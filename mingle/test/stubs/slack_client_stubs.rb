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

module SlackClientStubs
  def stub_integration_status_request(tenant_name, scope, body)
    stub_get_request("https://slackserver.com/integrationStatus?scope=#{scope}&tenantName=#{tenant_name}", body)
  end

  def stub_user_integration_status_request(tenant_name, mingle_user_id, scope, body)
    stub_get_request("https://slackserver.com/userIntegrationStatus?tenantName=#{tenant_name}&mingleUserId=#{mingle_user_id}&scope=#{scope}", body)
  end

  def stub_list_channels_request(tenant_name, mingle_team_id, mingle_user_id, body)
    stub_get_request("https://slackserver.com/listChannels?tenantName=#{tenant_name}&mingleUserId=#{mingle_user_id}&mingleTeamId=#{mingle_team_id}", body)
  end

  def stub_map_channel_request(tenant_name, project_name, team_id, mingle_user_id, channel_id, is_private, response_body )
    request_body  =  {tenantName: tenant_name, mingleProjectName: project_name, mingleTeamId: team_id, mingleUserId: mingle_user_id,
                      channelId: channel_id, privateChannel: is_private, eulaAcceptedBy: User.current.login, eulaAcceptedAt: Time.now.utc.milliseconds.to_i}
    stub_post_request('https://slackserver.com/mapChannel', request_body, response_body)
  end

  def stub_mapped_projects_request(tenant_name, response_body)
    stub_get_request("https://slackserver.com/mappedProjects?tenantName=#{tenant_name}", response_body)
  end

  def stub_update_channel_mappings_request(request_body, response_body)
    stub_post_request('https://slackserver.com/updateChannelMappings', request_body, response_body)
  end

  def stub_remove_integration_request(tenant_name, integration_type, params={})
    request_body = {
      tenantName: tenant_name,
      integrationType: integration_type,
      mingleTeamId: params[:team_id], mingleProjectName: params[:project_name],
      mingleUserId: params[:user_id], mingleUserName: params[:user_name]}
    stub_delete_request("https://slackserver.com/removeIntegration", request_body)
  end

  def stub_map_transition_request(tenant_name, params, response_body)
    request_body = {
        tenantName: tenant_name,
        mingleTeamId: params[:team_id],
        channelId: params[:slack_channel_id],
        transitionId: params[:transition_id],
        transitionName: params[:transition_name]
    }
    stub_post_request('https://slackserver.com/mapTransition', request_body, response_body)
  end

  def stub_remove_tenant_integration_request(tenant_name, params={})
    stub_delete_request("https://slackserver.com/removeTenantIntegration", {tenantName: tenant_name, users: params[:users], projects: params[:projects]})
  end

  def with_fake_aws_env_for_slack_client(&block)
    original_access_key = ENV['AWS_ACCESS_KEY_ID']
    original_secret_key = ENV['AWS_SECRET_ACCESS_KEY']
    ENV['AWS_ACCESS_KEY_ID'] = 'fake_access_key_id'
    ENV['AWS_SECRET_ACCESS_KEY'] = 'fake_secret_access_key'
    block.call
    ENV['AWS_ACCESS_KEY_ID'] = original_access_key
    ENV['AWS_SECRET_ACCESS_KEY'] = original_secret_key
  end

  private

  def stub_get_request(url, body)
    stub_request(:get, url)
        .with(:headers => {'Accept'=>'*/*',
                           'Authorization'=> /AWS4-HMAC-SHA256 Credential=fake_access_key_id\/#{Time.now.utc.strftime('%Y%m%d')}\/us-west-1\/execute-api\/aws4_request.*/,
                           'Host'=>'slackserver.com',
                           'User-Agent'=>'Ruby',
                           'X-Amz-Content-Sha256'=>/.*/,
                           'X-Amz-Date'=> Time.now.utc.strftime('%Y%m%dT%H%M%SZ') })
        .to_return(:status => 200, :body => body.to_json, :headers => {'Content-Type' => 'application/json'})
  end

  def stub_post_request(url,req_body,resp_body)
     stub_request(:post, url)
         .with(:body => req_body.to_json,
               :headers => {'Accept'=>'*/*',
                            'Authorization'=> /AWS4-HMAC-SHA256 Credential=fake_access_key_id\/#{Time.now.utc.strftime('%Y%m%d')}\/us-west-1\/execute-api\/aws4_request.*/,
                            'Host'=>'slackserver.com',
                            'User-Agent'=>'Ruby',
                            'X-Amz-Content-Sha256'=>/.*/,
                            'Content-Type' => 'application/json',
                            'X-Amz-Date'=> Time.now.utc.strftime('%Y%m%dT%H%M%SZ') })
         .to_return(:status => 200, :body => resp_body.to_json, :headers => {'Content-Type' => 'application/json'})
  end

  def stub_delete_request(url, body, resp_body = {})
     stub_request(:delete, url)
         .with(:body => body.to_json,
               :headers => {'Accept'=>'*/*',
                            'Authorization'=>/AWS4-HMAC-SHA256 Credential=fake_access_key_id\/#{Time.now.utc.strftime('%Y%m%d')}\/us-west-1\/execute-api\/aws4_request.*/,
                            'Host'=>'slackserver.com',
                            'User-Agent'=>'Ruby',
                            'X-Amz-Content-Sha256'=>/.*/,
                            'X-Amz-Date'=>Time.now.utc.strftime('%Y%m%dT%H%M%SZ')})
         .to_return(:status => 200, :body => resp_body.to_json, :headers => {})
  end
end
