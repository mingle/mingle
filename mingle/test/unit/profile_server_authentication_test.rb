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

class ProfileServerAuthenticationTest < ActiveSupport::TestCase
  def setup
    MingleConfiguration.app_namespace = "parsley"
    @http_stub = HttpStub.new
    ProfileServer.configure({:url => "https://profile_server"}, @http_stub)
    @auth = ProfileServer.authentication
    @thomas = create_user!(:login => 'thomas0f', :name => 'Thomas the Tank Engine')
  end

  def teardown
    ProfileServer.reset
    MingleConfiguration.app_namespace = nil
  end

  def test_should_generate_correct_sign_in_url
    assert_equal "https://profile_server/cas/parsley/login?service=https://mingle.example.com/foo", @auth.sign_in_url('https://mingle.example.com/foo')
  end

  def test_should_generate_correct_sign_out_url
    assert_equal "https://profile_server/cas/parsley/logout?url=https://mingle.example.com/foo", @auth.sign_out_url('https://mingle.example.com/foo')
  end

  def test_should_return_a_user_for_a_valid_ticket
    service = 'https://mingle.example.com/foo'
    @http_stub.register_get_response("https://profile_server/cas/parsley/validate?ticket=some-ticket&service=#{service}", [200, "yes\n#{@thomas.login}\n"])

    assert_equal @thomas, @auth.authenticate?({:ticket => 'some-ticket'}, service)
  end

  def test_should_return_nil_for_an_invalid_ticket
    service = 'https://mingle.example.com/foo'
    @http_stub.register_get_response("https://profile_server/cas/parsley/validate?ticket=some-ticket&service=#{service}", [200, "no\n\n"])
    assert_equal nil, @auth.authenticate?({:ticket => 'some-ticket'}, service)
  end

  def test_should_return_nil_if_cas_server_response_boo
    service = 'https://mingle.example.com/foo'
    @http_stub.set_error(:get => ProfileServer::NetworkError.new("connection refused"))
    assert_equal nil, @auth.authenticate?({:ticket => 'some-ticket'}, service)
  end

  def test_should_return_nil_if_cas_server_response_is_not_spec_compliant
    service = 'https://mingle.example.com/foo'
    @http_stub.register_get_response("https://profile_server/cas/parsley/validate?ticket=some-ticket&service=#{service}", [200, "boo!\n#{@thomas.login}\n"])
    assert_equal nil, @auth.authenticate?({:ticket => 'some-ticket'}, service)
  end

  def test_should_create_new_user_if_auth_success_and_cant_find_user_by_login
    service = 'https://mingle.example.com/foo'
    @http_stub.register_get_response("https://profile_server/cas/parsley/validate?ticket=some-ticket&service=#{service}", [200, "yes\nnew_user_login\n"])

    user = @auth.authenticate?({:ticket => 'some-ticket'}, service)
    assert_equal 'new_user_login', user.login
    assert_equal nil, user.email
  end

  def test_should_create_new_user_with_email_if_its_new_user_and_login_is_email
    service = 'https://mingle.example.com/foo'
    @http_stub.register_get_response("https://profile_server/cas/parsley/validate?ticket=some-ticket&service=#{service}", [200, "yes\nnew@email.com\n"])

    user = @auth.authenticate?({:ticket => 'some-ticket'}, service)
    assert_equal 'new@email.com', user.login
    assert_equal 'new@email.com', user.email
  end

  def test_support_password_change_depending_on_sso_by_idp_status
    @http_stub.register_get_response("https://profile_server/organizations/parsley/sso_config.json", [200, "null"])
    assert @auth.supports_password_change?

    @http_stub.register_get_response("https://profile_server/organizations/parsley/sso_config.json", [200, "saml metadata"])
    assert !@auth.supports_password_change?
  end

  def test_supports_password_recovery_depending_on_sso_by_idp_status
    @http_stub.register_get_response("https://profile_server/organizations/parsley/sso_config.json", [200, "null"])
    assert @auth.supports_password_recovery?
    @http_stub.register_get_response("https://profile_server/organizations/parsley/sso_config.json", [200, "saml metadata"])
    assert !@auth.supports_password_recovery?
  end
end
