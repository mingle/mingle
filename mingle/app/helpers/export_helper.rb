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

module ExportHelper
  def scope
    'identify,commands,chat:write:bot,channels:read,users:read'
  end

  def slack_app_client
    SlackApplicationClient.new(Aws::Credentials.new)
  end
  
  def slack_integration_data
    slack_app_client.integration_status(MingleConfiguration.app_namespace, scope)
  end
  
  def is_slack_integrated?
    slack_integration_data[:status] == IntegrationsHelper::IntegrationStatus::INTEGRATED
  end
  
  def slack_team_url
    slack_integration_data[:team][:url]
  end
end
