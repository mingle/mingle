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
require File.expand_path(File.dirname(__FILE__) + '/../documentation_test_helper')

class SlackHelperTest < ActiveSupport::TestCase
  include SlackHelper
  include SlackClientStubs
  include DocumentationTestHelper

  def setup
    WebMock.reset!
    WebMock.disable_net_connect!
    MingleConfiguration.slack_app_url = 'https://slackserver.com'
    Timecop.freeze
    @scope=  IntegrationsHelper::APP_INTEGRATION_SCOPE
    @user_integration_scope = IntegrationsHelper::USER_INTEGRATION_SCOPE
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

  def test_formatted_channels_should_sort_private_and_public_channels_seperately
    public_channel1 = OpenStruct.new(name: 'channel3', id: '3', private: false)
    private_channel1 = OpenStruct.new(name: 'channel2', id: '2', private: true)
    public_channel2 = OpenStruct.new(name: 'channel1', id: '1', private: false)
    private_channel2 = OpenStruct.new(name: 'channel4', id: '4', private: true)
    channels = [public_channel1,
                private_channel1,
                public_channel2,
                private_channel2]

    expected_private_channels = [['channel2', '2'], ['channel4', '4']]
    expected_public_channels = [['channel1', '1'], ['channel3', '3']]

    formatted_channels = Hash[formatted_channels(channels, false)]

    assert_equal(expected_public_channels, formatted_channels['Open channels'])
    assert_equal(expected_private_channels, formatted_channels['Private channels'])
  end

  def test_formatted_channels_should_not_reject_mapped_channel
    public_channel1 = OpenStruct.new(name: 'channel3', id: '3', private: false, mapped:true)
    private_channel1 = OpenStruct.new(name: 'channel2', id: '2', private: true, mapped:true)
    public_channel2 = OpenStruct.new(name: 'channel1', id: '1', private: false, mapped:false)
    private_channel2 = OpenStruct.new(name: 'channel4', id: '4', private: true, mapped:false)
    channels = [public_channel1,
                private_channel1,
                public_channel2,
                private_channel2]

    expected_private_channels = [['channel2', '2'], ['channel4', '4']]
    expected_public_channels = [['channel1', '1'], ['channel3', '3']]

    formatted_channels = Hash[formatted_channels(channels, false)]

    assert_equal(expected_public_channels, formatted_channels['Open channels'])
    assert_equal(expected_private_channels, formatted_channels['Private channels'])
  end

  def test_formatted_channels_should_reject_mapped_channel
    public_channel1 = OpenStruct.new(name: 'channel3', id: '3', private: false, mapped:true)
    private_channel1 = OpenStruct.new(name: 'channel2', id: '2', private: true, mapped:true)
    public_channel2 = OpenStruct.new(name: 'channel1', id: '1', private: false, mapped:false)
    private_channel2 = OpenStruct.new(name: 'channel4', id: '4', private: true, mapped:false)
    channels = [public_channel1,
                private_channel1,
                public_channel2,
                private_channel2]

    expected_private_channels = [['channel4', '4']]
    expected_public_channels = [['channel1', '1']]

    formatted_channels = Hash[formatted_channels(channels)]

    assert_equal(expected_public_channels, formatted_channels['Open channels'])
    assert_equal(expected_private_channels, formatted_channels['Private channels'])
  end

  def test_formatted_channels_should_not_return_private_channels_group_when_there_are_no_private_channels_integrated
    public_channel1 = OpenStruct.new(name: 'channel3', id: '3', private: false, mapped:true)
    public_channel2 = OpenStruct.new(name: 'channel1', id: '1', private: false, mapped:false)

    channels = [public_channel1,
                public_channel2]

    expected_public_channels = [['channel1', '1'], ['channel3', '3']]
    formatted_channels = Hash[formatted_channels(channels, false)]

    assert_nil(formatted_channels['Private channels'])
    assert_equal(expected_public_channels, formatted_channels['Open channels'])
  end

  def test_formatted_channels_should_not_return_public_channels_group_when_there_are_no_public_channels_integrated
    private_channel1 = OpenStruct.new(name: 'channel3', id: '3', private: true, mapped:true)
    private_channel2 = OpenStruct.new(name: 'channel1', id: '1', private: true, mapped:false)

    channels = [private_channel1,
                private_channel2]

    expected_private_channels = [['channel1', '1'], ['channel3', '3']]
    formatted_channels = Hash[formatted_channels(channels, false)]

    assert_nil(formatted_channels['Open channels'])
    assert_equal(expected_private_channels, formatted_channels['Private channels'])
  end

  def test_selected_slack_channel_for_project_should_return_slack_channel_of_mapped_channel_for_project
    team_id = first_project.team.id
    channels = [OpenStruct.new(id: 1, mapped: false, isPrimary: false),
                OpenStruct.new(id: 2, mapped: true, teamId: team_id, isPrimary: true),
                OpenStruct.new(id: 3, mapped: true, teamId: 2, isPrimary: true),
                OpenStruct.new(id: 4, mapped: false, isPrimary: false)]

    selected_slack_channel_id = selected_slack_channel_for_project(channels, first_project).id

    assert_equal(2, selected_slack_channel_id)
  end

  def test_selected_slack_channels_for_project_should_return_the_elements_with_mapped_channels_info
    team_id = first_project.team.id
    channels = [OpenStruct.new(id: 1, mapped: false),
                OpenStruct.new(id: 2, mapped: true, teamId: team_id, name: 'channel1'),
                OpenStruct.new(id: 3, mapped: true, teamId: 2),
                OpenStruct.new(id: 4, mapped: true, teamId: team_id, name: 'channel2'),
                OpenStruct.new(id: 3, mapped: false)]

    selected_slack_channel_id = selected_slack_channels_for_project(channels, first_project)

    assert_equal(selected_slack_channel_id, '<strong>&lt;channel1&gt;</strong><strong>&lt;channel2&gt;</strong>')
  end


  def test_partition_non_primary_channels_should_return_the_none_primary_channel_for_current_project
    team_id = first_project.team.id
    channels = [
        OpenStruct.new(id: 1, mapped: true, teamId: team_id, name: 'channel1', private: false, isPrimary: true),
        OpenStruct.new(id: 2, mapped: true, teamId: team_id, name: 'channel2' ,  private: true, isPrimary: false),
        OpenStruct.new(id: 3, mapped: false, name: 'channel3',  private: false),
        OpenStruct.new(id: 4, mapped: true, teamId: team_id.next, name: 'channel4',  private: false,  isPrimary: false),
        OpenStruct.new(id: 5, mapped: true,teamId: team_id.next,  name: 'channel5',  private: false,  isPrimary: true)
    ]

    expected_channels = [
        [OpenStruct.new(id: 2, mapped: true, teamId: team_id, name: 'channel2' ,  private: true, isPrimary: false)],
        [OpenStruct.new(id: 3, mapped: false, name: 'channel3',  private: false)]
    ]

    assert_equal(expected_channels, partition_non_primary_channels(channels, first_project))
  end

  def test_fetching_mapped_non_primary_channels
    team_id = first_project.team.id

    channels = [
        OpenStruct.new(id: 1, mapped: true, teamId: team_id, name: 'mappedPrimaryOpenChannel', private: false, isPrimary: true),
        OpenStruct.new(id: 2, mapped: true, teamId: team_id, name: 'mappedPrivateChannel' ,  private: true, isPrimary: false),
        OpenStruct.new(id: 3, mapped: false, name: 'unmappedOpenChannel',  private: false),
        OpenStruct.new(id: 4, mapped: true, teamId: team_id, name: 'mappedOpenChannel',  private: false,  isPrimary: false),
        OpenStruct.new(id: 5, mapped: false, teamId: team_id.next,  name: 'unmappedPrivateChannel',  private: true,  isPrimary: false)
    ]

    expected_channels = [
        OpenStruct.new(id: 2, mapped: true, teamId: team_id, name: 'mappedPrivateChannel' ,  private: true, isPrimary: false),
        OpenStruct.new(id: 4, mapped: true, teamId: team_id, name: 'mappedOpenChannel',  private: false,  isPrimary: false),
    ]


    assert_equal(expected_channels, mapped_non_primary_channels(channels, first_project))
  end

  def test_inject_private_channel_if_needed_should_inject_private_channel
    team_id = first_project.team.id
    selected_slack_channel_id = 432

    channels = [

        OpenStruct.new(id: 1, mapped: true, teamId: team_id, name: 'mappedPrivateChannel', private: true),
        OpenStruct.new(id: 2, mapped: true, teamId: team_id, name: 'mappedOpenChannel' ,  private: false),
    ]
    expected_channels = [
        OpenStruct.new(id: 1, mapped: true, teamId: team_id, name: 'mappedPrivateChannel' ,  private: true),
        OpenStruct.new(id: 2, mapped: true, teamId: team_id, name: 'mappedOpenChannel',  private: false),
        OpenStruct.new(id: selected_slack_channel_id, mapped: true, teamId: team_id, name: 'private channel',  private: true)
    ]

    assert_equal(expected_channels, inject_private_channel_if_needed(channels, selected_slack_channel_id, first_project))
  end

  def test_inject_private_channel_if_needed_should_not_inject_private_channel_if_it_already_exist
    team_id = first_project.team.id
    selected_slack_channel_id = 432

    channels = [

        OpenStruct.new(id: 1, mapped: true, teamId: team_id, name: 'mappedPrivateChannel', private: true),
        OpenStruct.new(id: 2, mapped: true, teamId: team_id, name: 'mappedOpenChannel' ,  private: false),
        OpenStruct.new(id: selected_slack_channel_id, mapped: true, teamId: team_id, name: 'mappedPrivateChannel2', private: true),
    ]
    expected_channels = OpenStruct.new(id: selected_slack_channel_id, mapped: true, teamId: team_id, name: 'private channel',  private: true)

    assert_false inject_private_channel_if_needed(channels, selected_slack_channel_id, first_project).include?(expected_channels)
  end

  def test_inject_private_channel_if_needed_should_not_inject_private_channel_if_selected_channel_is_nil
    team_id = first_project.team.id

    channels = [

        OpenStruct.new(id: 1, mapped: true, teamId: team_id, name: 'mappedPrivateChannel', private: true),
        OpenStruct.new(id: 2, mapped: true, teamId: team_id, name: 'mappedOpenChannel' ,  private: false),
    ]

    actual = inject_private_channel_if_needed(channels, nil, first_project)
    assert_equal channels, actual
    assert_equal 2, actual.size
  end

  def test_disable_drop_channel_down_should_return_true_when_selected_channel_id_does_not_exist_in_mapped_channel
    team_id = first_project.team.id
    selected_slack_channel_id = 432

    channels = [
        OpenStruct.new(id: 1, mapped: true, teamId: team_id, name: 'mappedPrivateChannel', private: true),
        OpenStruct.new(id: 2, mapped: true, teamId: team_id, name: 'mappedOpenChannel' ,  private: false),
    ]

    assert disable_drop_channel_down?(channels, selected_slack_channel_id)
  end

  def test_disable_drop_channel_down_should_return_false_when_selected_channel_id_exist_in_mapped_channel
    team_id = first_project.team.id
    selected_slack_channel_id = 2

    channels = [
        OpenStruct.new(id: 1, mapped: true, teamId: team_id, name: 'mappedPrivateChannel', private: true),
        OpenStruct.new(id: 2, mapped: true, teamId: team_id, name: 'mappedOpenChannel' ,  private: false),
    ]

    assert_false disable_drop_channel_down?(channels, selected_slack_channel_id)
  end

  def test_disable_drop_channel_down_should_return_false_when_selected_channel_id_is_nil
    team_id = first_project.team.id
    selected_slack_channel_id = nil

    channels = [
        OpenStruct.new(id: 1, mapped: true, teamId: team_id, name: 'mappedPrivateChannel', private: true),
        OpenStruct.new(id: 2, mapped: true, teamId: team_id, name: 'mappedOpenChannel' ,  private: false),
    ]

    assert_false disable_drop_channel_down?(channels, selected_slack_channel_id)
  end

  def test_selected_slack_channel_for_project_should_return_nil_when_no_channel_is_mapped
    channels = [OpenStruct.new(id: 1, mapped: false),
                OpenStruct.new(id: 4, mapped: false)]

    selected_slack_channel = selected_slack_channel_for_project(channels, first_project)

    assert_nil(selected_slack_channel)
  end

  def test_selected_slack_channel_for_project_should_return_nil_when_channels_are_mapped_for_other_teams
    channels = [OpenStruct.new(id: 1, mapped: true, teamId: first_project.team.id+1),
                OpenStruct.new(id: 4, mapped: false)]

    selected_slack_channel= selected_slack_channel_for_project(channels, first_project)

    assert_nil(selected_slack_channel)
  end

  def test_read_only_mode_should_return_true_when_project_is_mapped
    assert read_only_mode?(true, nil)
  end

  def test_should_not_display_private_channel_authorization_if_project_mapped_and_in_users_channels_list
    assert_false requires_private_channel_authorization?(true, OpenStruct.new(id: 1, mapped: true, teamId: 1), {})
  end

  def test_should_display_private_channel_authorization_if_user_not_authorized_yet
    assert requires_private_channel_authorization?(true, nil, {:authenticated => false, :error => {:missingScope => 'groups:read'}})
  end

  def test_should_display_private_channel_authorization_if_user_not_authorized_yet
    assert need_authorization_to_see_private_channel?(:authenticated => false, :error => {:missingScope => 'groups:read'})
  end

  def test_read_only_mode_should_return_true_when_selected_slack_channel_is_set
    assert read_only_mode?(false, 1)
  end

  def test_basic_identity_mapped_should_return_true_if_basic_identity_scope_not_missing
    assert basic_identity_mapped?({:authenticated => false, :error => {:missingScope => 'groups:read'}})
  end

  def test_basic_identity_mapped_should_return_false_if_basic_identity_scope_missing
    assert_false basic_identity_mapped?({:authenticated => false, :error => {:missingScope => 'groups:read,identity.basic'}})
  end

  def test_basic_identity_mapped_should_return_true_if_authenticated
    assert basic_identity_mapped?({:authenticated => true})
  end

  def test_basic_identity_mapped_should_return_false_if_not_authenticated
    assert_false basic_identity_mapped?({:authenticated => false})
  end

  def test_read_only_mode_should_return_true_when_user_is_not_authorized
    first_project.activate
    login_as_member
    assert read_only_mode?(nil,nil)
  end

  def test_slack_error_message_for_code_should_return_custom_message_when_tenant_does_not_exist
    assert_equal 'This Mingle instance is not integrated with any Slack team', slack_error_message_for_code('tenant_does_not_exist')
  end

  def test_slack_error_message_for_code_should_return_humanized_error_code_for_others
    assert_equal 'Error code', slack_error_message_for_code('error_code')
  end

  def test_get_integration_link_should_return_slack_setup_link_if_tenant_not_integrated
    tenant_name = 'valid-tenant-name'

    MingleConfiguration.overridden_to(
        :app_namespace => tenant_name,
        :slack_client_id => 'some_client_id',
        :slack_encryption_key => 'kkCSxzaucrCTn0GK/MEH7Q==') do

      login_as_proj_admin
      stub_integration_status_request(tenant_name, @scope, {'status' => 'NOT_INTEGRATED'})

      with_fake_aws_env_for_slack_client do
        assert_equal build_help_link('setup_slack.html'), integration_help_link
      end
    end
  end

  def test_get_integration_link_should_return_authenticate_in_slack_link_if_user_not_integrated
    user_info = {'name' => 'slack_user_name'}
    tenant_name = 'valid-tenant-name'

    MingleConfiguration.overridden_to(
        :app_namespace => tenant_name,
        :slack_client_id => 'some_client_id',
        :slack_encryption_key => 'kkCSxzaucrCTn0GK/MEH7Q==') do

      login_as_proj_admin
      stub_integration_status_request(tenant_name, @scope, {'status' => 'INTEGRATED'})

      stub_user_integration_status_request(tenant_name, User.current.id, @user_integration_scope , {'authenticated' => false, 'user' => user_info})

      with_fake_aws_env_for_slack_client do
        assert_equal authenticate_in_slack_link, integration_help_link
      end
    end
  end

  def test_get_integration_link_should_return_slack_features_link_if_tenant_and_user_are_integrated
    user_info = {'name' => 'slack_user_name'}
    tenant_name = 'valid-tenant-name'

    MingleConfiguration.overridden_to(
        :app_namespace => tenant_name,
        :slack_client_id => 'some_client_id',
        :slack_encryption_key => 'kkCSxzaucrCTn0GK/MEH7Q==') do

      login_as_proj_admin
      stub_integration_status_request(tenant_name, @scope, {'status' => 'INTEGRATED'})

      stub_user_integration_status_request(tenant_name, User.current.id, @user_integration_scope , {'authenticated' => true, 'user' => user_info})

      with_fake_aws_env_for_slack_client do
        assert_equal build_help_link("features_slack.html"), integration_help_link
      end
    end
  end

end
