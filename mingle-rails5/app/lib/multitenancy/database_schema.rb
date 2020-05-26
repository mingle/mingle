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
  def self.db_url(db_url)
    return default_db_url if db_url.blank?
    if db_url !~ /^jdbc\:.*/
      Rails.logger.error("Invalid db url '#{db_url}', use default configured url '#{default_db_url}' instead")
      return default_db_url
    end
    db_url
  end

  def self.default_db_url
    Multitenancy::DEFAULT_DB_URL
  end

  class DatabaseSchema
    attr_reader :db_url, :schema
    def initialize(db_url, schema)
      @db_url = Multitenancy.db_url(db_url)
      @schema = schema
    end

    def name
      @schema.name
    end

    def fake_tenant
      Tenant.new(name, 'database_username' => name, 'db_config' => { 'url' => db_url })
    end

    [:create, :delete, :ensure, :exists?, :info].each do |m|
      define_method m do |*args, &block|
        Rails.logger.info("switching to connection pool connecting to #{@db_url}")
        CONNECTION_MANAGER.with_connection(@db_url) do
          @schema.send(m, *args, &block)
        end
      end
    end
  end
end
