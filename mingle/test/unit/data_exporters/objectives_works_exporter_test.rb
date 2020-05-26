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

class ObjectivesWorksExporterTest < ActiveSupport::TestCase

  def test_should_export_to_sheet_and_name
    login_as_admin

    program = create_program

    assert ObjectivesWorksExporter.new('', {program_id: program.id}).exports_to_sheet?
    assert_equal 'Objectives Added Work', ObjectivesWorksExporter.new('', {program_id: program.id}).name
  end

  def test_sheet_should_contain_correct_data
    login_as_admin
    program = create_program
    plan = program.plan
    with_first_project do |project|

      program.projects << project
      property_to_map = project.find_property_definition("status")
      enumeration_value_to_map = property_to_map.enumeration_values.detect {|ev| ev.value == 'closed'}
      program_project = program.program_projects.first
      program_project.update_attributes(:status_property => property_to_map, :done_status => enumeration_value_to_map)
      program_project.reload

      objective = create_planned_objective program, :name => "objective new"
      plan.works.created_from(project).create!(:card_number => 1, :objective => objective, :name => project.cards.first.name)
      objective.filters.create!(:project => project, :params => {:filters => ["[status][is][new]"]})

      objectives_works_data_exporter = ObjectivesWorksExporter.new('', {program_id: program.id})
      sheet = ExcelBook.new('test').create_sheet(objectives_works_data_exporter.name)
      objectives_works_data_exporter.export(sheet)

      assert_equal 7, sheet.headings.count
      assert_equal 2, sheet.number_of_rows
      assert_equal ['Objective number', 'Objective title', 'Project', 'Card number', 'Card name', 'Filter', 'Done'], sheet.headings
      assert_equal ["##{objective.number}", objective.name, project.name, "#1", project.cards.first.name, 'status is new', 'No'] , sheet.row(1)
    end
  end

  def test_should_be_exportable_when_work_is_added_to_one_objective_at_least
    login_as_admin
    program = create_program
    plan = program.plan
    with_first_project do |project|
      program.projects << project
      property_to_map = project.find_property_definition("status")
      enumeration_value_to_map = property_to_map.enumeration_values.detect {|ev| ev.value == 'closed'}
      program_project = program.program_projects.first
      program_project.update_attributes(:status_property => property_to_map, :done_status => enumeration_value_to_map)
      program_project.reload

      objective = create_planned_objective program, :name => "objective new"
      plan.works.created_from(project).create!(:card_number => 1, :objective => objective, :name => project.cards.first.name)
      objectives_works_data_exporter = ObjectivesWorksExporter.new('', {program_id: program.id})
      assert objectives_works_data_exporter.exportable?
    end
  end

  def test_should_be_exportable_when_work_is_not_added_to_any_of_the_objectives
    login_as_admin
    program = create_program
    create_planned_objective program, :name => "objective new"
    objectives_works_data_exporter = ObjectivesWorksExporter.new('', {program_id: program.id})

    assert_false objectives_works_data_exporter.exportable?
  end
end
