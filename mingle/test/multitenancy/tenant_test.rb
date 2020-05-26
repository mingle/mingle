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
class TenantTest < ActiveSupport::TestCase
  def setup
    Multitenancy.delete_schemas_with_prefix('min\\_')
    Multitenancy.clear_tenants
    Multitenancy.clear_missing
  end

  def teardown
    Multitenancy.delete_schemas_with_prefix('min\\_')
    Multitenancy.clear_tenants
    Multitenancy.clear_missing
  end

  def test_upgrade_all_tenants_marks_tenants_as_missing
    create_tenant("site1")
    create_tenant("site2")

    assert_equal ["site1", "site2"], Multitenancy.tenants.sort
    assert_equal [], Multitenancy.tenants_missing_schemata

    Multitenancy.merge_tenant_config("site2", {"database_username" => "foobar"})
    TenantInstallation.upgrade_all_tenants

    assert_equal ["site1"], Multitenancy.tenants.sort
    assert_equal ["site2"], Multitenancy.tenants_missing_schemata
  end

  def test_fetch_schema_name_when_db_username_is_an_array
    create_tenant("site1")
    Multitenancy.merge_tenant_config("site1", {"database_username" => ["schema_name"]})
    tenant = Multitenancy.find_tenant("site1")
    assert_equal "SCHEMA_NAME", tenant.schema_name
  end

  def test_activate_tenant_should_not_effect_db_config
    create_tenant("site1")
    tenant = Multitenancy.find_tenant('site1')
    original_db_config = tenant.db_config.dup
    tenant.activate {}
    assert_equal(original_db_config, tenant.db_config)
  end

  def create_tenant(name)
    TenantInstallation.create_tenant(name, valid_site_setup_params)
  end

  def valid_site_setup_params
    {
    :first_admin => {
      :login => "admin",
      :name => "Admin User",
      :email => "email@exmaple.com"
      },
      :license => valid_license
    }
  end

end
