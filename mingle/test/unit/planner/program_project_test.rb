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

class ProgramProjectTest < ActiveSupport::TestCase
  def setup
    login_as_admin
    @program = program('simple_program')
    @plan = @program.plan
  end

  def test_update_project_status_mapping_should_assign_completed_for_all_works_added_after
    project = sp_first_project
    objective = @program.objectives.first
    update_card_properties(project, :number => 1, 'status' => 'closed')

    @plan.assign_cards(project, 1, objective)
    work = objective.works.first
    assert work.completed?
  end

  def test_program_project_should_know_done_property
    project = first_project
    with_first_project do |project|
      program = create_program
      plan = program.plan
      program.projects << project
      property_to_map = project.find_property_definition("status")
      enumeration_value_to_map = property_to_map.enumeration_values.detect{|ev| ev.value == 'closed'}
      program_project = program.program_projects.first
      program_project.update_attributes(:status_property => property_to_map, :done_status => enumeration_value_to_map)
      program_project.reload
      assert_equal property_to_map, program_project.status_property
      assert_equal enumeration_value_to_map, program_project.done_status
    end
  end
  
  def test_should_know_if_status_mapping_configured
    project = first_project
    with_first_project do |project|
      program = create_program
      plan = program.plan
      program.projects << project
      
      property_to_map = project.find_property_definition("status")
      enumeration_value_to_map = property_to_map.enumeration_values.detect{|ev| ev.value == 'closed'}
      program_project = program.program_projects.first
      
      assert_false program_project.mapping_configured?
      
      program_project.update_attributes(:status_property => property_to_map, :done_status => enumeration_value_to_map)
      program_project.reload
      assert program_project.mapping_configured?
    end
  end
  
  # bug 13589
  def test_removing_mapped_status_should_remove_mapping
    with_new_project do |project|
        program = create_program
        program.projects << project
        
        setup_property_definitions('status' => ['not done', 'done'])
        property_to_map = project.find_property_definition('status')
        
        enumeration_value_to_map = property_to_map.enumeration_values.detect{|ev| ev.value == 'done'}
        program_project = program.program_projects.first

        assert_false program_project.mapping_configured?
        program_project.update_attributes(:status_property => property_to_map, :done_status => enumeration_value_to_map)
        program_project.reload
        assert program_project.mapping_configured?
        enumeration_value_to_map.destroy
        program_project.reload
        
        assert_false program_project.mapping_configured?
    end
  end

  def test_should_delete_objective_filters_when_delete_program_project
    objective_a = @program.objectives.find_by_name('objective a')
    project = sp_first_project
    objective_a.filters.create!(:project => project, :params => {:filters => ["[status][is][new]"]})

    @program.program_projects.find_by_project_id(sp_first_project.id).destroy

    assert_equal 0, objective_a.reload.filters.size
  end

  def test_should_delete_objective_filters_for_specified_plan_only
    objective = @program.objectives.find_by_name('objective a')
    project = sp_first_project
    objective.filters.create!(:project => project, :params => {:filters => ["[status][is][new]"]})
    program_a = create_program
    plan_a = program_a.plan
    plan_a.program.projects << project
    objective_a = program_a.objectives.create({:name => 'objective', :start_at => Time.now, :end_at => 4.days.from_now})

    objective_a.filters.create!(:project => project, :params => {:filters => ["[status][is][new]"]})

    @program.program_projects.find_by_project_id(sp_first_project.id).destroy

    assert_equal 0, objective.reload.filters.size
    assert_equal 1, objective_a.reload.filters.size
  end

  def test_update_project_status_mapping_should_assign_completed_for_existing_works_with_null_completed
    project = sp_first_project
    objective = create_simple_objective(:projects => [project])
    plan = objective.program.plan
    plan.assign_cards(project, 1, objective)
    work = plan.works.first
    assert work.completed.nil?

    program = plan.program
    program.update_project_status_mapping(project, { :status_property_name => 'status', :done_status => 'closed' })
    assert_false work.reload.completed
  end

  def test_should_give_error_when_could_not_find_given_property_name
    project = sp_first_project
    assert !@program.update_project_status_mapping(project, { :status_property_name => 'status not exists', :done_status => :closed })
    assert_equal ['Property status not exists not found.'], @program.errors.full_messages
  end

  def test_should_give_error_when_could_not_find_given_property_value
    project = sp_first_project
    assert !@program.update_project_status_mapping(project, { :status_property_name => 'status', :done_status => 'not exist' })
    assert_equal ['Property value not exist not found.'], @program.errors.full_messages
  end

  def test_projects_with_work_in_an_objective
    objective = @program.objectives.first
    @plan.assign_cards(sp_first_project, [1, 2], objective)
    @plan.assign_cards(sp_second_project, [1, 2], objective)

    assert_equal ['sp_first_project', 'sp_second_project'].sort, @program.projects_with_work_in(objective).collect(&:identifier).sort
  end
end
