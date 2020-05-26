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

class IntegrationsControllerTest < ActionController::TestCase
  include IntegrationsHelper
  include SlackClientStubs

  def setup
    @controller = create_controller(IntegrationsController)
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    WebMock.reset!
    WebMock.disable_net_connect!
    MingleConfiguration.slack_app_url = 'https://slackserver.com'
    Timecop.freeze
  end

  def teardown
    MingleConfiguration.slack_app_url = nil
    WebMock.allow_net_connect!
    Timecop.return
  end

  def test_index_renders_for_admin_only
    MingleConfiguration.overridden_to(
        :slack_encryption_key => 'kkCSxzaucrCTn0GK/MEH7Q==') do
      login_as_admin

      stub_integration_status_request('', APP_INTEGRATION_SCOPE, {})

      with_fake_aws_env_for_slack_client do
        get :index
      end

      body_html = Nokogiri::HTML.parse(@response.body)
      assert_not_nil body_html.css('a img[alt="Add to Slack"]')
      assert_select '.slack-help-link', { :count => 1 }
    end
  end

  def test_index_should_redirect_for_non_admin_users
    login_as_member

    assert_raises(ErrorHandler::UserAccessAuthorizationError) do
      get :index
    end
  end

  def test_add_slack_integration_should_redirect_to_slack_url_with_encrypted_state_when_eula_accepted
    slack_client_id = 'some_client_id'
    tenant_name = 'valid-tenant-name'
    MingleConfiguration.overridden_to(
        app_namespace: tenant_name,
        slack_client_id: slack_client_id,
        slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==') do
      login_as_admin

      post :add_slack_integration, eula_acceptance: 'slack_eula_accepted'

      encrypted_state = encrypt_data_for_slack("tenantState:#{tenant_name};admin;#{Time.now.utc.milliseconds.to_i}")
      query_params = {'client_id' => slack_client_id,
                      'scope' => APP_INTEGRATION_SCOPE,
                      'state' => encrypted_state,
                      'redirect_uri' => slack_redirect_uri('authorize')}.to_query
      expected_redirect_url = "https://slack.com/oauth/authorize?#{query_params}"

      assert_redirected_to expected_redirect_url
    end
  end

  def test_add_slack_integration_should_render_index_when_eula_is_not_accepted
    login_as_admin

    post :add_slack_integration

    assert_template :index
    assert_equal 'Please accept the terms and conditions!', flash[:error]
  end

  def test_index_should_assign_team_info_when_slack_already_added
    expected_team_info = {'name' => 'ValidSlackTeam',
                 'url' => 'https://validslackteam.slack.com', 'id'=> 1}
    tenant_name = 'valid-tenant-name'

    MingleConfiguration.overridden_to(
        :app_namespace => tenant_name,
        :slack_client_id => 'some_client_id',
        :slack_encryption_key => 'kkCSxzaucrCTn0GK/MEH7Q==') do
      login_as_admin
      stub_integration_status_request(tenant_name, APP_INTEGRATION_SCOPE, {'status' => 'INTEGRATED',
                                                    'team' => expected_team_info})

      with_fake_aws_env_for_slack_client do
        get :index
      end

      team_info = assigns(:team_info)
      assert_equal expected_team_info, team_info
      assert_select '.slack-help-link', { :count => 1 }
    end
  end

  def test_index_should_assign_team_info_and_set_flash_message_when_slack_revoke_in_progress
    expected_team_info = {'name' => 'ValidSlackTeam',
                 'url' => 'https://validslackteam.slack.com', 'id'=> 1}
    tenant_name = 'valid-tenant-name'

    MingleConfiguration.overridden_to(
        :app_namespace => tenant_name,
        :slack_client_id => 'some_client_id',
        :slack_encryption_key => 'kkCSxzaucrCTn0GK/MEH7Q==') do
      login_as_admin
      stub_integration_status_request(tenant_name, APP_INTEGRATION_SCOPE, {'status' => 'REVOKE_IN_PROGRESS',
                                                    'team' => expected_team_info})

      with_fake_aws_env_for_slack_client do
        get :index
      end

      team_info = assigns(:team_info)
      assert_equal expected_team_info, team_info
      assert_equal "Mingle is being delinked from Slack. If you have any questions or concerns please write to <a href='mailto:support@thoughtworks.com'>support@thoughtworks.com</a>." ,flash.now[:notice]
      assert_select '.slack-help-link', { :count => 1 }
      assert_select '.remove-slack-integration', {:count => 0}
    end
  end

  def test_add_user_to_slack_should_redirect_to_slack_url_when_eula_accepted
    slack_client_id = 'some_client_id'
    tenant_name = 'valid-tenant-name'
    MingleConfiguration.overridden_to(
        app_namespace: tenant_name,
        slack_client_id: slack_client_id,
        slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==') do
      longbob = login_as_longbob

      post :add_user_to_slack, :eula_acceptance => 'slack_eula_accepted'

      encrypted_state = encrypt_data_for_slack({ userLogin: 'longbob',
                                                 userId: longbob.id,
                                                 userName: longbob.name,
                                                 tenantName: tenant_name,
                                                 mingleRedirectUri: "profile/show/#{longbob.id}",
                                                 eulaAcceptedAt: Time.now.utc.milliseconds.to_i
                                               }.to_json)

      query_params = {'client_id' => slack_client_id,
                      'scope' => USER_INTEGRATION_SCOPE,
                      'state' => encrypted_state,
                      'redirect_uri' => slack_redirect_uri('authorizeUser')}.to_query
      expected_redirect_url = "https://slack.com/oauth/authorize?#{query_params}"

      assert_redirected_to expected_redirect_url
    end
  end

  def test_add_user_to_slack_should_redirect_to_profile_show_when_eula_not_accepted
    slack_client_id = 'some_client_id'
    tenant_name = 'valid-tenant-name'
    MingleConfiguration.overridden_to(
        app_namespace: tenant_name,
        slack_client_id: slack_client_id,
        slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==') do
      admin = login_as_longbob

      post :add_user_to_slack

      assert_redirected_to controller: :profile, action: :show, id: admin.id, tab: 'Slack'
    end
  end

  def test_should_remove_tenant_integration
    slack_client_id = 'some_client_id'
    tenant_name = 'valid-tenant-name'
    MingleConfiguration.overridden_to(
        app_namespace: tenant_name,
        slack_client_id: slack_client_id,
        slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==') do
      login_as_admin
      users = fetch_id_to_name_map_from_query_for_test("SELECT id, name FROM users")
      projects = fetch_id_to_name_map_from_query_for_test("SELECT g.id, p.name FROM deliverables p INNER JOIN groups g ON g.name='Team' AND g.deliverable_id = p.id AND p.type = 'Project'")

      stub_remove_tenant_integration_request(tenant_name, {users: users, projects: projects})

      with_fake_aws_env_for_slack_client do
        delete :remove_slack_integration
      end

      assert_redirected_to action: :index
      assert_equal "Mingle is being delinked from Slack. If you have any questions or concerns please write to <a href='mailto:support@thoughtworks.com'>support@thoughtworks.com</a>.", flash[:notice]
    end
  end

  def test_should_remove_user_integration
    slack_client_id = 'some_client_id'
    tenant_name = 'valid-tenant-name'
    MingleConfiguration.overridden_to(
        app_namespace: tenant_name,
        slack_client_id: slack_client_id,
        slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==') do
      member = login_as_member
      stub_remove_integration_request(tenant_name, 'User', {user_id: member.id, user_name: member.name})

      with_fake_aws_env_for_slack_client do
        delete :remove_user_from_slack
      end

      assert_redirected_to controller: :profile, action: :show, id: member.id, tab: 'Slack'
      assert_equal "Mingle user profile has been delinked from Slack. If you have any questions or concerns please write to <a href='mailto:support@thoughtworks.com'>support@thoughtworks.com</a>.", flash[:notice]
    end
  end

  def test_should_redirect_to_integration_help_link
    tenant_name = 'valid-tenant-name'

    MingleConfiguration.overridden_to(
        :app_namespace => tenant_name,
        :slack_client_id => 'some_client_id',
        :slack_encryption_key => 'kkCSxzaucrCTn0GK/MEH7Q==') do
      login_as_admin
      stub_integration_status_request(tenant_name, APP_INTEGRATION_SCOPE, {'status' => 'NOT_INTEGRATED'})

      with_fake_aws_env_for_slack_client do
        get :slack_integration_help
      end
    end
  end

  private
  def fetch_id_to_name_map_from_query_for_test(query)
    ActiveRecord::Base.connection.select_all(query).inject({}) { |result, item| result[item['id'].to_s] = item['name']; result }
  end
end
