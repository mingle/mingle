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

class SlackIntegrationsExporter < BaseDataExporter
  def initialize(base_dir, message={})
    super(base_dir, message)
    @team_url = message[:team_url]
  end

  def name
    'Integrations'
  end

  def export(sheet)
    sheet.add_headings(sheet_headings)
      sheet.insert_row(1, ['Slack', @team_url], {link: {index: 1, url: @team_url}})
    Rails.logger.info("Exported integrations to sheet")
  end

  def exportable?
    true
  end

  private

  def headings
    %w(Integration Team)
  end
end
