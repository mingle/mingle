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

require File.expand_path(File.dirname(__FILE__) + '/../../functional_test_helper')

class PlansControllerTest < ActionController::TestCase
  
  def setup
    login_as_admin
    @program = create_program
  end

  def test_show_timeline_with_objectives_have_total_work_count
    program = program('simple_program')
    plan_objective = program.objectives.first
    program.plan.assign_cards(sp_first_project, 1, plan_objective)

    get :show, :program_id => program.to_param
    assert_equal 1, assigns['timeline_objectives'].detect {|objective| objective.id == plan_objective.id}.total_work
  end
  
  def test_should_show_plan_start_and_end_date
    program = program('simple_program')
    get :show, :program_id => program.to_param
    plan = program.plan
    assert_select 'a', :text => /#{plan.format_date(plan.start_at)} - #{plan.format_date(plan.end_at)}/
  end

  def test_show_passes_along_server_today
    expected_today = Time.now.strftime('%Y-%m-%d')
    get :show, :program_id => @program.to_param
    assert_match /#{expected_today}/, @response.body
  end

  def test_should_raise_invalid_plan_error_when_plan_doesnt_exist
    assert_raise(ErrorHandler::InvalidResourceError) do 
      get :show, :id => "doesnotexist"
    end
  end
  
  def test_update_should_go_to_timeline_on_success
    program = program('simple_program')
    put :update, :program_id => program.to_param, :plan => {:start_at => '2010-01-31', :end_at => '2011-05-13'}
    assert @response.body = /window.location.href = "programs\/my_new_identifier\/plan"/ 
    assert_equal "Plan has been updated", flash[:notice]
    program.plan.reload
    assert_equal Date.new(2010, 1, 25), program.plan.start_at
    assert_equal Date.new(2011, 5, 15), program.plan.end_at
  end

  def test_update_should_remain_on_edit_page_on_failure
    put :update, :program_id => @program.to_param, :plan => {:start_at => ''}
    assert flash.now[:error]
    assert_response :success
  end

  def test_should_show_plan_admin
    get :edit, :program_id => @program.to_param
    assert_response :success
    assert_match /Display start date/, @response.body
  end

end
