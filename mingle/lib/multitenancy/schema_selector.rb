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
  def self.switch_schema(conn, schema_name)
    conn.config[:schema_search_path] = schema_name.downcase
    conn.switch_schema(schema_name)
  end

  module SchemaSelector
    module Tenant
      def self.included(base)
        base.alias_method_chain :activate, :switch_schema
      end

      def activate_with_switch_schema(&block)
        if ActiveRecord::Base.connection_handler.active_connections?
          Rails.logger.info "Already have active connection. Switching to schema - #{self.schema_name} for tenant: #{self.name}"
          Multitenancy.switch_schema(ActiveRecord::Base.connection, self.schema_name)
        end
        activate_without_switch_schema(&block)
      end
    end

    def self.included(base)
      base.alias_method_chain :checkout, :switch_schema
    end

    def checkout_with_switch_schema
      checkout_without_switch_schema.tap do |connection|
        active_tenant = Multitenancy.active_tenant

        if active_tenant.nil?
          if Multitenancy.no_tenant?
            connection.config.delete(:schema_search_path)
            return connection
          else
            checkin connection
            raise "No tenant activated currently. Can't checkout DB connection."
          end
        end
        Multitenancy.switch_schema(connection, active_tenant.schema_name)
        connection
      end
    end
  end
end
