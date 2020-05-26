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

class SlackApiLoginSystemTest < ActionController::TestCase
  include IntegrationsHelper
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

  def test_set_current_user_as_instance_of_api_user_when_sass_env_is_not_set
    @controller.request = @request
    @controller.response = @response

    MingleConfiguration.overridden_to(:authentication_keys => 'key1',
                                      :slack_encryption_key => 'test_encryption_key') do
      @request.env["HTTP_MINGLE_API_KEY"] = 'key1'
      @request.env["HTTP_MINGLE_SLACK_API_DATA"] = encrypted_slack_data
      get :show, {:api_version => 'v2', "project_id" => @project.identifier,
                  :format => 'xml', :authenticity_token => 'token',
                  :number => '2701' }

      assert User.current.instance_of? User::ApiUser
    end
  end

  def test_set_current_user_as_instance_of_mingle_user_and_origin_type_as_slack_for_valid_user_when_mingle_slack_api_data_exists
    @controller.request = @request
    @controller.response = @response
    member = User.current

    MingleConfiguration.overridden_to(:authentication_keys => 'key1',
                                      :slack_encryption_key => 'test_encryption_key',
                                      :saas_env => 'test') do


      @request.env["HTTP_MINGLE_API_KEY"] = 'key1'
      @request.env["HTTP_MINGLE_SLACK_API_DATA"] = encrypted_slack_data
      logout_as_nil


      post :create, {:api_version => 'v2', "project_id" => @project.identifier,
                     :format => 'xml', :authenticity_token => 'token',
                     :card => {:name => 'This is my card', :card_type => @project.card_types.first}
      }
      assert_equal member.login, User.current.login
      assert_equal Thread.current['origin_type'], 'slack'
    end
  end

  def test_set_current_user_as_instance_of_api_user_when_mingle_slack_api_data_does_not_exists
    @controller.request = @request
    @controller.response = @response

    logout_as_nil
     MingleConfiguration.overridden_to(:authentication_keys => 'key1',
                                      :slack_encryption_key => 'test_encryption_key',
                                      :saas_env => true) do

      @request.env["HTTP_MINGLE_API_KEY"] = 'key1'

      get :show, {:api_version => 'v2', "project_id" => @project.identifier,
                  :format => 'xml', :authenticity_token => 'token',
                   :number => '2701' }

      assert User.current.instance_of? User::ApiUser
    end
  end

  def test_should_deny_access_for_invalid_user
    @controller.request = @request
    @controller.response = @response

    MingleConfiguration.overridden_to(:authentication_keys => 'key1',
                                      :slack_encryption_key => 'test_encryption_key',
                                      :saas_env => 'test') do

      @request.env["HTTP_MINGLE_API_KEY"] = 'key1'
      @request.env["HTTP_MINGLE_SLACK_API_DATA"] = encrypted_slack_data(:user_id => 123345)
      logout_as_nil

      post :create, {:api_version => 'v2', "project_id" => @project.identifier,
                     :format => 'xml', :authenticity_token => 'token',
                     :card => {:name => 'This is my card', :card_type => @project.card_types.first}
      }
      assert_response 401
    end
  end

  def test_should_deny_access_when_mingle_slack_api_data_does_not_contains_desired_data
    @controller.request = @request
    @controller.response = @response

    MingleConfiguration.overridden_to(:authentication_keys => 'key1',
                                      :slack_encryption_key => 'test_encryption_key',
                                      :saas_env => 'test') do
      @request.env["HTTP_MINGLE_API_KEY"] = 'key1'
      @request.env["HTTP_MINGLE_SLACK_API_DATA"] = encrypt_data_for_slack("{}")
      logout_as_nil
      post :create, {:api_version => 'v2', "project_id" => @project.identifier,
                     :format => 'xml', :authenticity_token => 'token',
                     :card => {:name => 'This is my card', :card_type => @project.card_types.first}
      }
      assert_response 401
    end
  end

  def test_should_not_have_admin_access_on_simple_api_access
    @controller = create_controller UsersController
    @controller.request = @request
    @controller.response = @response

    MingleConfiguration.overridden_to(:authentication_keys => 'key1',
                                      :slack_encryption_key => 'test_encryption_key',
                                      :saas_env => 'test') do
      @request.env["HTTP_MINGLE_API_KEY"] = 'key1'
      @request.env["HTTP_MINGLE_SLACK_API_DATA"] = encrypt_data_for_slack("{}")
      logout_as_nil
      get :index, {:api_version => 'v2', "project_id" => @project.identifier,
                     :format => 'xml'}
      assert_response 401
    end
  end

  def test_should_login_api_user_on_invalid_json
    @controller.request = @request
    @controller.response = @response

    MingleConfiguration.overridden_to(:authentication_keys => 'key1',
                                      :slack_encryption_key => 'test_encryption_key',
                                      :saas_env => 'test') do
      @request.env["HTTP_MINGLE_API_KEY"] = 'key1'
      @request.env["HTTP_MINGLE_SLACK_API_DATA"] = encrypt_data_for_slack("{invalid json}")
      logout_as_nil
      post :create, {:api_version => 'v2', "project_id" => @project.identifier,
                     :format => 'xml', :authenticity_token => 'token',
                     :card => {:name => 'This is my card', :card_type => @project.card_types.first}
      }
      assert_response 401
    end
  end

  def test_should_have_admin_access_when_admin_value_set_in_data
    @controller = create_controller UsersController
    @controller.request = @request
    @controller.response = @response

    MingleConfiguration.overridden_to(:authentication_keys => 'key1',
                                      :slack_encryption_key => 'test_encryption_key',
                                      :saas_env => 'test') do
      @request.env["HTTP_MINGLE_API_KEY"] = 'key1'
      @request.env["HTTP_MINGLE_SLACK_API_DATA"] = encrypt_data_for_slack("{\"admin\":\"true\"}")
      logout_as_nil
      get :index, {:api_version => 'v2', "project_id" => @project.identifier, :format => 'xml'}

      assert_response 200
      assert User.current.instance_of? User::AdminApiUser
    end
  end

  private
  def encrypted_slack_data(options={})
    data_json = {
      "mingleTeamId" => @project.team.id,
      "mingleUserId"=>  options[:user_id] || User.current.id
    }.to_json
    encrypt_data_for_slack(data_json)
  end
end
