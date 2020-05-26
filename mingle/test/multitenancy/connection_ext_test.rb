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

require File.join(File.dirname(__FILE__), 'test_helper')

# Tags: multitenancy, install
class ConnectionExtTest < ActiveSupport::TestCase
  def setup
    Multitenancy.delete_schemas_with_prefix('site')
    @site_schema = Multitenancy.schema(nil, 'site')
  end

  def teardown
    Multitenancy.delete_schemas_with_prefix('site')
  end

  def test_should_not_change_current_schema_when_execute_sql_failed
    show_current_schema_sql = connection.database_vendor == :oracle ? "SELECT SYS_CONTEXT( 'userenv', 'current_schema' ) FROM dual" : "SHOW search_path"

    @site_schema.create
    Multitenancy.switch_schema(connection, @site_schema.name)
    assert_equal 'SITE', connection.select_value(show_current_schema_sql).upcase

    with_network_problem do
      connection.execute("hello world") rescue nil
    end

    assert_equal 'SITE', connection.select_value(show_current_schema_sql).upcase
  end

  def test_connection_active
    assert connection.active?
    with_network_problem do
      assert !connection.active?
    end
  end

  def connection
    Multitenancy.without_tenant do
      ActiveRecord::Base.connection
    end
  end

  def with_network_problem(&block)
    sql = connection.config[:connection_alive_sql]
    connection.config[:connection_alive_sql] = 'simulate network error'
    yield
  ensure
    connection.config[:connection_alive_sql] = sql
  end
end
