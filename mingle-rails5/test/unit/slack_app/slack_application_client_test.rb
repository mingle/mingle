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
require File.expand_path(File.dirname(__FILE__) + '/fake_credentials')

class SlackApplicationClientTest < ActiveSupport::TestCase
  include SlackClientStubs

  def setup
    WebMock.reset!
    WebMock.disable_net_connect!
    MingleConfiguration.slack_app_url = 'https://slackserver.com'
    @slack_app_client = SlackApplicationClient.new(FakeCredentials.new)
    freeze_time
  end

  def teardown
    MingleConfiguration.slack_app_url = nil
    WebMock.allow_net_connect!
    travel_back
  end

  def test_slack_integration_exists_for_tenant
    tenant_name = 'authorized-tenant'
    team_info = {'name' => tenant_name,
                 'url' => 'https://authorized-tenant.slack.com/'}
    scope = 'chat:bot:write'
    stub_integration_status_request(tenant_name, scope,{'status' => 'INTEGRATED',
                                             'team' => team_info})

    integration_status = @slack_app_client.integration_status(tenant_name, scope)

    assert_equal 'INTEGRATED', integration_status[:status]
    assert_equal team_info, integration_status[:team]
  end

  def test_slack_integration_status_should_return_false
    scope = 'some:scope'
    stub_integration_status_request('unauthorized-tenant', scope, {'status' => 'NOT_INTEGRATED'})
    assert_equal 'NOT_INTEGRATED', @slack_app_client.integration_status('unauthorized-tenant', scope)[:status]

    stub_integration_status_request('invalid_tenant', scope, {'status' => 'NOT_INTEGRATED'})
    assert_equal 'NOT_INTEGRATED', @slack_app_client.integration_status('invalid_tenant', scope)['status']
  end

  def test_remove_tenant_integration_should_invoke_slack_app_tenant_removal_method
    tenant_name = 'integrated-tenant'
    projects = {"1" => "Project One", "2" => "Project Two"}
    users = {"3" => "User One", "4" => "User Two"}
    stub_remove_tenant_integration_request(tenant_name, {projects: projects, users: users})

    @slack_app_client.remove_tenant_integration(tenant_name, {projects: projects, users: users})
  end

  def test_remove_integration_for_channel_type_should_invoke_slack_app_with_project_details
    tenant_name = 'integrated-tenant'
    team_id = 1234
    project_name = 'First project'
    stub_remove_integration_request('integrated-tenant', 'channel', {team_id: team_id, project_name: project_name})
    @slack_app_client.remove_integration(tenant_name, 'channel', {project_name: project_name, team_id: team_id})
  end


  def test_remove_integration_for_user_type_should_invoke_slack_app_with_user_details
    tenant_name = 'integrated-tenant'
    user_id = 5678
    user_name = 'First User'
    stub_remove_integration_request('integrated-tenant', 'user', {user_id: user_id, user_name: user_name})
    @slack_app_client.remove_integration(tenant_name, 'user', {user_name: user_name, user_id: user_id})
  end

  def test_list_channels_should_list_all_channels_for_authorized_tenants
    channels = [{'id' => 'C1A4W66HZ', 'name' => 'general'},
                {'id' => 'C1A671XK2', 'name' => 'random'}]
    tenant_name = 'authorized-tenant'
    mingleTeamId = 1234
    mingleUserId = 5678

    stub_list_channels_request(tenant_name, mingleTeamId, mingleUserId, {'channels' => channels})

    assert_equal channels, @slack_app_client.list_channels(tenant_name, mingleTeamId, mingleUserId)[:channels]
  end

  def test_list_channels_should_return_empty_list_for_unauthorized_tenants
    tenant_name = 'unauthorized-tenant'
    mingleTeamId = 1234
    mingleUserId = 5678

    stub_list_channels_request(tenant_name, mingleTeamId, mingleUserId, {'channels' => []})

    assert_equal [], @slack_app_client.list_channels(tenant_name, mingleTeamId, mingleUserId)[:channels]
  end

  def test_slack_user_integration_status_when_authenticated
    scope = 'some:scope'
    user_info = {'name' => 'slack_user_name'}
    tenant_name = 'authorized-tenant'
    stub_user_integration_status_request(tenant_name, 1234, scope, {'authenticated' => true, 'user' => user_info})
    user_integration_status = @slack_app_client.user_integration_status(tenant_name, 1234, scope)
    assert user_integration_status['authenticated']
    assert_equal user_info, user_integration_status['user']
  end

  def test_slack_user_integration_status_when_not_authenticated
    scope = 'some:scope'
    tenant_name = 'authorized-tenant'
    stub_user_integration_status_request(tenant_name, 1234, scope, {'authenticated' => false, 'user' => nil})
    user_integration_status = @slack_app_client.user_integration_status(tenant_name, 1234, scope)
    assert !user_integration_status['authenticated']
  end

  def test_map_transition_should_invoke_slack_app_map_transition
    tenant_name = 'integrated-tenant'
    team_id = 1234
    transition_id = 99
    slack_channel_id = 'GDHDH99'
    transition_name = 'transition'
    stub_map_transition_request(tenant_name, {team_id: team_id, slack_channel_id: slack_channel_id, transition_id: transition_id, transition_name: transition_name}, {ok: true})
    @slack_app_client.map_transition(tenant_name, team_id, slack_channel_id, transition_id, transition_name)
  end

  def test_map_channel_should_return_success
    tenant_name = 'authorized-tenant'
    mingle_project_name = 'mingleProject'
    mingle_team_id = 1234
    mingle_user_id = 123
    channel_id = 'C1A671XK2'
    stub_map_channel_request(tenant_name, mingle_project_name, mingle_team_id, mingle_user_id, channel_id, false, {success: true})

    response = @slack_app_client.map_channel(tenant_name, mingle_project_name, mingle_team_id, mingle_user_id, channel_id, false)

    assert response[:success]
  end

  def test_map_channel_should_return_error_on_failure
    tenant_name = 'authorized-tenant'
    mingle_project_name = 'mingleProject'
    mingle_team_id = 1234
    mingle_user_id = 123
    channel_id = 'invalid_channel'
    stub_map_channel_request(tenant_name, mingle_project_name, mingle_team_id, mingle_user_id, channel_id, true, {success: false, error: 'slack_channel_not_valid'})

    response = @slack_app_client.map_channel(tenant_name, mingle_project_name, mingle_team_id, mingle_user_id, channel_id, true)

    assert !response[:success]
    assert_equal 'slack_channel_not_valid', response[:error]
  end

  def test_mapped_projects_should_return_all_the_project_mappings_for_current_tenant_if_not_specified
    tenant_name = 'authorized-tenant'
    mappings = [{id: 1, mingleTeamId: 1, tenantMappingId: 1, slackChannelId: 'slackChannelOneId'}.with_indifferent_access,
                {id: 2, mingleTeamId: 2, tenantMappingId: 1, slackChannelId: 'slackChannelTwoId'}.with_indifferent_access]

    MingleConfiguration.overridden_to(app_namespace: tenant_name) do
      stub_mapped_projects_request(tenant_name, {ok: true, mappings: mappings})

      response = @slack_app_client.mapped_projects

      assert response[:ok]
      assert_equal mappings, response[:mappings]
    end
  end

  def test_mapped_projects_should_return_all_the_project_mappings_for_specified_tenant
    tenant_name = 'authorized-tenant'
    mappings = [{id: 1, mingleTeamId: 1, tenantMappingId: 1, slackChannelId: 'slackChannelOneId'}.with_indifferent_access,
                {id: 2, mingleTeamId: 2, tenantMappingId: 1, slackChannelId: 'slackChannelTwoId'}.with_indifferent_access]

    MingleConfiguration.overridden_to(app_namespace: 'some-tenant') do
      stub_mapped_projects_request(tenant_name, {ok: true, mappings: mappings})

      response = @slack_app_client.mapped_projects(tenant_name)

      assert response[:ok]
      assert_equal mappings, response[:mappings]
    end
  end

  def test_mapped_projects_should_return_error_response_for_invalid_tenants
    tenant_name = 'authorized-tenant'

    MingleConfiguration.overridden_to(app_namespace: 'some-tenant') do
      stub_mapped_projects_request(tenant_name, {ok: false, error: 'tenant_does_not_exist'})

      response = @slack_app_client.mapped_projects(tenant_name)

      assert_false response[:ok]
      assert_equal 'tenant_does_not_exist', response[:error]
    end
  end

  def test_update_channel_mappings_should_add_and_remove_specified_channels
    tenant_name = 'tenant'
    project_name = 'test-project'
    mingle_user_id = 23
    mingle_team_id = 12
    slack_channel1_name = 'slackChannel1'
    slack_channel2_name = 'slackChannel2'

    channels_to_update = [{channelId: '1', name: slack_channel1_name, action: 'Add', private: true}, {channelId: '2', name: slack_channel2_name, action: 'Remove', private: false}]

    request_body = {tenantName: tenant_name, projectName: project_name, mingleTeamId: mingle_team_id, mingleUserId: mingle_user_id,  channelsToUpdate: channels_to_update}
    updated_channels = [{channelId: '1', name: slack_channel1_name, mapped: false, error: 'channel_already_mapped'}, {channelId: '2', name: slack_channel2_name, mapped: false}]

    MingleConfiguration.overridden_to(app_namespace: 'some-tenant') do
      stub_update_channel_mappings_request(request_body,  {ok: true, updated_channels: updated_channels})

      response = @slack_app_client.update_channel_mappings(tenant_name, project_name, mingle_team_id, mingle_user_id, channels_to_update)

      assert response[:ok]
    end
  end

  def test_update_channel_mappings_should_return_error_message_when_channel_is_already_mapped
    tenant_name = 'tenant'
    project_name = 'test-project'
    mingle_user_id = 23
    mingle_team_id = 12
    slack_channel1_name = 'slackChannel1'
    slack_channel2_name = 'slackChannel2'

    channels_to_update = [{channelId: '1', name: slack_channel1_name, action: 'Add', private: true}, {channelId: '2', name: slack_channel2_name, action: 'Remove', private: false}]

    request_body = {tenantName: tenant_name, projectName: project_name, mingleTeamId: mingle_team_id, mingleUserId: mingle_user_id,  channelsToUpdate: channels_to_update}
    updated_channels = [{channelId: '1', name: slack_channel1_name, mapped: false, error: 'channel_already_mapped'}, {channelId: '2', name: slack_channel2_name, mapped: false}]

    MingleConfiguration.overridden_to(app_namespace: 'some-tenant') do
      stub_update_channel_mappings_request(request_body,  {ok: true, updatedChannels: updated_channels})

      response = @slack_app_client.update_channel_mappings(tenant_name, project_name, mingle_team_id, mingle_user_id, channels_to_update)

      assert response[:ok]
      assert response[:updatedChannels].first[:error].eql?('channel_already_mapped')
      assert response[:updatedChannels].last[:error].nil?
    end
  end
end
