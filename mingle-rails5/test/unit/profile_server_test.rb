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

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class ProfileServerTest < ActiveSupport::TestCase
  def setup
    MingleConfiguration.app_namespace = 'parsley'
    @http_stub = HttpStub.new
    ProfileServer.configure({:url => 'https://profile_server'}, @http_stub)
  end

  def teardown
    ProfileServer.reset
    MingleConfiguration.app_namespace = nil
  end

  def test_configured
    assert ProfileServer.configured?
    ProfileServer.reset
    assert_false ProfileServer.configured?
  end

  def test_license_details_retrieves_from_profile_server
    response = {
        'name' => 'parsley',
        'subscription_expires_on' => '2021-06-10',
        'allow_anonymous' =>true,
        'product_edition' => 'Mingle Plus',
        'max_active_full_users' =>200,
        'max_active_light_users' =>10,
        'lead_company' => 'TW',
        'users_url' => 'https://profile_server/organizations/parsley/users.json'}
    @http_stub.register_get_response('https://profile_server/organizations/parsley.json', [200, response.to_json])

    assert_equal response, ProfileServer.license_details
  end

  def test_update_license_sends_to_profile_server
    license_data = {'allow_anonymous' => false}
    ProfileServer.update_organization(license_data)
    assert_equal 1, @http_stub.requests.size
    assert_equal :put, @http_stub.last_request.http_method
    assert_equal 'https://profile_server/organizations/parsley.json', @http_stub.last_request.url
    put_attrs = JSON.parse(@http_stub.last_request.body)['organization']
    assert_equal false, put_attrs['allow_anonymous']
  end

  def test_new_user_is_relayed_to_profile_server
    user = create(:user)
    assert_equal 1, @http_stub.requests.size
    assert_equal :post, @http_stub.last_request.http_method
    assert_equal 'https://profile_server/organizations/parsley/users/sync.json', @http_stub.last_request.url
    post_attrs = JSON.parse(@http_stub.last_request.body)['user']
    assert_equal user.login, post_attrs['login']
    assert_equal user.name, post_attrs['name']
    assert_equal user.email, post_attrs['email']
    assert_equal user.password, post_attrs['password_hash']
    assert_equal user.salt, post_attrs['password_salt']
  end

  def test_user_attributes_changes_relayed_to_profile_server
    user = create(:user)
    user.update_last_login
    user.update_attributes(:name => 'john doe', :email => 'jdoe@mimpossible.com')

    assert_equal 2, @http_stub.requests.size
    assert_equal :post, @http_stub.last_request.http_method
    assert_equal 'https://profile_server/organizations/parsley/users/sync.json', @http_stub.last_request.url
    post_attrs = JSON.parse(@http_stub.last_request.body)['user']
    assert_equal 'john doe', post_attrs['name']
    assert_equal 'jdoe@mimpossible.com',  post_attrs['email']
    assert_equal user.login_access.last_login_at.as_json,  post_attrs['last_login_at']
  end

  def test_resetting_user_password_is_relayed_to_profile_server
    user = create(:user)
    user.change_password!(:password => 'p@ssw0rd', :password_confirmation => 'p@ssw0rd')
    assert user.errors.empty?
    ProfileServer
    assert_equal 2, @http_stub.requests.size
    user.reload

    post_attrs = JSON.parse(@http_stub.last_request.body)['user']
    assert_equal user.password, post_attrs['password_hash']
    assert_equal user.salt, post_attrs['password_salt']
  end

  def test_deactivating_a_user_is_relayed_to_profile_server
    user = create(:user)

    user.update_attribute(:activated, false)
    assert_equal 2, @http_stub.requests.size
    post_attrs = JSON.parse(@http_stub.last_request.body)['user']
    assert_equal false, post_attrs['active']
  end

  def test_deleting_a_user_deletes_on_profile_server
    User.any_instance.stubs(:check_deletable?).returns(true)
    user = create(:user)
    user.destroy

    assert_equal 2, @http_stub.requests.size
    last_request = @http_stub.requests.last
    assert_equal :delete, last_request.http_method

    assert_equal "https://profile_server/organizations/parsley/users/destroy_by_login.json?login=#{user.login}", last_request.url
  end

  def test_deactivate_users_on_profile_server
    user = create(:user)
    params = {:except => [user.login]}
    ProfileServer.deactivate_users(params)
    assert_equal 2, @http_stub.requests.size
    last_request = @http_stub.requests.last
    assert_equal :post, last_request.http_method

    assert_equal 'https://profile_server/organizations/parsley/users/deactivate.json', last_request.url
    assert_equal params.to_json, last_request.body
  end

  def test_should_retry_user_creation_upto_4_times_on_network_error
    @http_stub.set_error(:post => ProfileServer::NetworkError.new)
    assert_raises(ProfileServer::NetworkError) { create(:user) }
    assert_equal 4, @http_stub.requests.size
    assert_equal ['https://profile_server/organizations/parsley/users/sync.json'] * 4, @http_stub.requests.map(&:url)

  end

  def test_should_retry_user_deletion_upto_4_times_on_network_error
    User.any_instance.stubs(:check_deletable?).returns(true)
    user = create(:user)
    @http_stub.reset
    @http_stub.set_error(:delete => ProfileServer::NetworkError.new)
    assert_raises(ProfileServer::NetworkError) { user.destroy }
    assert_equal 4, @http_stub.requests.size
    assert_equal [:delete] * 4, @http_stub.requests.map(&:http_method)
  end

  def test_use_namespace_with_profile_server
    ProfileServer.configure({:url => 'https://profile_server', :namespace => 'fine'}, @http_stub)
    create(:user)
    assert_equal 'https://profile_server/organizations/fine$parsley/users/sync.json', @http_stub.last_request.url
  end

  def test_namespace_is_blank_proof
    ProfileServer.configure({:url => 'https://profile_server', :namespace => ''}, @http_stub)
    create(:user)
    assert_equal 'https://profile_server/organizations/parsley/users/sync.json', @http_stub.last_request.url
  end

  def test_should_skip_sync_in_project_upgrade_process
    old_table_name_prefix = ActiveRecord::Base.table_name_prefix
    ActiveRecord::Base.table_name_prefix = 'mi_123456'
    create(:user)
    assert @http_stub.requests.empty?
  ensure
    ActiveRecord::Base.table_name_prefix = old_table_name_prefix
  end

  def test_update_saml_metadata
    ProfileServer.update_saml_metadata('metadata file content')
    assert_equal 1, @http_stub.requests.size
    assert_equal :put, @http_stub.last_request.http_method
    assert_equal 'https://profile_server/organizations/parsley/sso_config.json', @http_stub.last_request.url
    post_attrs = JSON.parse(@http_stub.last_request.body)['organization']
    assert_equal 'metadata file content', post_attrs['saml_metadata']
  end

  def test_get_saml_metadata
    @http_stub.register_get_response('https://profile_server/organizations/parsley/sso_config.json', [200, 'saml metadata'])
    data = ProfileServer.get_saml_metadata
    assert_equal 'saml metadata', data
  end
end
