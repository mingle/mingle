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

class ProjectSlackIntegrationsExporterTest < ActiveSupport::TestCase

  def test_should_export_to_sheet_and_name
    project_slack_integrations_exporter = ProjectSlackIntegrationsExporter.new('')
    assert project_slack_integrations_exporter.exports_to_sheet?
    assert_equal 'Slack integration', project_slack_integrations_exporter.name
  end

  def test_sheet_should_contain_correct_slack_integrations_data
    with_new_project do |project|
      team_id = project.team.id
      channels = [
          {id: 1, mapped: true, teamId: team_id, name: 'channel1', private: false, isPrimary: true},
          {id: 2, mapped: true, teamId: team_id, name: 'channel2' , private: true, isPrimary: false},
          {id: 3, mapped: true, teamId: team_id, name: 'channel3',  private: false,  isPrimary: false},
          {id: 4, mapped: true,teamId: team_id,  name: 'channel4',  private: false,  isPrimary: false}
      ]
      SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'INTEGRATED', team: {name: 'A Team', url: 'http://slack.team.url'}})
      SlackApplicationClient.any_instance.stubs(:list_all_channels => {:channels => channels})

      project_slack_integrations_exporter = ProjectSlackIntegrationsExporter.new('', {})
      sheet = ExcelBook.new('test').create_sheet(project_slack_integrations_exporter.name)
      project_slack_integrations_exporter.export(sheet)

      assert_equal 3, sheet.headings.count
      assert_equal channels.size + 1, sheet.number_of_rows
      assert_equal ['Channel', 'Primary', 'Private'], sheet.headings
      assert_equal %w(channel1 Yes No), sheet.row(1)
      assert_equal %w(channel2 No Yes), sheet.row(2)
      assert_equal %w(channel3 No No), sheet.row(3)
      assert_equal %w(channel4 No No), sheet.row(4)
    end
  end

  def test_should_not_be_exportable_when_tenant_is_not_integrated
    with_new_project do
      SlackApplicationClient.any_instance.stubs(:mapped_projects => {:ok => false})
      project_slack_integrations_exporter = ProjectSlackIntegrationsExporter.new('', {})

      assert_false project_slack_integrations_exporter.exportable?
    end
  end

  def test_should_not_be_exportable_when_project_is_not_mapped
    with_new_project do
      SlackApplicationClient.any_instance.stubs(:mapped_projects => {:ok => true, :mappings => [{:mingleTeamId => 23}, {:mingleTeamId => 43}]})
      project_slack_integrations_exporter = ProjectSlackIntegrationsExporter.new('', {})

      assert_false project_slack_integrations_exporter.exportable?
    end
  end

  def test_should_be_exportable_when_project_is_mapped
    with_new_project do |project|
      SlackApplicationClient.any_instance.stubs(:mapped_projects => {:ok => true, :mappings => [{:mingleTeamId => project.team.id}, {:mingleTeamId => 43}]})
      project_slack_integrations_exporter = ProjectSlackIntegrationsExporter.new('', {})

      assert project_slack_integrations_exporter.exportable?
    end
  end
end
