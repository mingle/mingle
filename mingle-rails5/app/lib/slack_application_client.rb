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

class SlackApplicationClient
  include RetryOnNetworkError

  SLACK_APP_AWS_SERVICE_NAME = 'execute-api'
  SLACK_APP_AWS_REGION = MingleConfiguration.slack_app_aws_region || 'us-west-1'
  OK = '200'

  def initialize(aws_credentials)
    @signer = Aws::RequestSigner.new(aws_credentials, SLACK_APP_AWS_SERVICE_NAME, SLACK_APP_AWS_REGION)
    @base_url = URI.parse(MingleConfiguration.slack_app_url || '')
    @client = Net::HTTP.new(@base_url.host, @base_url.port)
    @client.use_ssl = @base_url.scheme == 'https'
  end

  def integration_status(tenant_name, scope)
    params = {tenantName: tenant_name, scope: scope}
    request = signed_get_request('integrationStatus', params)
    execute(request, params).body
  end

  def user_integration_status(tenant_name, user_id, scope)
    params = {tenantName: tenant_name, mingleUserId: user_id, scope: scope}
    request = signed_get_request('userIntegrationStatus', params)
    execute(request, params).body
  end

  def remove_integration(tenant_name, integration_type, params={})
    request_body = {
      tenantName: tenant_name,
      integrationType: integration_type,
      mingleTeamId: params[:team_id], mingleProjectName: params[:project_name],
      mingleUserId: params[:user_id], mingleUserName: params[:user_name]}
    request = signed_delete_request('removeIntegration', request_body)
    execute(request, request_body).body
  end

  def remove_tenant_integration(tenant_name, params={})
    request_body = {tenantName: tenant_name, users: params[:users], projects: params[:projects]}
    request = signed_delete_request('removeTenantIntegration', request_body)
    execute(request, request_body).body
  end

  def list_channels(tenant_name, mingle_team_id, mingle_user_id)
    params = {tenantName: tenant_name, mingleUserId: mingle_user_id, mingleTeamId: mingle_team_id}
    request = signed_get_request('listChannels', params)
    execute(request, params).body
  end

  def map_channel(tenant_name, project_name, team_id, mingle_user_id, channel_id, is_private)
    body = { tenantName: tenant_name, mingleProjectName: project_name, mingleTeamId: team_id,
             mingleUserId: mingle_user_id, channelId: channel_id, privateChannel: is_private,
             eulaAcceptedBy: User.current.login, eulaAcceptedAt: Time.now.utc.milliseconds.to_i }
    request = signed_post_request('mapChannel', body)
    execute(request,body).body
  end

  def map_transition(tenant_name, team_id, channel_id, transition_id, transition_name)
    body = { tenantName: tenant_name, mingleTeamId: team_id,
             channelId: channel_id, transitionId: transition_id, transitionName: transition_name }
    request = signed_post_request('mapTransition', body)
    execute(request,body).body
  end

  def mapped_projects(tenant_name = MingleConfiguration.app_namespace)
    params = {tenantName: tenant_name}
    request = signed_get_request('mappedProjects', params)
    execute(request, params).body
  end

  def update_channel_mappings(tenant_name, project_name, team_id, mingle_user_id, channels_to_update)
    body = { tenantName: tenant_name, projectName: project_name, mingleTeamId: team_id,
             mingleUserId: mingle_user_id, channelsToUpdate: channels_to_update }
    request = signed_post_request('updateChannelMappings', body)
    execute(request, body).body
  end

  private

  def signed_delete_request(path, body)
    request_url = URI.parse("#{base_url}/#{path}")
    request = Net::HTTP::Delete.new(request_url)
    request.content_type = 'application/json'
    request.body = body.to_json
    @signer.sign(request)
  end

  def signed_get_request(path, query_params)
    request_url = URI.parse("#{base_url}/#{path}")
    request_url.query = query_params.to_query
    request = Net::HTTP::Get.new(request_url)
    @signer.sign(request)
  end

  def signed_post_request(path, body)
    request_url = URI.parse("#{base_url}/#{path}")
    request = Net::HTTP::Post.new(request_url)
    request.content_type = 'application/json'
    request.body = body.is_a?(Hash) ? body.to_json : body.to_s
    @signer.sign(request)
  end

  def execute(request, data, format=:json)
    with_retry do |retries, exception|
      log_failed_try_on_exception(request.path, data, request.method, retries, exception)
      response = @client.request(request)
      response.body = JSON.parse(response.body).with_indifferent_access if format == :json && response.body && !response.body.trim.empty? && response.body != 'null'
      response
    end
  end

  def base_url
    @base_url.to_s
  end
end
