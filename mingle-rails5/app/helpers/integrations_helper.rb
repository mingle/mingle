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

java_import org.apache.commons.codec.binary.Hex
module IntegrationsHelper
  APP_INTEGRATION_SCOPE = 'identify,commands,chat:write:bot,channels:read,users:read'
  USER_INTEGRATION_SCOPE = 'identity.basic'

  module IntegrationStatus
    INTEGRATED = 'INTEGRATED'
    NOT_INTEGRATED = 'NOT_INTEGRATED'
    REVOKE_IN_PROGRESS = 'REVOKE_IN_PROGRESS'
    SCOPE_MISMATCH = 'SCOPE_MISMATCH'
  end

  def encrypt_data_for_slack(plain_text)
    encrypted_java_bytes = MingleCipher.new(Base64.decode64(MingleConfiguration.slack_encryption_key)).encrypt(plain_text)
    Hex.encodeHexString(encrypted_java_bytes)
  end

  def decrypt_data_from_slack(encrypted_text)
    encrypted_java_hex_string =  encrypted_text.to_java_string
    encrypted_java_bytes = Hex.decodeHex(encrypted_java_hex_string.toCharArray)
    MingleCipher.new(Base64.decode64(MingleConfiguration.slack_encryption_key)).decrypt(encrypted_java_bytes)
  end

  def slack_redirect_uri(action)
    "#{MingleConfiguration.slack_app_url}/" + action
  end

  def slack_user_sign_in_link(mingle_redirect_uri)
    slack_user_add_scope_link USER_INTEGRATION_SCOPE, mingle_redirect_uri
  end

  def slack_user_groups_authorization_link(mingle_redirect_uri)
    slack_user_add_scope_link 'groups:read,chat:write:bot', mingle_redirect_uri
  end

  def slack_user_add_scope_link(scope, mingle_redirect_uri)
    plain_text = { userLogin: User.current.login,
                   userId: User.current.id,
                   userName: User.current.name,
                   tenantName: MingleConfiguration.app_namespace,
                   mingleRedirectUri: mingle_redirect_uri,
                   eulaAcceptedAt: Time.now.utc.milliseconds.to_i
                  }.to_json

    slack_query_params = {'client_id' => MingleConfiguration.slack_client_id,
                          'scope' => scope,
                          'state' => encrypt_data_for_slack(plain_text),
                          'redirect_uri' => slack_redirect_uri('authorizeUser')}

    "https://slack.com/oauth/authorize?#{slack_query_params.to_query}"
  end

  def slack_user_authorization_info
    slack_client.user_integration_status(MingleConfiguration.app_namespace, User.current.id, USER_INTEGRATION_SCOPE)
  end

  def slack_tenant_integration_info
    slack_client.integration_status(MingleConfiguration.app_namespace, APP_INTEGRATION_SCOPE)
  end


  def slack_client
    SlackApplicationClient.new(AWS::Credentials.new)
  end

  def slack_team_info
    return nil unless (MingleConfiguration.app_namespace && MingleConfiguration.saas?)
    integration_status_data = slack_client.integration_status(MingleConfiguration.app_namespace, APP_INTEGRATION_SCOPE)
    integration_status_data[:status] == IntegrationStatus::INTEGRATED ? integration_status_data[:team] : nil
  end

  def projects_mapped_to_slack(projects)
    project_mappings = slack_client.mapped_projects[:mappings] || []
    mapped_teams = project_mappings.map {|mapping| mapping[:mingleTeamId]}
    projects.select { |project| mapped_teams.include?(project.team.id) }
  end

  module_function(:slack_team_info, :slack_user_authorization_info, :slack_user_sign_in_link, :slack_client, :decrypt_data_from_slack)
end
