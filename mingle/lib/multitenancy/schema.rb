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
  class Schema
    attr_reader :name
    def initialize(name)
      @name = name.to_s.upcase
      validate!
    end

    def validate!
      raise "Invalid Schema Name #{@name.inspect}" if @name.start_with?("PG_")
      raise "Invalid Schema Name #{@name.inspect}" unless @name =~ /^[A-Z][A-Z\d_]*$/
      raise "Invalid schema name #{@name.inspect}, max length is 30" if @name.size > 30
    end

    def ensure(&block)
      create unless exists?
      yield if block_given?
    end

    def exists?
      Multitenancy.without_tenant do
        connection.schema_exists?(self.name)
      end
    end

    def create
      Multitenancy.without_tenant do
        connection.create_tenant_schema(self.name)
      end
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.error { "#{e.message}\n#{e.backtrace.join("\n")}" }
      raise "Schema '#{@name}' creation failed due to: #{e.message}"
    end

    def delete
      Multitenancy.without_tenant do
        connection.drop_tenant_schema(self.name)
      end
    end

    private
    def connection
      ActiveRecord::Base.connection
    end
  end
end
