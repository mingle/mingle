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

require File.join(File.dirname(__FILE__), '/../../test_helper')

class TenantTest < ActiveSupport::TestCase

  #Todo: Move this to an integration test with actual tenant creation when TenantInstallation logic is moved.
  # def test_upgrade_all_tenants_marks_tenants_as_missing
  #   create_tenant('site1')
  #   create_tenant('site2')
  #
  #   assert_equal %w(site1 site2), Multitenancy.tenants.sort
  #   assert_equal [], Multitenancy.tenants_missing_schemata
  #
  #   Multitenancy.merge_tenant_config('site2', {'database_username' => 'foobar'})
  #   TenantInstallation.upgrade_all_tenants
  #
  #   assert_equal ['site1'], Multitenancy.tenants.sort
  #   assert_equal ['site2'], Multitenancy.tenants_missing_schemata
  # end

  def test_fetch_schema_name_when_db_username_is_an_array
    Multitenancy.add_tenant('site1', database_username: 'blah')
    Multitenancy.merge_tenant_config('site1', {'database_username' => ['schema_name']})
    tenant = Multitenancy.find_tenant('site1')
    assert_equal 'SCHEMA_NAME', tenant.schema_name
  end

  def test_activate_tenant_should_not_effect_db_config
    Multitenancy.expects(:switch_schema).with(anything, 'BLAH')
    Multitenancy.add_tenant('site1', database_username: 'blah')
    tenant = Multitenancy.find_tenant('site1')
    original_db_config = tenant.db_config.dup
    tenant.activate {}
    assert_equal(original_db_config, tenant.db_config)
  end

  def test_should_use_default_db_config_for_tenant_without_db_config
    expected_db_config = {username: 'test user', password: 'test password', url: 'jdbc:postgresql://localhost:5432/mingle_backend_test'}
    Multitenancy.expects(:default_db_config).returns(expected_db_config)
    Multitenancy::CONNECTION_MANAGER.class.any_instance.expects(:add).with(expected_db_config[:url], expected_db_config)
    Multitenancy::CONNECTION_MANAGER.class.any_instance.expects(:with_connection).with do |url, &block|
      expected_db_config[:url] == url
    end

    Multitenancy::Tenant.new('test-tenant', {database_username: 'another tenant'}).switch_connection_pool {}
  end

  def test_should_merge_tenant_db_config_with_default_db_config
    default_db_config = {password: 'test password', url: 'jdbc:postgresql://localhost:5432/mingle_backend_test'}
    expected_tenant_config = {database_username: 'another test user', 'db_config' => {password: ' another test password', url: 'jdbc:postgresql://localhost:5432/mingle_backend_test_1'}}
    expected_db_config = expected_tenant_config['db_config']
    Multitenancy.expects(:default_db_config).returns(default_db_config)
    Multitenancy::CONNECTION_MANAGER.class.any_instance.expects(:add).with(expected_db_config[:url], expected_db_config)
    Multitenancy::CONNECTION_MANAGER.class.any_instance.expects(:with_connection).with do |url, &block|
      expected_db_config[:url] == url
    end

    Multitenancy::Tenant.new('test-tenant', expected_tenant_config).switch_connection_pool {}
  end

  def test_should_remove_schema_name_and_schema_search_path
    default_db_config = {password: 'test password', url: 'jdbc:postgresql://localhost:5432/mingle_backend_test'}
    expected_tenant_config = {database_username: 'another test user', 'db_config' => {
        password: ' another test password', url: 'jdbc:postgresql://localhost:5432/mingle_backend_test_1', schema:'test_schema_name', schema_search_path:'test_schema_name'
    }}
    expected_db_config = expected_tenant_config['db_config']
    Multitenancy.expects(:default_db_config).returns(default_db_config)
    Multitenancy::CONNECTION_MANAGER.class.any_instance.expects(:add).with(expected_db_config[:url], expected_db_config.except(:schema, :schema_search_path))
    Multitenancy::CONNECTION_MANAGER.class.any_instance.expects(:with_connection).with do |url, &block|
      expected_db_config[:url] == url
    end

    Multitenancy::Tenant.new('test-tenant', expected_tenant_config).switch_connection_pool {}
  end
end
