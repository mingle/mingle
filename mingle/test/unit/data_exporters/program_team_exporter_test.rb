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

class ProgramTeamExporterTest < ActiveSupport::TestCase

  def setup
    login_as_admin
    @program = create_program
  end

  def test_should_export_to_sheet_and_name
    assert ProgramTeamExporter.new('', {program_id: @program.id}).exports_to_sheet?
    assert_equal 'Team', ProgramTeamExporter.new('', {program_id: @program.id}).name
  end

  def test_sheet_should_contain_correct_page_data
    member = User.find_by_login('member')
    admin = User.find_by_login('admin')
    @program.add_member(member)

    program_team_exporter = ProgramTeamExporter.new('', {program_id: @program.id})
    sheet = ExcelBook.new('test').create_sheet(program_team_exporter.name)
    program_team_exporter.export(sheet)

    assert_equal 3, sheet.headings.count
    assert_equal @program.users.all.count + 1, sheet.number_of_rows
    assert_equal ['Name', 'Sign-in name', 'Email'], sheet.headings
    assert_equal [admin.name, admin.login, admin.email], sheet.row(1)
    assert_equal [member.name, member.login, member.email], sheet.row(2)
  end

  def test_should_be_exportable_when_program_have_team_members
    login_as_admin
    program = create_program
    program.add_member(create_user!)
    program_team_exporter = ProgramTeamExporter.new('', {program_id: program.id})
    assert program_team_exporter.exportable?
  end

  def test_should_not_be_exportable_when_program_does_not_have_team_members
    login_as_admin
    program = create_program
    program.users.each { |user| program.remove_member(user) }
    program_team_exporter = ProgramTeamExporter.new('', {program_id: program.id})
    assert_false program_team_exporter.exportable?
  end
end
