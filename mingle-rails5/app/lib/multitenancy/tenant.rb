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

module Multitenancy
  class Tenant
    attr_reader :name, :schema_name, :db_config, :a_b_test_group_info, :mingle_configurations

    def self.currently_active
      Thread.current['multitenancy::active_tenant']
    end

    def self.with_tenant(tenant, &block)
      prev = Thread.current['multitenancy::active_tenant']
      Thread.current['multitenancy::active_tenant'] = tenant
      yield if block_given?
    ensure
      Thread.current['multitenancy::active_tenant'] = prev
    end

    def initialize(name, config)
      @name = name
      db_username = config['database_username']
      @schema_name = db_username.is_a?(Array) ? db_username.first.to_s.upcase : db_username.to_s.upcase
      @a_b_test_group_info = config['a_b_testing_groups'].try(:dup) || {}
      @db_config = (config['db_config'].try(:dup) || {}).with_indifferent_access
      @mingle_configurations = parse_mingle_configurations(config)
    end

    def activate(&block)
      switch_connection_pool {
        switch_schema_for_active_connection {
          mark_active_tenant {
            setup_logging {
              override_mingle_global_configurations {
                override_mingle_tenant_configurations {
                  switch_app_namespace(&block)}}}}}}
    end

    def delete
      Multitenancy.schema(@db_config['url'], @schema_name).delete
    end

    # keep it for mingle-saas codebase changes
    def disconnect!
    end

    def db_url
      Multitenancy.db_url(@db_config['url'])
    end

    def switch_connection_pool(&block)
      db_config = Multitenancy.default_db_config.merge(@db_config.symbolize_keys).except(:schema, :schema_search_path)
      Multitenancy::CONNECTION_MANAGER.add(db_config[:url], db_config)
      Rails.logger.info("Switching connection with SCHEMA name #{@schema_name} and DB config : #{db_config.except(:password)}")
      Multitenancy::CONNECTION_MANAGER.connection_pools.keys.each do | key |
        connection = Multitenancy::CONNECTION_MANAGER.connection_pools[key]
        spec = connection&.spec
        Rails.logger.info("Connection config for #{key} : #{spec.config.except(:password)}") if spec&.config
      end
      Multitenancy::CONNECTION_MANAGER.with_connection(db_config[:url], &block)
    end

    private
    def switch_schema_for_active_connection
      Multitenancy.switch_schema(ApplicationRecord.connection, self.schema_name)
      yield
    end

    def parse_mingle_configurations(config)
      config.map do |key, _|
        if key =~ /^mingle.config.(.*)$/
          [$1, _]
        end
      end.compact
    end

    def override_mingle_tenant_configurations(&block)
      MingleConfiguration.overridden_to(@mingle_configurations, &block)
    end

    def override_mingle_global_configurations(&block)
      MingleConfiguration.overridden_to(MingleConfiguration.global_config, &block)
    end

    def mark_active_tenant(&block)
      self.class.with_tenant(self, &block)
    end

    def switch_app_namespace(&block)
      MingleConfiguration.with_app_namespace_overridden_to(@name, &block)
    end

    def override_a_b_testing_group_info(&block)
      ABTesting.overridden_group_info(@a_b_test_group_info, &block)
    end

    def setup_logging(&block)
      return yield unless RUBY_PLATFORM =~ /java/
      prev = org.apache.log4j.MDC.get('tenant')
      begin
        org.apache.log4j.MDC.put('tenant', @name)
        yield
      ensure
        if prev
          org.apache.log4j.MDC.put('tenant', prev)
        else
          org.apache.log4j.MDC.remove('tenant')
        end
      end
    end
  end
end
