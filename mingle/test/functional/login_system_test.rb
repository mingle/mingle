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
require File.expand_path(File.dirname(__FILE__) + '/../unit/renderable_test_helper')

class LoginSystemTest < ActionController::TestCase
  def setup
    #Using CardsController to verify behavior of the login_system module
    @controller = create_controller CardsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller.request = @request
    @controller.response = @response

    login_as_member
    @project = first_project
    @project.activate
    @controller.class.allow_forgery_protection = true
  end

  def teardown
    @controller.class.allow_forgery_protection = false
    Clock.reset_fake
  end

  def test_configured_authenticates_api_key_for_an_api_call
    @controller = create_controller  FeedsController
    @controller.request = @request
    @controller.response = @response

    logout_as_nil
    MingleConfiguration.with_authentication_keys_overridden_to('key1') do
      @request.env["HTTP_MINGLE_API_KEY"] = 'key1'

      get :events, {:project_id => @project.identifier, :api_version => "v2", :format => "xml"}
      assert_response :ok

      assert_select 'feed', :count => 1 do
        assert_select "[xmlns=?]", "http://www.w3.org/2005/Atom"
        assert_select "[xmlns:mingle=?]", Mingle::API.ns
      end

      assert User.current.instance_of? User::ApiUser
    end
  end

  def test_configured_api_key_should_deny_if_api_key_not_valid
    @controller = create_controller  FeedsController
    @controller.request = @request
    @controller.response = @response

    logout_as_nil

    MingleConfiguration.with_authentication_keys_overridden_to('key1') do
      @request.env["HTTP_MINGLE_API_KEY"] = "non-existent"
      get :events, {:project_id => @project.identifier, :api_version => "v2", :format => "xml"}
      assert_response 401
    end
  end

  def test_should_not_store_return_to_when_authenticated
    get :list, {"project_id" => @project.identifier}
    assert_nil @controller.session['return-to']
  end

  def test_return_to_behavior_for_get_method
    logout_as_nil
    expected_params = {"project_id" => @project.identifier, "action" => "list", "controller" => "cards"}
    get :list, {"project_id" => @project.identifier}
    assert_equal(expected_params, @controller.session['return-to'])
  end

  def test_return_to_behavior_for_post_method
    logout_as_nil
    params = {:comment => {:content => "Murmured comment"}, :project_id => @project.identifier, :card => {:name => 'the_card', :card_type => @project.card_types.first}}
    post :create, params
    assert_nil @controller.session['return-to']
  end

  def test_load_user_from_session_or_cookie_should_load_user_from_session_if_present
    @controller.request = @request
    @controller.session = { :login => 'bob' }
    assert_equal 'bob', @controller.send(:load_user_from_session_or_cookie).login
  end

  def test_load_user_from_session_or_cookie_using_cookie_should_update_last_login_on_first_request_only
    @controller.session = {:login => nil}
    old_last_logged_in = 10.days.ago.utc
    User.find_by_login('bob').login_access.update_attributes(:last_login_at => old_last_logged_in, :login_token => '123')
    @controller.send(:cookies)[:login] = '123'

    # first request logs in user via cookie and adds to session
    user_from_cookie = @controller.send(:load_user_from_session_or_cookie)
    assert_equal 'bob', user_from_cookie.login
    new_last_logged_in = user_from_cookie.login_access.reload.last_login_at
    assert_not_equal old_last_logged_in, new_last_logged_in

    # subsequent requests should load user from session and not set last logged in
    Clock.fake_now(user_from_cookie.login_access.last_login_at + 1.days)
    assert_equal new_last_logged_in, @controller.send(:load_user_from_session_or_cookie).login_access.last_login_at
  end

  def test_use_hmac_with_user_api_key_to_login
    logout_as_nil
    user = user_named("bob@email.com")
    user.update_api_key

    get :list, {:api_version => 'v2', "project_id" => @project.identifier, :format => 'xml'}
    assert_response :unauthorized

    ApiAuth.sign!(@request, user.login, user.api_key)

    get :list, {:api_version => 'v2', "project_id" => @project.identifier, :format => 'xml'}
    assert_response :ok
    assert_equal user, User.current

    user.update_api_key

    get :list, {:api_version => 'v2', "project_id" => @project.identifier, :format => 'xml'}
    assert_response :unauthorized
    assert User.current.anonymous?
  end

  def test_should_not_auth_user_by_session_when_requesting_api_uri
    logout_as_nil
    session[:login] = 'admin'
    post :create, {
      :api_version => 'v2',
      :project_id => @project.identifier,
      :format => 'xml',
      :card => {:name => 'This is my card', :card_type => @project.card_types.first}
    }
    assert_response :unauthorized
  end

  def test_should_auth_user_by_session_when_requesting_api_uri_with_auth_token
    session[:_csrf_token] = 'token'
    logout_as_nil
    session[:login] = 'admin'
    post :create, {:api_version => 'v2', "project_id" => @project.identifier,
      :format => 'xml', :authenticity_token => 'token',
      :card => {:name => 'This is my card', :card_type => @project.card_types.first}
    }
    assert_response :created
  end

  def test_auth_user_by_session_when_it_is_not_api_request_uri
    session[:_csrf_token] = 'token'
    logout_as_nil
    session[:login] = 'admin'
    post :create, {
      "project_id" => @project.identifier,
      :authenticity_token => 'token',
      :card => {:name => 'This is my card', :card_type => @project.card_types.first}
    }
    assert_redirected_to :controller => 'cards', :action => 'list'
  end

  def test_authorize_user_with_github_webhook
    @controller = create_controller GithubController
    @controller.request = @request
    @controller.response = @response

    logout_as_nil

    user = create_user!(:login => 'bob@mingle.com')
    @project.add_member(user)
    user.update_api_key

    commits = ['[{"id":"4fbee7a1ae639e07bd7792da0912bb7e4015a0e1","distinct":true,"message":"changing for push","timestamp":"2014-04-30T13:57:01-07:00","url":"https://github.com/betarelease/test_push/commit/4fbee7a1ae639e07bd7792da0912bb7e4015a0e1","author":{"name":"Sudhindra Rao","email":"sudhindra.r.rao@gmail.com","username":"betarelease"},"committer":{"name":"Sudhindra Rao","email":"sudhindra.r.rao@gmail.com","username":"betarelease"},"added":[],"removed":[],"modified":["README.md"]}]']
    repository = '{"id":19327016,"name":"test_push","url":"https://github.com/betarelease/test_push","description":"testing push webhooks","watchers":0,"stargazers":0,"forks":0,"fork":false,"size":0,"owner":{"name":"betarelease","email":"sudhindra.r.rao@gmail.com"},"private":false,"open_issues":0,"has_issues":true,"has_downloads":true,"has_wiki":true,"created_at":1398891366,"pushed_at":1398891485,"master_branch":"master"}'

    github_data = '{"commmits":"#{commits}", "repository":"#{repository}"}'

    hmac_digest = OpenSSL::Digest::Digest.new('sha1')
    hmac_signature = OpenSSL::HMAC.hexdigest(hmac_digest, user.api_key, github_data)
    @request.env["HTTP_X_HUB_SIGNATURE"] = "sha1=#{hmac_signature}"
    @request.env['RAW_POST_DATA'] = github_data

    post :receive,{"project_id" => @project.identifier, :format => :json, :commits => commits, :repository => repository, :user => "bob@mingle.com"}

    assert_response :ok
  end

end
