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

class SlackController < ProjectApplicationController

  include ActionView::Helpers::JavaScriptHelper
  include SlackHelper
  helper :integrations

  allow :delete_access_for => [:remove_slack_integration],
        :get_access_for => [:index]
  privileges UserAccess::PrivilegeLevel::PROJECT_ADMIN => [:index, :save_channel, :update_channel_mappings, :remove_slack_integration]
  privileges UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER => [:index]

  def index
    scope = 'identify,commands,chat:write:bot,channels:read,users:read'

    integration_status = slack_app_client.integration_status(MingleConfiguration.app_namespace, scope)
    @slack_integrated = (integration_status[:status] == IntegrationsHelper::IntegrationStatus::INTEGRATED)
    if @slack_integrated
      fetch_slack_channels
      flash.now[:error] = params[:slack_error] if params[:slack_error]
      @selected_slack_channel = selected_slack_channel_for_project(@slack_channels, Project.current)
      flash.now[:notice] = "The linking of this project with ##{@selected_slack_channel.name} was successful!" if flash[:success]
      flash.now[:notice] = "You have successfully signed in as #{params[:slack_user_name]}" if params[:slack_user_name] && IntegrationsHelper.slack_user_authorization_info[:authenticated]
      @team_info = integration_status[:team]
      @user_integration = slack_app_client.user_integration_status(MingleConfiguration.app_namespace, User.current.id, IntegrationsHelper::USER_INTEGRATION_SCOPE + ',groups:read')
    end
  end

  def save_channel
    if params[:eula_acceptance] == 'slack_eula_accepted'
      team_id = Project.current.team.id
      response = slack_app_client.map_channel(MingleConfiguration.app_namespace, Project.current.name, team_id, User.current.id,
                                              params[:selected_slack_channel_id], params[:is_private])
      if response[:success]
        add_monitoring_event('slack_channel_mapped', {'project_name' => Project.current.name})
        @selected_slack_channel_id = params[:selected_slack_channel_id]
        flash[:success] = true
      elsif
        flash[:error] = slack_error_message_for_code(response[:error])
      end
    else
      flash[:error] = 'Please accept the terms and conditions!'
    end

    redirect_to :action => :index
  end

  def update_channel_mappings
    channels_to_update = params[:channelsToUpdate]
    unless channels_to_update
      render :nothing => true, :status => 400
    else
      project = Project.current
      update_mapping_response = slack_app_client.update_channel_mappings(MingleConfiguration.app_namespace, project.name, project.team.id, User.current.id, channels_to_update)
      if update_mapping_response[:ok]
        failed_mappings = []
        update_mapping_response[:updatedChannels].each  do |channel|
            failed_mappings << channel[:name] unless channel[:error].blank?
            add_monitoring_event('channel_mapped', {'project_name' => project.name}) if channel[:error].blank? & channel[:mapped]
        end
        response = {}
        unless failed_mappings.empty?
          response[:error] = "Mapping could not be updated for the following Slack channel#{failed_mappings.size > 1 ? 's' : ''}: #{failed_mappings.join(', ')}. Please try again in sometime."
        end
        response[:updatedChannels] = update_mapping_response[:updatedChannels]
        render :json => response.to_json , :status => :ok
      else
        render :json => {:error => update_mapping_response[:error]}.to_json, :status => :ok
      end
    end
  end

  def remove_slack_integration
    SlackApplicationClient.new(Aws::Credentials.new).remove_integration(MingleConfiguration.app_namespace, 'Channel', {:team_id => Project.current.team.id, :project_name => Project.current.name})
    flash.now[:notice] = "Project has been delinked from Slack. If you have any questions or concerns please write to <a href='mailto:support@thoughtworks.com'>support@thoughtworks.com</a>."
    redirect_to :action => 'index'
  end

  private

  def fetch_slack_channels
    list_channels_response = slack_app_client.list_channels(MingleConfiguration.app_namespace, Project.current.team.id, User.current.id)
    @slack_channels = (list_channels_response[:channels].map { |ch| OpenStruct.new(ch) } || []).sort_by(&:name)
    @team_mapped = list_channels_response[:teamMapped]
  end

  def slack_app_client
    SlackApplicationClient.new(Aws::Credentials.new)
  end
end
