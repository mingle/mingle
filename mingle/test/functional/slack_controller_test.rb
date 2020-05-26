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

class SlackControllerTest < ActionController::TestCase
  include SlackClientStubs
  include IntegrationsHelper


  def setup
    @controller = create_controller(SlackController)
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    WebMock.reset!
    WebMock.disable_net_connect!
    MingleConfiguration.slack_app_url = 'https://slackserver.com'
    Timecop.freeze
    @scope= 'identify,commands,chat:write:bot,channels:read,users:read'
    @user_integration_scope = IntegrationsHelper::USER_INTEGRATION_SCOPE + ',groups:read'
    @project = with_new_project(:anonymous_accessible => false, :membership_requestable => false) do |project|
      project.add_member(User.find_by_login('proj_admin'), :project_admin)
    end
    @project.activate
  end

  def teardown
    MingleConfiguration.slack_app_url = nil
    WebMock.allow_net_connect!
    Timecop.return
  end


  def test_index_should_not_render_authenticate_link_when_slack_integration_exists_and_user_is_authenticated
    user_info = {'name' => 'slack_user_name'}
    tenant_name = 'valid-tenant-name'
    expected_team_info = {'name' => 'ValidSlackTeam',
                          'url' => 'https://validslackteam.slack.com'}

    slack_channel_name = 'ValidSlackChannel'
    expected_channels_info = [{'name' => slack_channel_name, 'id' => '2', 'mapped' => false, 'teamId' => 1, 'private'=>'false'}]
    MingleConfiguration.overridden_to(
        :app_namespace => tenant_name,
        :slack_client_id => 'some_client_id',
        :slack_encryption_key => 'kkCSxzaucrCTn0GK/MEH7Q==') do

        login_as_proj_admin
        stub_integration_status_request(tenant_name, @scope, {'status' => 'INTEGRATED',
                                                            'team' => expected_team_info})

        stub_user_integration_status_request(tenant_name, User.current.id, @user_integration_scope , {'authenticated' => true, 'user' => user_info})

        stub_list_channels_request(tenant_name, @project.team.id,User.current.id,{'channels'=> expected_channels_info, 'teamMapped'=>false})
        with_fake_aws_env_for_slack_client do
          get :index, :project_id => @project.identifier
        end
      assert_select 'div#slack_content_intro p:nth-of-type(2)' , :text => /This instance of Mingle has been linked with the Slack team #{expected_team_info['name']}/
      assert_select 'div#slack_authentication a.ok' , false
      assert_select '.slack-help-link', :count => 1
    end
  end


  def test_index_should_show_correct_message_when_private_channel_is_visible_to_user
    user_info = {'name' => 'slack_user_name'}
    expected_team_info = {'name' => 'ValidSlackTeam',
                          'url' => 'https://validslackteam.slack.com'}
    tenant_name = 'valid-tenant-name'
    private_channel_name = 'ValidSlackChannel1'
    expected_mapped_channel = {'name' => private_channel_name, 'id' => '1', 'mapped' => false, 'teamId' => @project.team.id, 'private'=>true}

    public_channel_name = 'ValidSlackChannel2'
    expected_channels_info = [expected_mapped_channel, {'name' => public_channel_name, 'id' => '2', 'mapped' => false, 'teamId' => 1, 'private'=>false}]
    MingleConfiguration.overridden_to(
        :app_namespace => tenant_name,
        :slack_client_id => 'some_client_id',
        :slack_encryption_key => 'kkCSxzaucrCTn0GK/MEH7Q==') do

      login_as_proj_admin
      stub_integration_status_request(tenant_name, @scope, {'status' => 'INTEGRATED',
                                                            'team' => expected_team_info})
      stub_user_integration_status_request(tenant_name, User.current.id, @user_integration_scope, {'authenticated' => true, 'user' => user_info})
      stub_list_channels_request(tenant_name, @project.team.id, User.current.id,{'channels'=> expected_channels_info,'teamMapped'=>false})
      with_fake_aws_env_for_slack_client do
        get :index, :project_id => @project.identifier
      end
      assert_select 'div#select_slack_channel option:nth-child(1)' , :text => 'Select Channel'
      assert_select 'div#select_slack_channel option' , :text => private_channel_name
      assert_select 'div#select_slack_channel option' , :text => public_channel_name
    end
  end

  def test_index_should_show_relevant_message_when_full_team_member_checks_slack_integration_page
    user_info = {'name' => 'slack_user_name'}
    expected_team_info = {'name' => 'ValidSlackTeam',
                          'url' => 'https://validslackteam.slack.com'}
    tenant_name = 'valid-tenant-name'

    MingleConfiguration.overridden_to(
        :app_namespace => tenant_name,
        :slack_client_id => 'some_client_id',
        :slack_encryption_key => 'kkCSxzaucrCTn0GK/MEH7Q==') do
      full_member = create_user!
      @project.add_member(full_member, :full_member)
      login(full_member)
      stub_integration_status_request(tenant_name, @scope, {'status' => 'INTEGRATED',
                                                            'team' => expected_team_info})
      stub_user_integration_status_request(tenant_name, User.current.id, @user_integration_scope, {'authenticated' => true, 'user' => user_info})
      stub_list_channels_request(tenant_name, @project.team.id, User.current.id,{'channels'=> [],'teamMapped'=>false})
      with_fake_aws_env_for_slack_client do
        get :index, :project_id => @project.identifier
      end
      assert_select 'p.mapped_message' , :text => /This Project has not been linked to any Slack Channel, Please contact a Project admin to create this link/
    end
  end

  def test_index_should_show_correct_message_when_user_is_not_authorized_to_see_private_channels
    expected_team_info = {'name' => 'ValidSlackTeam',
                          'url' => 'https://validslackteam.slack.com'}
    tenant_name = 'valid-tenant-name'
    channel_name = 'ValidSlackChannel1'
    expected_channels = [{'name' => channel_name, 'id' => '1', 'mapped' => false, 'teamId' => @project.team.id, 'private'=>'false'}]

    MingleConfiguration.overridden_to(
        :app_namespace => tenant_name,
        :slack_client_id => 'some_client_id',
        :slack_encryption_key => 'kkCSxzaucrCTn0GK/MEH7Q==') do

      login_as_proj_admin
      stub_integration_status_request(tenant_name, @scope, {'status' => 'INTEGRATED',
                                                            'team' => expected_team_info})
      stub_user_integration_status_request(tenant_name, User.current.id, @user_integration_scope, {'authenticated' => false, 'error' => {'missingScope' => 'groups:read' }})
      stub_list_channels_request(tenant_name, @project.team.id, User.current.id,{'channels'=> expected_channels,'teamMapped'=>false})
      with_fake_aws_env_for_slack_client do
        get :index, :project_id => @project.identifier
      end
      assert_select 'div#authorization-steps a.slack-link' , :text => /Get private channel/
    end
  end

  def test_save_channel_should_return_the_mapped_channel_when_eula_accepted
    tenant_name = 'valid-tenant-name'
    channel_id = '3'

    MingleConfiguration.overridden_to(
        app_namespace: tenant_name,
        slack_client_id: 'some_client_id',
        slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==') do

      project_admin = login_as_proj_admin

      stub_map_channel_request(tenant_name, @project.identifier, @project.team.id, project_admin.id, channel_id, false, {'success' => true})

      with_fake_aws_env_for_slack_client do
        post :save_channel, project_id: @project.identifier, selected_slack_channel_id: channel_id, is_private: false, eula_acceptance: 'slack_eula_accepted'
        mapped_channel_id = assigns(:selected_slack_channel_id)

        assert_equal channel_id, mapped_channel_id
        assert true, flash[:success]
      end
    end
  end

  def test_save_channel_should_redirect_to_index_when_eula_not_accepted
    tenant_name = 'valid-tenant-name'
    channel_id = '3'

    MingleConfiguration.overridden_to(
    app_namespace: tenant_name,
    slack_client_id: 'some_client_id',
    slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==') do

      project_admin = login_as_proj_admin

      stub_map_channel_request(tenant_name, @project.identifier, @project.team.id, project_admin.id, channel_id, false, {'success' => true})

      with_fake_aws_env_for_slack_client do
        post :save_channel, project_id: @project.identifier, selected_slack_channel_id: channel_id, is_private: false

        assert_redirected_to :action => :index
        assert_equal 'Please accept the terms and conditions!', flash[:error]
      end
    end
  end

  def test_index_should_not_display_add_more_channel_sections_if_project_is_not_mapped_yet
    tenant_name = 'valid-tenant-name'

    expected_team_info = {'name' => 'ValidSlackTeam',
    'url' => 'https://validslackteam.slack.com'}

    expected_channels_list = [{'name' => 'privateChannel1', 'id' => '1', 'mapped' => false, 'teamId' => @project.team.id, 'private'=>true},
    {'name' => 'privateChannel2', 'id' => '1', 'mapped' => false, 'teamId' => @project.team.id, 'private'=>true},
    {'name' => 'openChannel1', 'id' => '1', 'mapped' => false, 'teamId' => @project.team.id, 'private'=>false},
    {'name' => 'openChannel2', 'id' => '1', 'mapped' => false, 'teamId' => @project.team.id, 'private'=>false}]

    MingleConfiguration.overridden_to(
    app_namespace: tenant_name,
    slack_client_id: 'some_client_id',
    slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==') do

      login_as_proj_admin
      stub_integration_status_request(tenant_name, @scope, {'status' => 'INTEGRATED',
      'team' => expected_team_info})
      stub_user_integration_status_request(tenant_name, User.current.id, @user_integration_scope, {'authenticated' => true, 'error' => {'missingScope' => 'groups:read' }})
      stub_list_channels_request(tenant_name, @project.team.id, User.current.id,{'channels'=> expected_channels_list,'teamMapped'=>false})

      with_fake_aws_env_for_slack_client do
        get :index, :project_id => @project.identifier
        assert_select '#add-remove-channels-header', false, 'This page should not contain add/remove channel header'
        assert_select '#add-remove-channels-content', false, 'This page should not contain add/remove channels content'
      end
    end
  end

  def test_index_should_display_add_more_channel_sections_if_project_is_mapped
    tenant_name = 'valid-tenant-name'

    expected_team_info = {'name' => 'ValidSlackTeam',
    'url' => 'https://validslackteam.slack.com'}

    expected_channels_list = [
      {'name' => 'privateChannel2', 'id' => '2', 'mapped' => true, 'teamId' => @project.team.id, 'private'=>true , 'isPrimary' => false},
      {'name' => 'privateChannel1', 'id' => '1', 'mapped' => false, 'teamId' => @project.team.id, 'private'=>true, 'isPrimary' => false},
      {'name' => 'openChannel2', 'id' => '4', 'mapped' => true, 'teamId' => @project.team.id, 'private'=>false, 'isPrimary' => true},
      {'name' => 'openChannel1', 'id' => '3', 'mapped' => true, 'teamId' => @project.team.id, 'private'=>false , 'isPrimary' => false}
    ]

    MingleConfiguration.overridden_to(
    app_namespace: tenant_name,
    slack_client_id: 'some_client_id',
    slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==') do

      login_as_proj_admin
      stub_integration_status_request(tenant_name, @scope, {'status' => 'INTEGRATED',
      'team' => expected_team_info})
      stub_user_integration_status_request(tenant_name, User.current.id, @user_integration_scope, {'authenticated' => true, 'error' => {'missingScope' => 'groups:read' }})
      stub_list_channels_request(tenant_name, @project.team.id, User.current.id,{'channels'=> expected_channels_list,'teamMapped'=>true})

      with_fake_aws_env_for_slack_client do
        get :index, :project_id => @project.identifier
        assert_select '#add-remove-channels-header'
        assert_select '#add-remove-channels-content'
        assert_select '.primary-channel strong', :text => '#&nbsp;openChannel2'
        assert_select '.slack-channel-container li input', :count => 3
        assert_select '.slack-channel-container #toggle_channel_1[checked]', :count => 0
        assert_select '.slack-channel-container #toggle_channel_2[checked]', :count => 1
        assert_select '.slack-channel-container #toggle_channel_4', :count => 0

        assert_select 'ul.slack-channel-container li input' do |elements|
          actual_channel_names = elements.map do |element|
            element.attributes['data-channel-name']
          end
          assert_equal(%w(openChannel1 privateChannel1 privateChannel2), actual_channel_names)
        end
      end
    end
  end


  def test_index__add_more_channel_sections_should_not_include_non_primary_mapped_channel_of_other_team
    tenant_name = 'valid-tenant-name'

    expected_team_info = {'name' => 'ValidSlackTeam',
                          'url' => 'https://validslackteam.slack.com'}

    expected_channels_list = [
        {'name' => 'privateChannel1', 'id' => '1', 'mapped' => false, 'private'=>true, 'isPrimary' => false},
        {'name' => 'privateChannel2', 'id' => '2', 'mapped' => true, 'teamId' => @project.team.id, 'private'=>true , 'isPrimary' => false},
        {'name' => 'openChannel1', 'id' => '3', 'mapped' => true, 'teamId' => @project.team.id, 'private'=>false , 'isPrimary' => false},
        {'name' => 'openChannel2', 'id' => '4', 'mapped' => true, 'teamId' => @project.team.id, 'private'=>false, 'isPrimary' => true},
        {'name' => 'privateChannel5', 'id' => '5', 'mapped' => true, 'teamId' => 130, 'private'=>true, 'isPrimary' => false},
        {'name' => 'privateChannel6', 'id' => '6', 'mapped' => true, 'teamId' => 132, 'private'=>true, 'isPrimary' => true}
    ]

    MingleConfiguration.overridden_to(
        app_namespace: tenant_name,
        slack_client_id: 'some_client_id',
        slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==') do

      login_as_proj_admin
      stub_integration_status_request(tenant_name, @scope, {'status' => 'INTEGRATED',
                                                            'team' => expected_team_info})
      stub_user_integration_status_request(tenant_name, User.current.id, @user_integration_scope, {'authenticated' => true, 'error' => {'missingScope' => 'groups:read' }})
      stub_list_channels_request(tenant_name, @project.team.id, User.current.id,{'channels'=> expected_channels_list,'teamMapped'=>true})

      with_fake_aws_env_for_slack_client do
        get :index, :project_id => @project.identifier
        assert_select '#add-remove-channels-header'
        assert_select '#add-remove-channels-content'
        assert_select '.slack-channel-container li input', :count => 3
        assert_select '.slack-channel-container #toggle_channel_5', :count => 0
        assert_select '.slack-channel-container #toggle_channel_6', :count => 0
      end
    end
  end

  def test_remove_slack_integration_for_project
    tenant_name = 'valid-tenant-name'

    MingleConfiguration.overridden_to(
        app_namespace: tenant_name,
        slack_client_id: 'some_client_id',
        slack_feedback_form_url: 'slack_feedback_form_url',
        slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==') do

      login_as_proj_admin
      stub_remove_integration_request(tenant_name, 'Channel', {team_id: @project.team.id, project_name: @project.name})

      with_fake_aws_env_for_slack_client do
        delete :remove_slack_integration, project_id: @project.identifier

        assert_redirected_to action: :index
        assert_equal "Project has been delinked from Slack. If you have any questions or concerns please write to <a href='mailto:support@thoughtworks.com'>support@thoughtworks.com</a>.", flash[:notice]
      end
    end
  end

  def test_update_channel_mappings_should_update_mappings
    login_as_proj_admin

    tenant_name = 'tenant'
    project_name = @project.name
    mingle_user_id = User.current.id
    mingle_team_id = @project.team.id
    slack_channel1_name = 'slackChannel1'
    slack_channel2_name = 'slackChannel2'
    channels_to_update = [{channelId: '1', name: slack_channel1_name, action: 'Add', private: true}, {channelId: '2', name: slack_channel2_name, action: 'Remove', private: false}]

    request_body = {tenantName: tenant_name, projectName: project_name, mingleTeamId: mingle_team_id, mingleUserId: mingle_user_id,  channelsToUpdate: channels_to_update}
    updated_channels = [{channelId: '1', name: slack_channel1_name, mapped: false, error: 'channel_already_mapped'}, {channelId: '2', name: slack_channel2_name, mapped: false}]

    expected_error = "Mapping could not be updated for the following Slack channel: #{slack_channel1_name}. Please try again in sometime."
    MingleConfiguration.overridden_to(
              app_namespace: tenant_name,
              slack_client_id: 'some_client_id',
              slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==') do

      stub_update_channel_mappings_request(request_body,  {ok: true, updatedChannels: updated_channels})

      with_fake_aws_env_for_slack_client do
        post :update_channel_mappings, :channelsToUpdate => channels_to_update, :project_id => @project.identifier
        response_body = ActiveSupport::JSON::decode(@response.body)
        assert_equal expected_error, response_body['error']
        assert_equal updated_channels.to_json, response_body['updatedChannels'].to_json
      end
    end
  end

  def test_update_channel_mappings_should_render_error_when_channels_to_update_parameter_does_not_exisit
    login_as_proj_admin
    post :update_channel_mappings, :project_id => @project.identifier
    assert_response 400
  end

  def test_update_channel_mappings_should_render_error_when_tenant_name_is_invalid
    login_as_proj_admin
    tenant_name = 'invalid-tenant'
    project_name = @project.name
    mingle_user_id = User.current.id
    mingle_team_id = @project.team.id
    slack_channel1_name = 'slackChannel1'
    slack_channel2_name = 'slackChannel2'
    channels_to_update = [{channelId: '1', name: slack_channel1_name, action: 'Add', private: true}, {channelId: '2', name: slack_channel2_name, action: 'Remove', private: false}]
    request_body = {tenantName: tenant_name, projectName: project_name, mingleTeamId: mingle_team_id, mingleUserId: mingle_user_id,  channelsToUpdate: channels_to_update}

    invalid_tenant_error_message = 'Invalid tenant name'

    MingleConfiguration.overridden_to(
        app_namespace: tenant_name,
        slack_client_id: 'some_client_id',
        slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==') do

      stub_update_channel_mappings_request(request_body,  {ok: false, error: invalid_tenant_error_message})

      with_fake_aws_env_for_slack_client do
        post :update_channel_mappings, :channelsToUpdate => channels_to_update, :project_id => @project.identifier
        response_body = ActiveSupport::JSON::decode(@response.body)
        assert_equal invalid_tenant_error_message, response_body['error']
      end
    end
  end
end
