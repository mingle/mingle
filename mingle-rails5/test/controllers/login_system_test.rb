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

class LoginSystemTest < ActionDispatch::IntegrationTest

  def setup
    ApplicationController.allow_forgery_protection = true
  end

  def teardown
    ApplicationController.allow_forgery_protection = false
  end

  def test_configured_authenticates_api_key_for_an_api_call
    create(:admin)
    logout_as_nil
    MingleConfiguration.with_authentication_keys_overridden_to('key1') do
      request_path = "/api/v2#{call_me_in_test_path}.xml"

      get request_path, env: { LoginSystem::HTTP_MINGLE_API_KEY => 'key1'}

      assert_response :ok
      assert_equal('<response>successful api call</response>', @response.body)
      assert User.current.instance_of? User::ApiUser
    end
  end

  def test_configured_api_key_should_deny_if_api_key_not_valid
    create(:admin)
    logout_as_nil
    MingleConfiguration.with_authentication_keys_overridden_to('key1') do

      get "/api/v2#{call_me_in_test_path}.xml", env: {LoginSystem::HTTP_MINGLE_API_KEY => 'non existant'}

      assert_response 401
    end
  end

  def test_should_not_store_return_to_when_authenticated
    login create(:user) do |u, session|
      get call_me_in_test_path
      assert_nil session['return-to']
    end
  end

# TODO: fix/move/delete tests
 # def test_return_to_behavior_for_get_method
  #   logout_as_nil
  #   get :call_me_in_test_path
  #   assert_equal({}, @controller.session['return-to'])
  # end
  #
  # def test_return_to_behavior_for_post_method
  #   logout_as_nil
  #   params = {:comment => {:content => 'Murmured comment'}, :project_id => @project.identifier, :card => {:name => 'the_card', :card_type => @project.card_types.first}}
  #   post :create, params
  #   assert_nil @controller.session['return-to']
  # end

  def test_load_user_from_session_or_cookie_should_load_user_from_session_if_present
    controller = DummyController.new
    controller.request = ActionController::TestRequest.create
    create(:bob)
    controller.request.session = {login: 'bob'}
    assert_equal 'bob', controller.send(:load_user_from_session_or_cookie).login
  end

  def test_load_user_from_session_or_cookie_using_cookie_should_update_last_login_on_first_request_only
    controller = DummyController.new
    controller.request = ActionController::TestRequest.create
    login(create(:bob))
    controller.request.session = {:login => nil}
    old_last_logged_in = 10.days.ago.utc
    User.find_by_login('bob').login_access.update_attributes(:last_login_at => old_last_logged_in, :login_token => '123')
    controller.send(:cookies)[:login] = '123'

    # first request logs in user via cookie and adds to session
    user_from_cookie = controller.send(:load_user_from_session_or_cookie)
    assert_equal 'bob', user_from_cookie.login
    new_last_logged_in = user_from_cookie.login_access.reload.last_login_at
    assert_not_equal old_last_logged_in, new_last_logged_in.time

    # subsequent requests should load user from session and not set last logged in
    travel_to(user_from_cookie.login_access.last_login_at + 1.days) do
      assert_equal new_last_logged_in, controller.send(:load_user_from_session_or_cookie).login_access.last_login_at
    end
  end

  def test_use_hmac_with_user_api_key_to_login
    logout_as_nil
    user = create(:bob)
    user.update_api_key

    api_request_path = "/api/v2#{call_me_in_test_path}.xml"
    get api_request_path
    assert_response :unauthorized

    ApiAuth.expects(:access_id).with do |request|
      assert request.is_a? ActionDispatch::Request
    end.returns('bob')
    ApiAuth.expects(:authentic?).with do |request, key|
      assert request.is_a? ActionDispatch::Request
      assert_equal user.api_key, key
    end.returns(true)

    get api_request_path, env: {'Authorization': 'APIAuthorization:bob'}
    assert_response :ok
    assert_equal user, User.current

    user.update_api_key
    ApiAuth.expects(:access_id).with do |request|
      assert request.is_a? ActionDispatch::Request
    end.returns(nil)
    get api_request_path, env: {'Authorization': 'APIAuthorization:incorrect'}

    assert_response :unauthorized
    assert User.current.anonymous?
  end

  def test_should_auth_user_by_session_when_requesting_api_uri_with_auth_token
    token = SecureRandom.base64(ActionController::RequestForgeryProtection::AUTHENTICITY_TOKEN_LENGTH)
    user = create(:admin)
    set_session(_csrf_token: token, login: user.login)

    post "/api/v2#{call_me_in_test_path}.xml", headers: {'X-CSRF-Token': token}

    assert_response :success
    assert_equal('<response>successful api call</response>', @response.body)
  end

  def test_auth_user_by_session_when_it_is_not_api_request_uri
    token = SecureRandom.base64(ActionController::RequestForgeryProtection::AUTHENTICITY_TOKEN_LENGTH)
    user = create(:admin)
    set_session(_csrf_token: token, login: user.login)

    post call_me_in_test_path, headers: {'X-CSRF-Token': token}

    assert_response :success
    assert_equal('Implementing this to test rails secure headers', @response.body)
  end

  def test_authorize_user_with_github_webhook
    # Assuming request is verified. The github controller receive endpoint should not verify authenticity token
    # because that request will come from the webhook call
    ApplicationController.allow_forgery_protection = false
    logout_as_nil
    user = create(:bob)
    user.update_api_key
    commits = ['[{"id":"4fbee7a1ae639e07bd7792da0912bb7e4015a0e1","distinct":true,"message":"changing for push","timestamp":"2014-04-30T13:57:01-07:00","url":"https://github.com/betarelease/test_push/commit/4fbee7a1ae639e07bd7792da0912bb7e4015a0e1","author":{"name":"Sudhindra Rao","email":"sudhindra.r.rao@gmail.com","username":"betarelease"},"committer":{"name":"Sudhindra Rao","email":"sudhindra.r.rao@gmail.com","username":"betarelease"},"added":[],"removed":[],"modified":["README.md"]}]']
    repository = '{"id":19327016,"name":"test_push","url":"https://github.com/betarelease/test_push","description":"testing push webhooks","watchers":0,"stargazers":0,"forks":0,"fork":false,"size":0,"owner":{"name":"betarelease","email":"sudhindra.r.rao@gmail.com"},"private":false,"open_issues":0,"has_issues":true,"has_downloads":true,"has_wiki":true,"created_at":1398891366,"pushed_at":1398891485,"master_branch":"master"}'
    github_data = '{"commmits":"#{commits}", "repository":"#{repository}"}'

    hmac_digest = OpenSSL::Digest.new('sha1')
    hmac_signature = OpenSSL::HMAC.hexdigest(hmac_digest, user.api_key, github_data)

    Messaging::Mailbox.expects(:transaction).once

    post call_me_in_test_path ,params: {:format => :json, :commits => commits, :repository => repository, :user => 'bob'},
         env: {'HTTP_X_HUB_SIGNATURE': "sha1=#{hmac_signature}",'RAW_POST_DATA': github_data }

    assert_response :ok
  end

end
