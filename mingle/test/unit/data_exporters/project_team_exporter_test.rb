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

class ProjectTeamExporterTest < ActiveSupport::TestCase

  def test_should_export_to_sheet_with_correct_name
    project_team_exporter = ProjectTeamExporter.new('')
    assert project_team_exporter.exports_to_sheet?
    assert_equal 'Team', project_team_exporter.name
  end

  def test_sheet_should_contain_team_data
    readonly_user = create_user!(name: 'readonly user')
    full_user = create_user!(name:'full user')
    admin_user = create_user!(name: 'admin user')
    with_new_project do |project|
      project.add_member(readonly_user, :readonly_member)
      project.add_member(full_user)
      project.add_member(admin_user, :project_admin)
      create_group('devs', [readonly_user, full_user])
      create_group('managers', [admin_user])
      create_group('qas', [readonly_user, admin_user])

      project_team_exporter = ProjectTeamExporter.new('')
      sheet = ExcelBook.new('test').create_sheet(project_team_exporter.name)
      project_team_exporter.export(sheet)

      assert_equal 5, sheet.headings.count
      assert_equal ['Name', 'Sign-in name', 'Email', 'Permissions', 'User groups'], sheet.headings

      assert_equal 4, sheet.number_of_rows
      assert_equal [admin_user.name, admin_user.login, admin_user.email, 'Project administrator', 'managers, qas'], sheet.row(1)
      assert_equal [full_user.name, full_user.login, full_user.email, 'Team member', 'devs'], sheet.row(2)
      assert_equal [readonly_user.name, readonly_user.login, readonly_user.email, 'Read only team member', 'devs, qas'], sheet.row(3)
    end

  end

  def test_should_be_exportable_when_project_have_members
    login_as_admin
    with_new_project do |project|
      project.add_member(create_user!)
      project_team_exporter = ProjectTeamExporter.new('')
      assert project_team_exporter.exportable?
    end
  end

  def test_should_not_be_exportable_when_project_does_not_have_members
    login_as_admin
    with_new_project do
      project_team_exporter = ProjectTeamExporter.new('')
      assert_false project_team_exporter.exportable?
    end
  end
end
