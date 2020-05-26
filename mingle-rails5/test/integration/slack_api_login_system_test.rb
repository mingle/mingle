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

class SlackApiLoginSystemTest < ActionDispatch::IntegrationTest
  include IntegrationsHelper

  def setup
    @project = create(:project, :active)
    @user = create(:user)
    MingleConfiguration.authentication_keys = 'key1'
    MingleConfiguration.slack_encryption_key = 'test_encryption_key'
    MingleConfiguration.saas_env = 'test'
    logout_as_nil
  end

  def teardown
    MingleConfiguration.authentication_keys = nil
    MingleConfiguration.slack_encryption_key = nil
    MingleConfiguration.saas_env = nil
  end

  def test_set_current_user_as_instance_of_api_user_when_saas_env_is_not_set
    MingleConfiguration.saas_env = nil
    login(@user)
    get "/api/v2#{call_me_in_test_path}.xml", env: {'HTTP_MINGLE_API_KEY': 'key1', 'HTTP_MINGLE_SLACK_API_DATA': encrypted_slack_data}

    assert_response :ok
    assert_equal('<response>successful api call</response>', @response.body)
    assert User.current.instance_of? User::ApiUser
  end

  def test_set_current_user_as_instance_of_mingle_user_and_origin_type_as_slack_for_valid_user_when_mingle_slack_api_data_exists
    post "/api/v2#{call_me_in_test_path}.xml", env: {'HTTP_MINGLE_API_KEY': 'key1', 'HTTP_MINGLE_SLACK_API_DATA': encrypted_slack_data(user_id: @user.id)}

    assert_response :ok
    assert_equal @user.login, User.current.login
    assert_equal Thread.current['origin_type'], 'slack'
  end

  def test_set_current_user_as_instance_of_api_user_when_mingle_slack_api_data_does_not_exists
    get "/api/v2#{call_me_in_test_path}.xml", env: {'HTTP_MINGLE_API_KEY': 'key1'}

    assert_response :ok
    assert User.current.instance_of? User::ApiUser
  end

  def test_should_deny_access_for_invalid_user
    post "/api/v2#{call_me_in_test_path}.xml", env: {'HTTP_MINGLE_API_KEY': 'key1', 'HTTP_MINGLE_SLACK_API_DATA': encrypted_slack_data(user_id: 123345)}

    assert_response 401
  end

  def test_should_deny_access_when_mingle_slack_api_data_does_not_contains_desired_data
    post "/api/v2#{call_me_in_test_path}.xml", env: {'HTTP_MINGLE_API_KEY': 'key1', 'HTTP_MINGLE_SLACK_API_DATA': encrypt_data_for_slack('{}')}

    assert_response 401
  end

  def test_should_not_have_admin_access_on_simple_api_access
    post "/api/v2#{call_me_in_test_path}.xml", env: {'HTTP_MINGLE_API_KEY': 'key1', 'HTTP_MINGLE_SLACK_API_DATA': encrypt_data_for_slack('{}')}

    assert_response 401
  end

  def test_should_login_api_user_on_invalid_json
    post "/api/v2#{call_me_in_test_path}.xml", env: {'HTTP_MINGLE_API_KEY': 'key1', 'HTTP_MINGLE_SLACK_API_DATA': encrypt_data_for_slack('{invalid json}')}

    assert_response 401
  end

  def test_should_have_admin_access_when_admin_value_set_in_data
    get "/api/v2#{call_me_in_test_path}.xml", env: {'HTTP_MINGLE_API_KEY': 'key1', 'HTTP_MINGLE_SLACK_API_DATA': encrypt_data_for_slack("{\"admin\":\"true\"}")}

    assert_response 200
    assert User.current.instance_of? User::AdminApiUser
  end

  private
  def encrypted_slack_data(options={})
    data_json = {
        'mingleTeamId' => @project.team.id,
        'mingleUserId' => options[:user_id] || User.current.id
    }.to_json
    encrypt_data_for_slack(data_json)
  end
end
