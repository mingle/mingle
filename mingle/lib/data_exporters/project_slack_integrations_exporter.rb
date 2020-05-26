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

class ProjectSlackIntegrationsExporter < BaseDataExporter
  include SlackHelper
  include ExportHelper

  def name
    'Slack integration'
  end

  def export(sheet)
    sheet.add_headings(sheet_headings)
    index = 1
    if is_slack_integrated?
      fetch_slack_channels
      primary_slack_channel = selected_slack_channel_for_project(@slack_channels, project)
      non_primary_channels = mapped_non_primary_channels(@slack_channels, project)
      if primary_slack_channel
        sheet.insert_row(index, [primary_slack_channel.name, 'Yes', private_channel(primary_slack_channel)])
        index = index.next
      end
      non_primary_channels.each do |channel|
        sheet.insert_row(index, [channel.name, 'No', private_channel(channel)])
        index = index.next
      end
    end
    Rails.logger.info("Exported slack integrations to sheet")
  end

  def exportable?
    response = slack_app_client.mapped_projects
    return false unless response && response[:ok]
    response[:mappings].any? do | mapping |
      mapping[:mingleTeamId] == project.team.id
    end
  end

  private
  def headings
    %w(Channel Primary Private)
  end

  def project
    Project.current
  end

  def fetch_slack_channels
    list_channels_response = slack_app_client.list_all_channels(MingleConfiguration.app_namespace, project.team.id)
    @slack_channels = (list_channels_response[:channels].map {|ch| OpenStruct.new(ch)} || []).sort_by(&:name)
  end

  def private_channel(channel)
    channel.private ? 'Yes' : 'No'
  end

end
