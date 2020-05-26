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
class MultitenancySchemaTest < ActiveSupport::TestCase
  def setup
    Multitenancy.delete_schemas_with_prefix('site')
    @site_schema = Multitenancy.schema(nil, 'site')
  end

  def teardown
    Multitenancy.delete_schemas_with_prefix('site')
  end

  def test_delete_schemas_by_prefix
    @site_schema.create
    Multitenancy.delete_schemas_with_prefix('site')
    assert !@site_schema.exists?
  end

  def test_schema_actions
    assert !@site_schema.exists?
    @site_schema.create
    assert @site_schema.exists?
    @site_schema.delete
    assert !@site_schema.exists?
  end

  def test_ensure_schema_should_create_schema_if_it_does_not_exist
    @site_schema.ensure
    assert @site_schema.exists?
  end

  def test_ensure_schema_should_not_recreate_schema_if_schema_exists
    @site_schema.create

    conn = Multitenancy.without_tenant { ActiveRecord::Base.connection }

    Multitenancy.switch_schema(conn, @site_schema.name)
    conn.create_table :schema_migrations do |t|
      t.column :version, :string
    end
    @site_schema.ensure

    table_count_sql = if conn.database_vendor == :oracle
      "SELECT COUNT(*) FROM ALL_TABLES WHERE OWNER = '#{@site_schema.name.upcase}'"
    else
      "SELECT COUNT(*) FROM pg_tables WHERE LOWER(schemaname) = '#{@site_schema.name.downcase}'"
    end

    assert_equal "1", conn.select_value(table_count_sql)
  end

  def test_ensure_tablespace_deleted_if_it_exists
    only_oracle do
      password = 'password'
      conn = Multitenancy.without_tenant { ActiveRecord::Base.connection }

      conn.execute("CREATE TABLESPACE #{@site_schema.name} DATAFILE '#{@site_schema.name}' SIZE 1M ONLINE;")
      conn.execute("CREATE USER #{@site_schema.name} IDENTIFIED BY #{password} DEFAULT TABLESPACE #{@site_schema.name} QUOTA UNLIMITED ON #{@site_schema.name} TEMPORARY TABLESPACE temp")

      Multitenancy.delete_schemas_with_prefix(@site_schema.name)
      assert !@site_schema.exists?

      result = conn.execute("SELECT COUNT(*) AS TABLESPACE_COUNT FROM DBA_TABLESPACES WHERE TABLESPACE_NAME='#{@site_schema.name}'")
      assert result[0]['tablespace_count'] == '0'
    end
  end

end
