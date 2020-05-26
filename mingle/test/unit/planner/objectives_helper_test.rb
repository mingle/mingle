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
require File.expand_path(File.dirname(__FILE__) + '/../renderable_test_helper')

class ObjectivesHelperTest < ActionController::TestCase
  include ObjectivesHelper, RenderableTestHelper::Unit

  def setup
    @program = program('simple_program')
    @plan = @program.plan
    @objective = @program.objectives.find_by_name('objective a')
  end

  def test_work_progress_message_and_its_link
    @plan.assign_cards(sp_first_project, [1, 2], @objective)
    assert_match(/0 of 2 work items are done/, work_progress_message)

    assert_include(program_plan_objective_works_path(@plan.program, @objective), work_progress_message_link)
    assert_include("filters%5B%5D=%5Bstatus%5D%5Bis%5D%5Bdone%5D", work_progress_message_link)
    assert_include("/programs/#{@plan.program.to_param}/plan/objectives/objective_a", work_progress_message_link)
  end

  def test_work_progress_message_should_be_blank_when_there_is_no_work
    assert_nil work_progress_message
  end

  def test_view_plan_objective_work_path_should_filter_work_when_no_done_status_mapped
    login_as_admin
    @plan.program.update_project_status_mapping(sp_first_project, :status_property_name => 'status', :done_status => 'closed')
    @plan.assign_cards(sp_first_project, [1], @objective)
    assert_equal program_plan_objective_works_path(@plan.program, @objective, :filters => ['[status][is not][done]'].sort), plan_objective_work_path(@plan.program, @objective, {:status => ['is not', 'done']})
  end

  def test_objective_name_tag_to_be_span_on_no_value_statement
    assert_equal objective_name_tag(@objective), "<span>#{@objective.name}</span>"
    @objective.value_statement = ""
    assert_equal objective_name_tag(@objective), "<span>#{@objective.name}</span>"
  end

  def test_objective_name_tag_with_value_statement_to_be_link
    @objective.value_statement = "something defined"
    assert_match(/<a .*>#{@objective.name}<\/a>/, objective_name_tag(@objective))
  end

  def url_for(options)
    FakeViewHelper.new.url_for(options)
  end

  def protect_against_forgery?
    false
  end
end
