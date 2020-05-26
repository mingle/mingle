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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class SchemaSelectorTest < ActiveSupport::TestCase

  class Connection
    attr_reader :sql, :current_schema

    def config
      @config ||= {}
    end

    def execute(sql)
      @sql = sql
    end

    def switch_schema(schema_name)
      @current_schema = schema_name
    end
  end

  class ConnectionPool
    attr_reader :conn
    def initialize
      @conn = Connection.new
    end

    def checkout
      conn = @conn
      @conn = nil
      conn
    end

    def checkin(conn)
      raise "checkout connection before checkin" if @conn
      @conn = conn
    end

    include Multitenancy::SchemaSelector
  end

  def setup
    Multitenancy.add_tenant('first',
                            "database_adapter" => 'jdbc',
                            "database_url" => "jdbc:oracle:thin:@//db.example.com:1521/mingle",
                            "database_username" => "tenant_schema")
    Multitenancy.add_tenant('second', "database_adapter" => 'jdbc')
  end

  def teardown
    Multitenancy.clear_tenants
  end

  def test_schema_switching_for_tenant
    pool = ConnectionPool.new
    Multitenancy.activate_tenant('first') do
      conn = pool.checkout
      assert_equal "TENANT_SCHEMA", conn.current_schema
    end
  end

  def test_raising_error_when_there_is_no_active_tenant
    pool = ConnectionPool.new
    assert_raise RuntimeError do
      pool.checkout
    end
    # should checkin the connection when there is error
    assert pool.conn
  end

  def test_should_return_raw_connection_when_no_active_tenant_and_mark_with_without_tenant_flag
    pool = ConnectionPool.new
    conn = Multitenancy.without_tenant do
      pool.checkout
    end
    assert_nil conn.sql
  end
end
