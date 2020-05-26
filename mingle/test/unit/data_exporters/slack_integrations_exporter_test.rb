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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class SlackIntegrationsExporterTest < ActiveSupport::TestCase
  def test_should_export_to_sheet_and_name
    assert SlackIntegrationsExporter.new('', {}).exports_to_sheet?
    assert_equal 'Integrations', SlackIntegrationsExporter.new('', {}).name
  end

  def test_sheet_should_contain_slack_integrations_data
    login_as_admin

    slack_integrations_exporter = SlackIntegrationsExporter.new('', {team_url: 'test.slack.com'})
    sheet = ExcelBook.new('test').create_sheet(slack_integrations_exporter.name)
    slack_integrations_exporter.export(sheet)

    assert_equal 2, sheet.headings.count
    assert_equal %w(Integration Team), sheet.headings
    assert_equal %w(Slack test.slack.com), sheet.row(1)
    assert_equal 'test.slack.com', sheet.cell_link_address(1,1)
  end
end
