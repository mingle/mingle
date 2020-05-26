#  Copyright 2020 ThoughtWorks, Inc.
#  
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as
#  published by the Free Software Foundation, either version 3 of the
#  License, or (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#  
#  You should have received a copy of the GNU Affero General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.

module TenantInstallation
  class ConfigInvalidException < StandardError
  end

  class MigrationError < StandardError
  end

  FIRST_ADMIN_SPECIAL_PASSWORD_SUFFIX = "Pa$$s744Ix"

  @@locks = ThreadsafeHash.new

  class << self
    include UrlUtils

    def create_tenant_with_email_response(message)
      create_tenant(message[:name], message[:setup_params])
    rescue TenantInstallation::ConfigInvalidException => exception
      alarm = %Q[
#{message.inspect}
Error:
#{exception.class} (#{exception.message}):
    #{exception.backtrace.join("\n    ")}
]
      Rails.logger.info("Site creation failed - #{alarm}")
      Alarms.notify(exception, {:task => 'site creation'})
    end

    def create_tenant(tenant_name, setup_params)
      db_url, schema_name = SchemaPool.new.get_schema
      config = { 'database_username' => schema_name,
                 'a_b_testing_groups' => ABTesting.assign_groups
               }
      if db_url
        config['db_config'] = {'url' => db_url}
      end
      mutex(tenant_name) do
        tenant = Multitenancy.schema(db_url, schema_name).ensure do
          Multitenancy.add_tenant(tenant_name, config) do
            if setup_params
              Database.migrate
              License.eula_accepted unless License.eula_accepted?
              create_first_admin(setup_params[:first_admin])
              register_license(setup_params[:license]) if setup_params[:license]

              SystemUser.ensure_exists
            end
          end
        end
        # initialize demo project after tenant was created and configured
        # these actions will send messages to background jobs,
        # so we have to do them after tenant was configured in dynamo db
        tenant.activate do
          track_site_creation(tenant_name, User.first_admin.login)
          sample_project_specs = SampleProjectSpecs.new
          spec_name = if setup_params[:first_project_spec_name]
                        setup_params[:first_project_spec_name]
                      else
                        'sample_project.yml'
                      end
          sample_project_specs.process(spec_name)
        end
      end
    rescue => e
      Rails.logger.error { "create tenant failed due to: #{e.message}, tenant name: #{tenant_name}" }
      Rails.logger.error { "setup_params: #{setup_params.inspect}" }
      raise
    end

    def purge_s3_data_for_tenant(tenant_name, s3_bucket_manager=Multitenancy::S3BucketManager.new)
      s3_bucket_manager.clear(tenant_name)
    end

    def clear_saas_tos_cache(tenant)
      tenant.activate do
        SaasTos.clear_cache!
      end
    end

    def clear_elastic_search_data(tenant)
      tenant.activate do
        ElasticSearch.clean_site_documents(tenant.name)
      end
    end

    def destroy_tenant(tenant_name)
      mutex(tenant_name) do
        Multitenancy.delete_tenant(tenant_name) do |tenant|
          clear_saas_tos_cache(tenant)
          delete_firebase_data(tenant_name)
          clear_elastic_search_data(tenant)
          tenant.delete
          purge_s3_data_for_tenant(tenant_name)
        end
      end
    end

    def upgrade_tenant(tenant, force=false)
      mutex(tenant) do
        Multitenancy.activate_tenant(tenant) do
          if force || Database.need_migration?
            Database.migrate
            License.eula_accepted unless License.eula_accepted?
          end
        end
      end
    end

    def upgrade_all_tenants
      Multitenancy.randomized_tenants.each do |tenant_name|
        tenant = Multitenancy.find_tenant(tenant_name)
        raise Multitenancy::TenantNotFoundError.new("Cannot find tenant by name #{tenant_name}") unless tenant

        schema_name = tenant.schema_name
        connection = nil

        tenant.switch_connection_pool do

          schema_exists = Multitenancy.without_tenant do
            connection = ActiveRecord::Base.connection
            connection.schema_exists?(schema_name)
          end

          if schema_exists
            Multitenancy.switch_schema(connection, schema_name)
            tenant.activate do
              with_migration_error_logging(tenant_name) do
                upgrade_tenant(tenant_name)
              end
            end
          else
            Rails.logger.warn "tenant #{tenant_name.inspect} is missing its schema #{schema_name.inspect} at #{tenant.db_url.inspect}"
            Multitenancy.mark_tenant_as_missing_schema(tenant_name)
          end

        end


      end
    end

    def generate_from_email(email)
      name = email.split("@").first
      name.downcase.gsub(/\W/, '_').first(40)
    end

    def with_migration_error_logging(tenant_name)
      yield
    rescue => e
      Kernel.log_error(e, "Error upgrading tenant #{tenant_name.inspect}")
      me = MigrationError.new("Failed to migrate tenant #{tenant_name.inspect}: #{e.message}")
      me.set_backtrace(e.backtrace)
      raise me
    end

    private
    def delete_firebase_data(tenant_name)
      return if MingleConfiguration.firebase_app_url.blank?
      client = FirebaseClient.new(
        MingleConfiguration.firebase_app_url,
        MingleConfiguration.firebase_secret
      )

      FirebaseKeys::KEYS.each do |key, value|
        Rails.logger.info { "deleting key #{value} for #{tenant_name} at #{client.base_url}" }
        retryable(:tries => 3, :sleep => 0.05) do
          response = client.delete([value, tenant_name].join('/'))

          if response.success?
            Rails.logger.info { "Firebase response [#{response.url}]: #{response.inspect}" }
          else
            error = "Cannot push to firebase: #{response.url}, resp #{response.code}: #{response.body}"
            Rails.logger.error(error)
            raise error unless Rails.env.production?
          end
        end
      end
    end

    def mutex(lock_name, &block)
      @@locks.put_if_absent(lock_name, Mutex.new)
      @@locks[lock_name].synchronize(&block)
    end

    def create_first_admin(attrs)
      unless User.no_users?
        raise "There is unexpected #{User.count} users in the schema, which suppose to be clean. Top 5 are #{User.all(:limit => 5).inspect }."
      end
      lost_password_ticket = attrs.delete(:lost_password_ticket)
      password = attrs.delete(:password) || (lost_password_ticket ? (lost_password_ticket + FIRST_ADMIN_SPECIAL_PASSWORD_SUFFIX) : User.random_password)
      passwords = {:password => password, :password_confirmation => password}
      login = {:login => generate_from_email(attrs[:email])}
      user = User.create(attrs.merge(passwords).merge(login))
      if lost_password_ticket
        user.login_access.assign_lost_password_ticket(lost_password_ticket)
      end
      if !user.errors.empty?
        raise ConfigInvalidException.new(user.errors.full_messages.join("\n"))
      end
    end

    def register_license(license)
      status = CurrentLicense.register!(license[:key], license[:licensed_to])
      raise ConfigInvalidException.new("license is invalid, licensed to: #{license[:licensed_to]}, key: #{license[:key]}") unless status.valid?
    end

    def track_site_creation(tenant, user_login)
      EventsTracker.new.track("#{tenant}:#{user_login}", 'site_creation', ABTesting.group_info.merge({:site_name => tenant}))
    rescue => e
      Rails.logger.error "Track site creation failed: #{tenant.inspect}, #{user_login.inspect}"
      Rails.logger.error "Ignore error: #{e.message}\n#{e.backtrace.join("\n")}"
    end
  end
end
