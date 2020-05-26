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

require 'multitenancy/config_source'
require 'multitenancy/tenant'
require 'multitenancy/tenant_management'
require 'multitenancy/database_schema'
require 'multitenancy/schema'
require 'multitenancy/schema_selector'
require 'multitenancy/tenant_name_invalid_error'
require 'multitenancy/tenant_not_found_error'
require 'multitenancy/s3_bucket_manager'

module Multitenancy
  NAME_MAX_LENGTH = 24

  class << self
    def setup_schema_selector
      return unless need_schema_selector?
      ActiveRecord::ConnectionAdapters::ConnectionPool.send(:include, SchemaSelector)
      Tenant.send(:include, SchemaSelector::Tenant)
    end

    def clear_activerecord_connection_pools
      test_db_url = ActiveRecord::Base.configurations[Rails.env]['url']
      ActiveRecord::Base.connection_handler.connection_pools.delete_if {|key, value| key != test_db_url }
    end

    def schema(db_url, name)
      DatabaseSchema.new(db_url, Schema.new(name))
    end

    def schemas(prefix)
      without_tenant do
        ActiveRecord::Base.connection.schemata_with_prefix(prefix)
      end
    end

    def delete_schemas_with_prefix(schema_prefix, db_url=nil)
      without_tenant do
        schemas = ActiveRecord::Base.connection.schemata_with_prefix(schema_prefix)
        schemas.map{|s| self.schema(db_url, s)}.each(&:delete)
      end
    end

    def schema_name
      if active_tenant = Multitenancy.active_tenant
        active_tenant.schema_name
      else
        connection_username
      end
    end

    def connection_username
      without_tenant do
        ActiveRecord::Base.connection.instance_variable_get('@config')[:username].upcase
      end
    end

    def no_tenant?
      Thread.current['multitenancy::no_tenant']
    end

    def without_tenant(&block)
      Thread.current['multitenancy::no_tenant'] = true
      block.call
    ensure
      Thread.current['multitenancy::no_tenant'] = nil
    end

    def tenants
      Array(tenant_configs_source.names)
    end

    def tenants_missing_schemata
      Array(missing_schemata_tenants.names)
    end

    def add_tenant(name, config, &setup_block)
      name = name.downcase
      validate_name!(name)
      Tenant.new(name, config).tap do |tenant|
        if block_given?
          tenant.activate(&setup_block)
        end
        tenant_configs_source[name] = config.to_json
      end
    end

    def delete_tenant(name, &block)
      tenant = find_tenant(name)
      if tenant
        yield(tenant) if block_given?
        tenant_configs_source.delete(name)
      end
    end

    def activate_tenant(name, &block)
      tenant = find_tenant(name)
      raise TenantNotFoundError.new("Cannot find tenant by name #{name}") unless tenant
      tenant.activate(&block)
    end

    def tenant_exists?(name)
      !tenant_config(name).nil?
    end

    def valid_name?(name)
      name && name =~ /^([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])$/i # close to RFC-1123
    end

    def derive_tenant_name(name)
      name_without_special_chars = name.gsub(/[^a-zA-Z0-9-]+/, '-').downcase
      tenant_name = name_without_special_chars.gsub(/-+$/, '')
      return "" if !valid_name?(tenant_name)
      return tenant_name.uniquify_with_succession(NAME_MAX_LENGTH) { |name| !valid_name?(name) || tenant_exists?(name) }
    end

    def clear_tenants
      tenant_configs_source.clear
      @source = nil
    end

    def clear_missing
      missing_schemata_tenants.clear
      @missing = nil
    end

    def randomized_tenants
      tenants.shuffle
    end

    def activate_each(&block)
      randomized_tenants.each do |name|
        activate_tenant(name, &block)
      end
    end

    def active_tenant
      Tenant.currently_active
    end

    #todo: delete this after deployed to production
    def disconnect_tenant(name)
    end

    def find_tenant(name)
      if config = tenant_config(name)
        Tenant.new(name, config)
      end
    end

    def merge_tenant_config(name, new_config)
      Rails.logger.info("trying to merge tenant config: #{name} => #{new_config.inspect}")
      if config = tenant_config(name)
        Rails.logger.info("found tenant configuration, merge it")
        tenant_configs_source[name] = remove_deprecated_configs(config.merge(new_config)).to_json
      end
    end

    def delete_tenant_config(name, key)
      Rails.logger.info("trying to delete tenant config: #{name} => #{key.inspect}")
      if config = tenant_config(name)
        Rails.logger.info("found tenant configuration, delete it")
        config.delete(key)
        tenant_configs_source[name] = remove_deprecated_configs(config).to_json
      end
    end

    def remove_deprecated_configs(config)
      accepted_keys = MingleConfiguration::ENV_CONFIG + MingleConfiguration::FEATURE_TOGGLES
      config.delete_if do |key, value|
        (key.start_with?("mingle.config.") && (is_obsolete = !accepted_keys.include?(key.to_s.gsub(/^mingle\.config\./, "").to_sym))).tap do |result|
          Rails.logger.info "deleting tenant key #{key.inspect}" if result
        end
      end
    end

    def stats
      tenant_configs_source.names.inject({}) do |memo, name|
        config = tenant_config(name)
        db_url = config['db_config'] ? config['db_config']['url'] : nil
        db_url = Multitenancy.db_url(db_url)
        memo[db_url] ||= 0
        memo[db_url] += 1
        memo
      end
    end

    def mark_tenant_as_missing_schema(tenant_name)
      missing_schemata_tenants[tenant_name] = tenant_config(tenant_name).to_json
      tenant_configs_source.delete(tenant_name)
    end

    private
    def tenant_config(name)
      return if name.blank?
      name = name.downcase

      unless valid_name?(name)
        Rails.logger.warn("Warn: trying to find a tenant with invalid name '#{name}'")
      end
      if config = tenant_configs_source[name]
        JSON.parse(config)
      end
    end
    def validate_name!(name)
      raise TenantNameInvalidError.new("#{name.inspect} is not a valid tenant name.") unless valid_name?(name)
    end

    def need_schema_selector?
      MingleConfiguration.multitenancy_mode? ||  MingleConfiguration.multitenancy_migrator?
    end

    def tenant_configs_source
      @source ||= ConfigSource.create
    end

    def missing_schemata_tenants
      @missing ||= KeyValueStore.create MingleConfiguration.missing_schemata_dynamodb_table, :tenant, :configs, MingleConfiguration.saas?
    end

  end
end
