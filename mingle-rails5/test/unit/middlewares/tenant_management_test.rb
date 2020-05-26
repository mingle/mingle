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

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')
class TenantManagementTest < ActiveSupport::TestCase

  def test_response_404_when_tenant_not_found
    Multitenancy.expects(:tenant_exists?).with('not-found-site').returns(false).once
    status, _, _ = serve_through_tenant_management('not-found-site.example.com') do
      raise 'the app should not be called'
    end

    assert_equal 404, status
  end

  def test_response_404_when_http_host_does_not_exist_in_the_env
    tenant_management = Middlewares::TenantManagement.new('app')
    env = {}
    status, _, _ = tenant_management.call(env)
    assert_equal 404, status
  end

  def test_activate_tenant_and_call
    invoked_env = nil
    Multitenancy.expects(:tenant_exists?).with('only-tenant').returns(true).once
    Multitenancy.expects(:activate_tenant).with('only-tenant').once.yields

    serve_through_tenant_management('only-tenant.example.com') do |env|
      invoked_env = env
    end
    expected_env = {'HTTP_HOST' => 'only-tenant.example.com'}

    assert_equal expected_env, invoked_env
  end

  def test_extract_tenant_name_from_http_host_with_multiple_subdomain
    Multitenancy.expects(:tenant_exists?).with('only-tenant').returns(true).once
    Multitenancy.expects(:activate_tenant).with('only-tenant').once
    serve_through_tenant_management('only-tenant.bar.example.com:8080')
  end

  def test_bypass_for_localhost
    status, _, body = serve_through_tenant_management('localhost') do
      [200, {}, 'found localhost']
    end
    assert_equal 200, status
    assert_equal 'found localhost', body
  end

  private
  def serve_through_tenant_management(host, env = {'HTTP_HOST' => host},  &app)
    tenant_management = Middlewares::TenantManagement.new(app)
    tenant_management.call(env)
  end
end
