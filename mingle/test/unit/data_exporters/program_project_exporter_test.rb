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

class ProgramProjectExporterTest < ActiveSupport::TestCase

  def test_should_export_to_sheet_and_name
    login_as_admin

    program = create_program

    assert ProgramProjectExporter.new('', {program_id: program.id}).exports_to_sheet?
    assert_equal 'Projects', ProgramProjectExporter.new('', {program_id: program.id}).name
  end

  def test_sheet_should_contain_correct_page_data
    login_as_admin
    program = create_program
    with_first_project do |project|

      program.projects << project
      property_to_map = project.find_property_definition("status")
      enumeration_value_to_map = property_to_map.enumeration_values.detect {|ev| ev.value == 'closed'}
      program_project = program.program_projects.first
      program_project.update_attributes(:status_property => property_to_map, :done_status => enumeration_value_to_map)
      program_project.reload

      program_project_data_exporter = ProgramProjectExporter.new('', {program_id: program.id})
      sheet = ExcelBook.new('test').create_sheet(program_project_data_exporter.name)
      program_project_data_exporter.export(sheet)

      assert_equal 5, sheet.headings.count
      assert_equal program.program_projects.all.count + 1, sheet.number_of_rows
      assert_equal ['Project identifier', 'Project name', 'Done status: Property', 'Done status: Value', 'Accepts dependencies'], sheet.headings
      assert_equal [project.identifier, project.name, property_to_map.name, enumeration_value_to_map.value, 'Yes'], sheet.row(1)
    end
  end

  def test_sheet_should_contain_NA_for_done_status_property_and_value_when_not_configured

    login_as_admin
    program = create_program
    with_first_project do |project|

      program.projects << project

      program_project_data_exporter = ProgramProjectExporter.new('', {program_id: program.id})
      sheet = ExcelBook.new('test').create_sheet(program_project_data_exporter.name)
      program_project_data_exporter.export(sheet)

      assert_equal 5, sheet.headings.count
      assert_equal program.program_projects.all.count + 1, sheet.number_of_rows
      assert_equal ['Project identifier', 'Project name', 'Done status: Property', 'Done status: Value', 'Accepts dependencies'], sheet.headings
      assert_equal [project.identifier, project.name, 'NA', 'NA', 'Yes'], sheet.row(1)

    end
  end

  def test_should_be_exportable_when_program_have_projects
    login_as_admin
    program = create_program
    with_first_project do |project|
      program.projects << project
      program_project_data_exporter = ProgramProjectExporter.new('', {program_id: program.id})

      assert program_project_data_exporter.exportable?
    end
  end

  def test_should_be_exportable_when_program_does_not_have_projects
    login_as_admin
    program = create_program
    program_project_data_exporter = ProgramProjectExporter.new('', {program_id: program.id})

    assert_false program_project_data_exporter.exportable?
  end
end
