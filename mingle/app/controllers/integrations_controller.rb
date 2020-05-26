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

class IntegrationsController < ApplicationController
  include IntegrationsHelper, RetryOnNetworkError, SlackHelper
  helper :slack

  allow :get_access_for => [:index, :slack_integration_help], :delete_access_for => [:remove_slack_integration, :remove_user_from_slack]
  privileges UserAccess::PrivilegeLevel::MINGLE_ADMIN => [:index, :add_slack_integration, :remove_slack_integration, :authorize_tenant]
  privileges UserAccess::PrivilegeLevel::REGISTERED_USER => [:add_user_to_slack, :remove_user_from_slack, :slack_integration_help]

  def index
    flash.now[:error] = params[:error]
    integration_info = slack_tenant_integration_info
    @slack_integrated = [IntegrationStatus::INTEGRATED, IntegrationStatus::REVOKE_IN_PROGRESS].include?(integration_info[:status])
    @revoke_in_progress = integration_info[:status] == IntegrationStatus::REVOKE_IN_PROGRESS
    html_flash.now[:notice] = slack_integration_revoke_in_progress_message if @revoke_in_progress
    @team_info = integration_info[:team]
  end

  def remove_slack_integration
    users = fetch_id_to_name_map_from_query("SELECT id, name FROM #{ActiveRecord::Base.connection.safe_table_name('users')}")
    projects = fetch_id_to_name_map_from_query("SELECT g.id, p.name FROM #{ActiveRecord::Base.connection.safe_table_name('deliverables')} p INNER JOIN #{ActiveRecord::Base.connection.safe_table_name('groups')} g ON lower(g.name)='team' AND g.deliverable_id = p.id AND p.type = 'Project'")
    SlackApplicationClient.new(Aws::Credentials.new).remove_tenant_integration(MingleConfiguration.app_namespace, {users: users, projects: projects})
    html_flash[:notice] = slack_integration_revoke_in_progress_message
    redirect_to :action => 'index'
  end

  def add_slack_integration
    if params[:eula_acceptance] == 'slack_eula_accepted'
      plain_text = "tenantState:#{MingleConfiguration.app_namespace};#{User.current.login};#{Time.now.utc.milliseconds.to_i}"
      slack_query_params = {'client_id' => MingleConfiguration.slack_client_id,
                            'scope' => APP_INTEGRATION_SCOPE,
                            'state' => encrypt_data_for_slack(plain_text),
                            'redirect_uri' => slack_redirect_uri('authorize')}.to_query

      redirect_to('https://slack.com/oauth/authorize?' + slack_query_params)
    else
      flash[:error] = 'Please accept the terms and conditions!'
      render :index
    end
  end

  def add_user_to_slack
    if params[:eula_acceptance] == 'slack_eula_accepted'
      redirect_to slack_user_sign_in_link("profile/show/#{User.current.id}")
    else
      flash[:error] = 'Please accept the terms and conditions!'
      redirect_to controller: :profile, action: :show, id: User.current.id, tab: 'Slack'
    end
  end

  def remove_user_from_slack
    SlackApplicationClient.new(Aws::Credentials.new).remove_integration(MingleConfiguration.app_namespace, 'User', {user_id: User.current.id, user_name: User.current.name})
    html_flash[:notice] = "Mingle user profile has been delinked from Slack. If you have any questions or concerns please write to <a href='mailto:support@thoughtworks.com'>support@thoughtworks.com</a>."
    redirect_to controller: :profile, action: :show, id: User.current.id, tab: 'Slack'
  end

  def slack_integration_help
    add_monitoring_event(:open_slack_integration_help_link)
    redirect_to integration_help_link
  end


  private
  def fetch_id_to_name_map_from_query(query)
    ActiveRecord::Base.connection.select_all(query).inject({}) { |result, item| result[item['id'].to_s] = item['name']; result }
  end

  def slack_integration_revoke_in_progress_message
    "Mingle is being delinked from Slack. If you have any questions or concerns please write to <a href='mailto:support@thoughtworks.com'>support@thoughtworks.com</a>."
  end
end
