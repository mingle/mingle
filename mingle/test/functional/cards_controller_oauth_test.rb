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

class CardsControllerOauthTest < ActionController::TestCase

  def setup
    @controller = create_controller CardsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @project = first_project
    @project.activate
    logout_as_nil
  end

  def test_should_get_card_using_valid_oauth_token_only_for_api_access_only_on_ssl
    card = @project.cards.first
    user = User.find_by_login('member')
    oauth_client = Oauth2::Provider::OauthClient.create!(:name => 'foo application', :redirect_uri => 'http://does.not.exist/cb')
    token = Oauth2::Provider::OauthToken.create!(:user_id => user.id.to_s, :oauth_client_id => oauth_client.id)

    @request.env["Authorization"] = %{Token token="#{token.access_token}"}
    assert_raise_with_message(Oauth2::Provider::HttpsRequired, 'HTTPS is required for OAuth Authorizations') do
      get :show, :project_id => @project.identifier, :number => card.number, :api_version => "v2", :format => 'xml'
    end
  end

  def test_should_get_card_using_valid_oauth_token_only_for_api_access
   card = @project.cards.first
   user = User.find_by_login('member')
   oauth_client = Oauth2::Provider::OauthClient.create!(:name => 'foo application', :redirect_uri => 'http://does.not.exist/cb')
   token = Oauth2::Provider::OauthToken.create!(:user_id => user.id.to_s, :oauth_client_id => oauth_client.id)

   @request.env["Authorization"] = %{Token token="#{token.access_token}"}
   @request.env['HTTPS'] = 'on'
   get :show, :project_id => @project.identifier, :number => card.number, :api_version => "v2", :format => 'xml'
   assert_response :ok

   assert_select "card number", card.number.to_s
  end

  def test_should_not_get_card_using_valid_oauth_token_for_non_api_access
    card = @project.cards.first
    user = User.find_by_login('member')
    oauth_client = Oauth2::Provider::OauthClient.create!(:name => 'foo application', :redirect_uri => 'http://does.not.exist/cb')
    token = Oauth2::Provider::OauthToken.create!(:user_id => user.id.to_s, :oauth_client_id => oauth_client.id)

    @request.env["Authorization"] = %{Token token="#{token.access_token}"}
    @request.env['HTTPS'] = 'on'
    get :show, :project_id => @project.identifier, :number => card.number
    assert_response :redirect
    assert_redirected_to :controller => :profile, :action => :login
  end

  def test_should_not_authenticate_if_access_token_invalid
   card = @project.cards.first

   @request.env["Authorization"] = %{Token token="1234"}
   @request.env['HTTPS'] = 'on'
   get :show, :project_id => @project.identifier, :number => card.number, :api_version => "v2", :format => 'xml'

   assert_response :unauthorized
   assert_equal "The OAuth token provided is invalid.", @response.body
  end

  pending "this test was passed, because we wrote this test without change_license_to_allow_anonymous_access, see bug #11241"
  def test_should_not_authenticate_if_using_valid_token_and_user_was_deleted_even_if_project_is_anonymous_access_enabled
    change_license_to_allow_anonymous_access
    token = nil
    User.with_first_admin do
      @project.anonymous_accessible = true
      @project.save

      user = User.find_by_login('member')

      oauth_client = Oauth2::Provider::OauthClient.create!(:name => 'foo application', :redirect_uri => 'http://does.not.exist/cb')
      token = Oauth2::Provider::OauthToken.create!(:user_id => user.id.to_s, :oauth_client_id => oauth_client.id)
      user.delete
    end

    card = @project.cards.first

    @request.env["Authorization"] = %{Token token="#{token.access_token}"}
    @request.env['HTTPS'] = 'on'

    get :show, :project_id => @project.identifier, :number => card.number, :api_version => "v2", :format => 'xml'
    assert_response '401'
  ensure
    reset_license
  end

  def test_should_not_authenticate_if_access_token_is_valid_but_user_is_deleted
    token = nil
    User.with_first_admin do
      user = User.find_by_login('member')

      oauth_client = Oauth2::Provider::OauthClient.create!(:name => 'foo application', :redirect_uri => 'http://does.not.exist/cb')
      token = Oauth2::Provider::OauthToken.create!(:user_id => user.id.to_s, :oauth_client_id => oauth_client.id)
      user.delete
    end

    card = @project.cards.first

    @request.env["Authorization"] = %{Token token="#{token.access_token}"}
    @request.env['HTTPS'] = 'on'
    assert_raise ApplicationController::UserAccessAuthorizationError do
      get :show, :project_id => @project.identifier, :number => card.number, :api_version => "v2", :format => 'xml'
    end
  end

  def test_should_not_authenticate_using_valid_oauth_token_if_not_api_request
    card = @project.cards.first
    user = User.find_by_login('member')
    oauth_client = Oauth2::Provider::OauthClient.create!(:name => 'foo application', :redirect_uri => 'http://does.not.exist/cb')
    token = Oauth2::Provider::OauthToken.create!(:user_id => user.id.to_s, :oauth_client_id => oauth_client.id)

    @request.env["Authorization"] = %{Token token="#{token.access_token}"}
    @request.env['HTTPS'] = 'on'
    get :show, :project_id => @project.identifier, :number => card.number

    assert_redirected_to :controller => :profile, :action => :login
  end

  def test_should_always_reset_current_user_when_authenticate
    card = @project.cards.first
    user = User.find_by_login('member')
    oauth_client = Oauth2::Provider::OauthClient.create!(:name => 'foo application', :redirect_uri => 'http://does.not.exist/cb')
    token = Oauth2::Provider::OauthToken.create!(:user_id => user.id.to_s, :oauth_client_id => oauth_client.id)

    @request.env["Authorization"] = %{Token token="#{token.access_token}"}
    @request.env['HTTPS'] = 'on'
    get :show, :project_id => @project.identifier, :number => card.number, :api_version => "v2", :format => 'xml'
    assert !User.current.anonymous?

    @request.env["Authorization"] = %{Token token="#{token.access_token}"}
    @request.env['HTTPS'] = 'on'
    User.current.delete

    assert_raise ApplicationController::UserAccessAuthorizationError do
      get :show, :project_id => @project.identifier, :number => card.number, :api_version => "v2", :format => 'xml'
    end
    assert User.current.anonymous?
  end


end
