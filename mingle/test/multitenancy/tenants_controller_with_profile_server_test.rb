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
require File.expand_path(File.dirname(__FILE__) + '/../messaging/messaging_test_helper')

# Tags: multitenancy, install
class TenantsControllerWithProfileServerTest < ActionController::TestCase
  include MessagingTestHelper

  def setup
    Multitenancy.delete_schemas_with_prefix('min\\_')
    Multitenancy.clear_tenants
    Clock.fake_now("2012-01-01")

    @http_stub = HttpStub.new
    ProfileServer.configure({:url => "https://profile_server"}, @http_stub)
    @auth = ProfileServer.authentication

    @controller = TenantsController.new
  end

  def teardown
    ProfileServer.reset
    Multitenancy.delete_schemas_with_prefix('min\\_')
    Multitenancy.clear_tenants
    Clock.reset_fake
  end

  def test_create_tenant
    create_tenant("site123", valid_site_setup_params) do |schema|
      Multitenancy.activate_tenant("site123") do
        assert !Database.need_migration?
        assert License.eula_accepted?
        assert_not_nil CurrentLicense.license_key
        assert_equal 'email', User.first_admin.login
        assert_equal 'Admin User', User.first_admin.name
        assert_equal 1, Project.all.size

        assert_equal 2, @http_stub.requests.size
        assert_equal :post, @http_stub.requests[0].http_method
        assert_equal "https://profile_server/organizations/site123/users/sync.json", @http_stub.requests[0].url
        assert_equal :put, @http_stub.requests[1].http_method
        assert_equal "https://profile_server/organizations/site123.json", @http_stub.requests[1].url
      end

      assert Multitenancy.tenant_exists?("site123")
    end
  end

  def valid_site_setup_params
    {
      :first_admin => {
        :name => "Admin User",
        :email => "email@exmaple.com"
      },
      :license => valid_license
    }
  end

  private

  def schema_name(tenant_name)
    tenant = Multitenancy.find_tenant(tenant_name)
    tenant.schema_name unless tenant.nil?
  end

  def create_tenant(tenant_name, setup_params, &block)
    schema_name = tenant_name
    post(:create, :name => tenant_name,
         :setup_params => setup_params)

    assert_response :success

    TenantCreationProcessor.run_once
    tenant_schema = schema_name(tenant_name)
    yield(tenant_schema)
  ensure
    post(:destroy, :name => tenant_name)
  end
end
