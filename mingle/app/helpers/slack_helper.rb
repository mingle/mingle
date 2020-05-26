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

module SlackHelper
  include UserAccess
  include IntegrationsHelper
  include HelpDocHelper


  PRIVATE_CHANNEL = 'private channel'
  def formatted_channels(channels, reject_mapped = true)
    private_channels, public_channels = partition_private_channels(channels, reject_mapped)
    formatted_channels = []

    formatted_channels.push(select_option_group_from_channels('Private channels', private_channels)) if private_channels && private_channels.any?
    formatted_channels.push(select_option_group_from_channels('Open channels', public_channels)) if public_channels && public_channels.any?
    formatted_channels
  end


  def inject_private_channel_if_needed(mapped_channels, selected_channel_id, project)
    return mapped_channels if selected_channel_id.nil? || has_access_to_selected_channel?(mapped_channels, selected_channel_id)
    mapped_channels.dup << OpenStruct.new(:id => selected_channel_id, :mapped => true, :teamId => project.team.id, :name => PRIVATE_CHANNEL, :private => true, )
  end


  def disable_drop_channel_down?(mapped_channels, selected_channel_id)
    return false if selected_channel_id.nil?
    ! mapped_channels.any? { |ch| ch.id.eql? selected_channel_id }
  end

  def partition_private_channels(channels, reject_mapped)
    channels = channels.reject{|c| c.mapped == 'true' || c.mapped } if reject_mapped
    channels.partition(&:private)
  end

  def partition_non_primary_channels(channels, project)
    channels = channels.reject{|c| ( c.mapped && c.isPrimary || c.mapped && c.teamId != project.team.id)}
    channels.partition(&:private)
  end

  def mapped_non_primary_channels(channels, project)
    channels.select{|c| ( !c.isPrimary && c.mapped && c.teamId == project.team.id)}
  end

  def select_option_group_from_channels(title, channels)
    [title, channels.sort_by(&:name).collect { |ch| [ch.name, ch.id] }]
  end

  def selected_slack_channel_for_project(channels, project)
    team_id = project.team.id
    return channels.find { |ch| ch.mapped && ch.teamId == team_id && ch.isPrimary}
  end

  def selected_slack_channels_for_project(channels, project)
    team_id = project.team.id
    html = ''.html_safe
    channels.each do |ch|
      if ch.mapped && ch.teamId == team_id
        html <<  '<strong>'.html_safe
        html << "<#{ch.name}>"
        html <<  '</strong>'.html_safe
      end
    end
    html
  end

  def requires_private_channel_authorization?(team_mapped, selected_slack_channel, user_integration)
    already_mapped = (team_mapped && !selected_slack_channel.nil?)
    groups_scope_missing = need_authorization_to_see_private_channel?(user_integration)
    !already_mapped && groups_scope_missing
  end

  def need_authorization_to_see_private_channel?(user_integration)
    !user_integration[:authenticated] || scope_missing?(user_integration[:error], "groups:read")
  end

  def basic_identity_mapped?(user_integration)
    return true if user_integration[:authenticated]
    return false unless user_integration[:error] && user_integration[:error][:missingScope]
    !scope_missing?(user_integration[:error], IntegrationsHelper::USER_INTEGRATION_SCOPE)
  end

  def read_only_mode?(project_mapped, selected_slack_channel)
    !has_access_to_select_channel? || project_mapped || selected_slack_channel
  end

  def has_access_to_select_channel?
    authorized?(:controller => 'slack', :action => :save_channel )
  end

  def add_to_slack_terms
    %Q{You are about to enable the Slack Integration with Mingle for your Mingle instance. This will enable Mingle users in your Mingle instance to share
    information from your Mingle instance to Slack, and will allow users of Slack to input information into your Mingle instance. You and your Mingle
    users are solely responsible for ensuring that information you or your users share between Mingle and Slack is shared in compliance with your
    organization's policies on monitoring and protecting the confidentiality of such information.}
  end

  def channel_mapping_terms
    %Q{You are about to enable the Slack Integration with Mingle for your Mingle project. This will enable Mingle users in your Mingle project to share
    information from your Mingle project to Slack, and will allow users of Slack to input information into your Mingle project. You and your Mingle users
    are solely responsible for ensuring that information you or your users share between Mingle and Slack is shared in compliance with your organization's
    policies on monitoring and protecting the confidentiality of such information.}
  end

  def slack_user_auth_terms
    'You are now linking your Mingle account to your Slack account. This lets you to share information from Mingle to Slack, and to send information from
    Slack to Mingle. When you share information from Mingle to a Slack channel or use Slack to send information to Mingle, you are sharing the information with
    everyone who has access to that Slack channel. It is your responsibility to appropriately protect the confidentiality of the information you share between
    Mingle and Slack.'
  end

  def integration_help_link
    if slack_tenant_integration_info[:status] != IntegrationStatus::INTEGRATED
     link_to_help('/setup_slack.html')
    elsif !slack_user_authorization_info[:authenticated]
      authenticate_in_slack_link
    else
     link_to_help('/features_slack.html')
    end
  end

  def authenticate_in_slack_link
    {controller: :profile, action: :show, id: User.current.id, tab: 'slack'}
  end

  def slack_error_message_for_code(slack_error_code)
    {
        'tenant_does_not_exist' => 'This Mingle instance is not integrated with any Slack team'
    }[slack_error_code] || slack_error_code.humanize
  end
  private
  def scope_missing?(user_integration_error, scope)
    user_integration_error && user_integration_error[:missingScope] && user_integration_error[:missingScope] =~ /#{scope}/
  end

  def has_access_to_selected_channel?(mapped_channels, selected_channel_id)
    mapped_channels.any? { |ch| ch.id.eql? selected_channel_id }
  end

end
