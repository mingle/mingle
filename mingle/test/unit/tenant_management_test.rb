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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')
require File.expand_path(File.dirname(__FILE__) + '/../../lib/multitenancy/tenant_management.rb')
class TenantManagementTest < ActiveSupport::TestCase

  def setup
    Multitenancy.add_tenant('only-tenant', "database_adapter" => 'jdbc')
  end

  def teardown
    Multitenancy.clear_tenants
  end

  def test_response_404_when_tenant_not_found
    status, headers, body = serve_through_tenant_managment("not-found-site.example.com") do
      raise "the app should not be called"
    end

    assert_equal 404, status
  end

  def test_response_404_when_tenant_name_is_invalid
    status, headers, body = serve_through_tenant_managment("a_b.example.com") do
      raise "the app should not be called"
    end

    assert_equal 404, status
  end

  def test_response_404_when_http_host_does_not_exist_in_the_env
    tenant_management = Multitenancy::TenantManagement.new('app')
    env = {}
    status, headers, body = tenant_management.call(env)
    assert_equal 404, status
  end

  def test_activate_tenant_and_call
    status, headers, body = serve_through_tenant_managment("only-tenant.example.com") do |env|
      [200, {}, "found site only_tenant from #{env['HTTP_HOST']}"]
    end

    assert_equal 200, status
    assert_equal "found site only_tenant from only-tenant.example.com", body
  end

  def test_extract_tenant_name_from_http_host
    assert_equal "only-tenant", extract_tenant_name("only-tenant.bar.com")
    assert_equal "only-tenant", extract_tenant_name("only-tenant.bar.example.com:8080")
  end

  def test_bypass_for_localhost
    status, headers, body = serve_through_tenant_managment('localhost') do
      [200, {}, "found localhost"]
    end
    assert_equal 200, status
    assert_equal "found localhost", body
  end

  private

  def extract_tenant_name(host_name)
    _, _, body = serve_through_tenant_managment(host_name) { [200, {}, MingleConfiguration.app_namespace] }
    body
  end

  def serve_through_tenant_managment(host, &app)
    tenant_management = Multitenancy::TenantManagement.new(app)
    env = {"HTTP_HOST" => host}
    tenant_management.call(env)
  end
end
