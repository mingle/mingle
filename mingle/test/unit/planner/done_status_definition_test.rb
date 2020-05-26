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

class DoneStatusDefinitionTest < ActionController::TestCase

  def setup
    login_as_admin
    @program = create_program
    @plan = @program.plan
  end

  def test_as_mql_should_match_done_status
    @program.assign(stack_bar_chart_project)
    @program.update_project_status_mapping(stack_bar_chart_project, :status_property_name => 'status', :done_status => 'done')
    program_project = @plan.program.program_project(stack_bar_chart_project)
    assert_equal "'Status' >= 'Done'", program_project.done_status_definition.as_mql
  end
  
  def test_as_mql_should_quote_done_property_name_and_status
    with_new_project do |project|
      @program.assign project
      setup_property_definitions 'Card Status' => ['Ready', 'In Progress', 'Building in Go', 'Deployed', 'Closed'] 
      @program.update_project_status_mapping(project, :status_property_name => 'Card Status', :done_status => 'Building in Go')
      program_project = @plan.program.program_project(project)
      assert_equal "'Card Status' >= 'Building in Go'", program_project.done_status_definition.as_mql
    end
  end

  def test_includes_matches_the_correct_statuses
    with_new_project do |project|
      @program.assign(project)
      setup_property_definitions 'Card Status' => ['Ready', 'In Progress', 'Building in Go', 'Deployed', 'Closed'] 
      @program.update_project_status_mapping(project, :status_property_name => 'Card Status', :done_status => 'Building in Go')
      program_project = @plan.program.program_project(project)
      assert !program_project.done_status_definition.includes?('Ready')
      assert !program_project.done_status_definition.includes?('In Progress')
      assert program_project.done_status_definition.includes?('Building in Go')
      assert program_project.done_status_definition.includes?('Deployed')
      assert program_project.done_status_definition.includes?('Closed')
    end
  end

  def test_should_not_create_a_done_definition_status_when_the_status_is_not_defined
    with_new_project do |project|
      @program.assign(project)
      setup_property_definitions 'Card Status' => ['Ready', 'In Progress', 'Building in Go', 'Deployed', 'Closed'] 
      program_project = @plan.program.program_project(project)
      assert_nil program_project.done_status_definition
    end
  end
end
