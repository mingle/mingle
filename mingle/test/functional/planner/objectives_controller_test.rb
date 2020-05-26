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

class ObjectivesControllerTest < ActionController::TestCase
  def setup
    @controller = ObjectivesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as_admin

    @program = program('simple_program')
    @plan = @program.plan
  end

  def test_create_objective_should_respond_to_js_calls_using_standard_json_time_format
    post :create, :program_id => @program.to_param, :objective => {:name => 'new objective', :start_at => '2011-02-06', :end_at => '2011-03-07', :vertical_position => 1}
    assert_response :success

    assert_match "timeline.objectiveCreated", @response.body
    assert_match "2011-02-06", @response.body
    assert_match '2011-03-07', @response.body
  end

  def test_create_objective_should_update_js_side_plan
    post :create, :program_id => @program.to_param, :objective => {:name => 'new objective', :start_at => '2009-01-08', :end_at => '2011-03-07', :vertical_position => 1}
    assert_response :success

    assert_match "timeline.objectiveCreated", @response.body
    assert_match "2009-01-05", @response.body
    assert_match "PLANNED", @response.body
  end

  def test_create_objective_with_duplicate_name_should_show_error
    create_planned_objective(@program, :name => 'sample')
    post :create, :program_id => @program.to_param, :objective => {:name => 'sample', :start_at => '2011-02-06', :end_at => '2011-03-07', :vertical_position => 1}
    assert_response :success
    assert_rollback
    assert_match "timeline.objectiveCreationFailed", @response.body
  end

  def test_create_objective_with_blank_name_should_show_error
    post :create, :program_id => @program.to_param, :objective => {:name => '', :start_at => '2011-02-06', :end_at => '2011-03-07', :vertical_position => 1}
    assert_response :success
    assert_rollback
    assert_match /timeline.objectiveCreationFailed\(.*, \{\"errors\":\[\"Name can't be blank\"\]\}\)/, @response.body
  end

  def test_create_objective_with_duplicate_name_should_show_error_and_include_stripped_name
    create_planned_objective(@program, :name => 'no whitespace')
    post :create, :program_id => @program.to_param, :objective => {:name => '    no      whitespace     ', :start_at => '2011-02-06', :end_at => '2011-03-07', :vertical_position => 1}
    assert_match '"no whitespace"', @response.body
  end

  def test_update_objective_with_blank_name_should_see_error
    create_planned_objective(@program, :name => 'One')
    objective2 = create_planned_objective(@program, :name => 'Two')
    post :update, :program_id => @program.to_param, :id => objective2.to_param, :objective => {:name => '', :start_at => '2011-02-06', :end_at => '2011-03-07', :vertical_position => 1}
    assert flash.now[:error].any?
    assert_equal ["Name can't be blank"], flash.now[:error]
    assert_response :success
    assert_rollback
    assert_template :edit
  end

  def test_cancel_button_points_to_plan_show
    create_planned_objective(@program, :name => 'One')
    objective2 = create_planned_objective(@program, :name => 'Two')
    post :update, :program_id => @plan.program.identifier, :id => objective2.to_param, :objective => {:name => '', :start_at => '2011-02-06', :end_at => '2011-03-07', :vertical_position => 1}
    assert flash.now[:error].any?
    assert_template :edit
    assert_tag :tag => 'input', :attributes => { :value => 'Cancel', :onclick => "window.location.href = &quot;#{program_plan_url(@program)}&quot;;"}
  end

  def test_update_objective_should_redirected_to_objective_show_if_no_return_to_specified
    objective = create_planned_objective(@program, :name => 'One')

    post :update, :program_id => @program.to_param, :id => objective.to_param, :objective => {:name => 'updated objective'}
    objective.reload
    assert_equal "Feature #{objective.name.bold} was successfully updated.", flash[:notice]
    assert_equal 'updated objective', objective.name
    assert_redirected_to program_plan_path(@program)
  end

  def test_should_response_nothing_when_ajax_call_update_successfully
    objective = @program.objectives.first
    xhr :post, :update, :program_id => @program.to_param, :id => objective.to_param, :objective => {:name => 'updated objective', :start_at => '2009-01-08'}
    assert_response :success
    assert_match "2009-01-05", @response.body
  end

  def test_should_response_error_when_ajax_call_update_failed
    objective = @program.objectives.first
    xhr :post, :update, :program_id => @program.to_param, :id => objective.to_param, :objective => {:name => ''}
    assert_response 422
  end

  def test_delete_objective_destroys_objective
    objective_to_delete = @program.objectives.first
    assign_project_cards(objective_to_delete, sp_first_project)

    delete :destroy, :id => objective_to_delete.to_param, :program_id => @program.to_param
    assert_redirected_to program_plan_path(@program)
    assert_equal [], Objective.find_all_by_id(objective_to_delete.id)
    assert_equal 0, @program.objectives.backlog.count
    assert_equal "Feature #{objective_to_delete.name.bold} has been deleted.", flash[:notice]
  end

  def test_destroy_objective_with_create_backlog_objective_creates_backlog_objective
    objective_to_delete = @program.objectives.planned.first
    assign_project_cards(objective_to_delete, sp_first_project)
    delete :destroy, :id => objective_to_delete.to_param, :program_id => @program.to_param, :move_to_backlog => true
    assert_redirected_to program_plan_path(@program)
    assert_equal objective_to_delete.name, @program.objectives.backlog.first.name
    assert_equal Objective::Status::BACKLOG, @program.objectives.backlog.first.status
    assert_equal "Feature #{objective_to_delete.name.bold} has been moved to the backlog.", flash[:notice]
  end

  def test_confirm_delete_objective_with_works_shows_correct_warnings
    objective_to_delete = @program.objectives.first
    assign_project_cards(objective_to_delete, sp_first_project)
    get :confirm_delete, :id => objective_to_delete.to_param, :program_id => @program.to_param
    assert_response :success
  end

  def test_edit_should_not_pass_along_return_to_url_to_update_if_not_present
    objective = @program.objectives.first
    get :edit, :program_id => @plan.program.to_param, :id => objective.to_param
    assert_select "input[name='return_to']", :count => 0
  end

  def test_navigation_bar_on_edit_page
    objective = @program.objectives.find_by_name('objective a')
    get :edit, :program_id => @plan.program.to_param, :id => objective.to_param
    assert_select "#page_navigator", :text => "objective a &raquo; Edit"
  end

  def test_navigation_bar_on_confirm_delete_page
    objective = @program.objectives.find_by_name('objective a')
    get :confirm_delete, :program_id => @program.to_param, :id => objective.to_param
    assert_select "#page_navigator", :text => "objective a &raquo; Remove from plan"
  end

  def test_should_still_show_navigation_bar_when_update_failed
    objective = @program.objectives.find_by_name('objective a')
    post :update, :program_id => @program.to_param, :id => objective.to_param, :objective => {:name => ''}
    assert_select "#page_navigator", :text => "objective a &raquo; Edit"
  end

  def test_should_raise_invalid_plan_error_when_plan_doesnt_exist
    objective = @program.objectives.first
    assert_raise(ErrorHandler::InvalidResourceError) do
      get :edit, :plan_id => "doesnotexist", :id => objective.to_param
    end
  end

  def test_should_raise_invalid_objective_error_when_objective_doesnt_exist
    objective = @program.objectives.first
    assert_raise(ErrorHandler::InvalidResourceError) do
      get :edit, :program_id => @program.to_param, :id => "doesnotexist"
    end
  end

  def test_work_should_redirect_to_plan_works_and_filter_works_by_objective
    objective = @program.objectives.first
    get :work, :program_id => @program.to_param, :id => objective.to_param
    assert_redirected_to :controller => 'works', :action => 'index', :objective_id => objective.to_param
  end

  def test_work_progress_json
    project = sp_second_project
    @program.update_project_status_mapping(project, :status_property_name => 'status', :done_status => 'closed')

    Clock.fake_now(:year => 2012, :month => 1, :day => 1)
    objective = create_planned_objective(@program, {:name => 'first objective', :start_at => Clock.now, :end_at => 10.days.from_now(Clock.now) })

    project.with_active_project do |project|
      Clock.fake_now(:year => 2012, :month => 1, :day => 2)
      @plan.assign_cards(project, [1], objective)
      ObjectiveSnapshot.rebuild_snapshots_for(objective.id, project.id)
      Clock.fake_now(:year => 2012, :month => 1, :day => 3)
      @plan.assign_cards(project, [2], objective)
      ObjectiveSnapshot.rebuild_snapshots_for(objective.id, project.id)
      Clock.fake_now(:year => 2012, :month => 1, :day => 4)
      ObjectiveSnapshot.rebuild_snapshots_for(objective.id, project.id)
      @plan.assign_cards(project, [3], objective)
      card = project.cards.first
      card.update_properties(:status => "closed")
      card.save!

      Clock.fake_now(:year => 2012, :month => 1, :day => 5)
      ObjectiveSnapshot.rebuild_snapshots_for(objective.id, project.id)
      card3 = project.cards.find_by_number(3)
      raise "can't find card3" if card3.nil?
      @plan.works.created_from_card(card3).first.destroy
    end

    get :work_progress, :program_id => @program.to_param, :id => objective.id, :project_id => project.identifier
    expected = ActiveSupport::JSON.decode({"progress"  => [ {:date => '2012-01-01', :actual_scope => 0, :completed_scope => 0},
                                                            {:date => '2012-01-02', :actual_scope => 1, :completed_scope => 0},
                                                            {:date => '2012-01-03', :actual_scope => 2, :completed_scope => 0},
                                                            {:date => '2012-01-04', :actual_scope => 3, :completed_scope => 1},
                                                            {:date => '2012-01-05', :actual_scope => 2, :completed_scope => 1}]}.to_json).sort

    assert_equal expected, ActiveSupport::JSON.decode(@response.body).sort
  end

  def test_index_returns_objectives_and_granularity
    objective = create_planned_objective(@program, :name => 'sample')
    get :index, :program_id => @program.to_param, :format => 'json'
    expected = ActiveSupport::JSON.decode({ :displayPreference => nil, :objectives => @plan.timeline_objectives}.to_json)["objectives"]
    actual = ActiveSupport::JSON.decode(@response.body)["objectives"]
    expected.each { |objective| assert actual.include?(objective) }

  end

  def test_check_synched_to_return_update_js_on_sync_finished
    objective = create_planned_objective(@program, :name => 'sample')

    get :timeline_objective, :program_id => @program.to_param, :id => objective.identifier, :format => 'json'
    assert_equal TimelineObjective.from(objective, @plan).to_json, @response.body
  end

  def test_view_value_statement_opens_up_light_box_with_value_statement
    objective = create_planned_objective(@program, :name => 'sample', :value_statement => 'invaluable objective')

    get :view_value_statement, :program_id => @program.to_param, :id => objective.identifier
    assert_match /.*Lightbox.*#{objective.value_statement}/m, @response.body
  end

  def test_restful_create_should_position_new_objectives_in_the_middle_of_timeline_when_no_other_positions_available
    (1..14).each do |i|
      create_planned_objective(@program, :name => "objective#{i}")
    end
    post :restful_create, { :program_id => @program.identifier, :objective => { :name => 'objective 15', :start_at => Clock.now.strftime(DateTimeConstants::ISO_DATE_FORMAT),
                            :end_at => 2.days.from_now(Clock.now).strftime(DateTimeConstants::ISO_DATE_FORMAT) }
                          }
    objective_15 = Objective.find_by_identifier('objective_15')
    assert objective_15
    assert_equal 6, objective_15.vertical_position
  end

  def test_restful_create_should_fail_for_incorrect_parameters
    response = post :restful_create, { :program_id => @program.identifier,
                                       :objective => { :name => 'An objective', :incorrect_start_date_param => Clock.now.strftime("%m/%d/%Y"),
                                                       :end_at => 2.days.from_now(Clock.now).strftime("%m/%d/%Y") } }
    assert_equal '422', response.code
    assert_equal "Invalid parameter(s) provided: incorrect_start_date_param", errors_from_rest_response(response.body).sort.first
  end

  def test_restful_create_should_fail_for_date_params_in_incorrect_date_formats
    response = post :restful_create, { :program_id => @program.identifier,
                                       :objective => { :name => 'An objective', :start_at => '2013/30/01',
                                                       :end_at => '02/01/2013' } } # 30-Jan-2013 to 01-Feb-2013
    assert_equal '422', response.code
    assert_equal ["The parameter 'start_at' was in an incorrect format. Please use 'yyyy-mm-dd'."], errors_from_rest_response(response.body)
  end

  def test_restful_create_should_validate_missing_parameters
    response = post :restful_create, { :program_id => @program.identifier,
                                       :objective => { :name => 'An objective' } }
    assert_equal '422', response.code
    assert_equal ["The parameter(s) 'start_at', 'end_at' were not provided."], errors_from_rest_response(response.body)
  end

  def test_restful_update_should_fail_for_incorrect_parameters
    response = post :restful_update, {
      :program_id => @program.identifier, :id => @program.objectives.first.identifier,
      :objective => { :incorrect_start_date_param => Clock.now.strftime("%m/%d/%Y") }
    }
    assert_equal '422', response.code
    assert_equal ["Invalid parameter(s) provided: incorrect_start_date_param"], errors_from_rest_response(response.body)
  end

  def test_restful_update_should_fail_for_date_params_in_incorrect_date_formats
    objective = @program.objectives.first
    response = post :restful_update, {
      :program_id => @program.identifier, :id => objective.identifier,
      :objective => { :end_at => '2013/30/12' }
    }

    assert_equal '422', response.code
    assert_equal ["The parameter 'end_at' was in an incorrect format. Please use 'yyyy-mm-dd'."], errors_from_rest_response(response.body)
  end

  def test_index_returns_objectives_and_granularity_when_readonly_mode_is_toggled_on
    MingleConfiguration.overridden_to(readonly_mode: true) do
      objective = create_planned_objective(@program, :name => 'sample')
      get :index, :program_id => @program.to_param, :format => 'json'
      expected = ActiveSupport::JSON.decode({:displayPreference => nil, :objectives => @plan.timeline_objectives}.to_json)["objectives"]
      actual = ActiveSupport::JSON.decode(@response.body)["objectives"]
      expected.each {|objective| assert actual.include?(objective)}
    end
  end

  def test_popup_details_returns_edit_and_remove_link
    MingleConfiguration.overridden_to(readonly_mode: true) do
      objective = create_planned_objective(@program, :name => 'sample')
      get :popup_details, :program_id => @program.to_param, :id => 'sample', :format => 'json'
      actual = @response.body
      assert_nil actual.match(/\/programs\/#{@program.identifier}\/plan\/objectives\/#{objective.name}\/edit.*Edit/)
      assert_nil actual.match(/\/programs\/#{@program.identifier}\/plan\/objectives\/#{objective.name}\/confirm_delete.*Remove/)
    end
  end

  def test_popup_details_should_not_render_add_project_link
    MingleConfiguration.overridden_to(readonly_mode: true) do
      program  = create_program
      create_planned_objective(program, :name => 'sample')
      get :popup_details, :program_id => program.to_param, :id => 'sample', :format => 'json'
      actual = @response.body
      assert_nil actual.match(/You must.*\/programs\/#{program.identifier}\/projects.*add projects.*to this plan before you can add work./)
      assert_nil actual.match(/\/programs\/#{program.identifier}\/projects.*Add projects/)
    end
  end

  def test_popup_details_should_not_render_add_work_link
    MingleConfiguration.overridden_to(readonly_mode: true) do
      program  = create_program
      project  = create_project
      program.projects << project
      create_planned_objective(program, :name => 'sample')
      get :popup_details, :program_id => program.to_param, :id => 'sample', :format => 'json'
      actual = @response.body
      assert_nil actual.match(/\/programs\/#{program.identifier}\/plan\/objectives\/sample\/work\/cards.*Add work.*to this feature.\b/)
      assert_nil actual.match(/\/programs\/#{program.identifier}\/plan\/objectives\/sample\/work\/cards.*Add work\b/)
    end
  end

  def test_should_not_allow_to_create_objective_when_readonly_mode_is_toggled_on
    MingleConfiguration.overridden_to(readonly_mode: true) do

      assert_raise ErrorHandler::UserAccessAuthorizationError, ErrorHandler::FORBIDDEN_MESSAGE do
        post :create, :program_id => @program.to_param, :objective => {:name => 'new objective', :start_at => '2011-02-06', :end_at => '2011-03-07', :vertical_position => 1}
      end

      assert_raise ErrorHandler::UserAccessAuthorizationError, ErrorHandler::FORBIDDEN_MESSAGE do
        post :restful_create, {:program_id => @program.identifier, :objective => {:name => 'objective 15', :start_at => Clock.now.strftime(DateTimeConstants::ISO_DATE_FORMAT),
                                                                                  :end_at => 2.days.from_now(Clock.now).strftime(DateTimeConstants::ISO_DATE_FORMAT)}
        }
      end
    end
  end

  def test_should_not_allow_to_update_objective_when_readonly_mode_is_toggled_on
    MingleConfiguration.overridden_to(readonly_mode: true) do
      objective = create_planned_objective(@program, :name => 'One')
      assert_raise ErrorHandler::UserAccessAuthorizationError, ErrorHandler::FORBIDDEN_MESSAGE do
        post :update, :program_id => @program.to_param, :id => objective.to_param, :objective => {:name => 'updated objective', :start_at => '2009-01-08'}
      end

      assert_raise ErrorHandler::UserAccessAuthorizationError, ErrorHandler::FORBIDDEN_MESSAGE do
        post :restful_update, {
            :program_id => @program.identifier, :id => objective.to_param,
            :objective => { :incorrect_start_date_param => Clock.now.strftime("%m/%d/%Y") }
        }
      end
    end
  end

  def test_should_not_allow_to_delete_objective_when_readonly_mode_is_toggled_on
    MingleConfiguration.overridden_to(readonly_mode: true) do
      objective = create_planned_objective(@program, :name => 'One')
      assert_raise ErrorHandler::UserAccessAuthorizationError, ErrorHandler::FORBIDDEN_MESSAGE do
        delete :destroy, :program_id => @program.to_param, :id => objective.to_param
      end

      assert_raise ErrorHandler::UserAccessAuthorizationError, ErrorHandler::FORBIDDEN_MESSAGE do
        post :restful_delete, :program_id => @program.identifier, :id => objective.to_param
      end
    end
  end

  def test_should_not_allow_to_access_confirm_delete_when_readonly_mode_is_toggled_on
    MingleConfiguration.overridden_to(readonly_mode: true) do
      objective = create_planned_objective(@program, :name => 'One')
      assert_raise ErrorHandler::UserAccessAuthorizationError, ErrorHandler::FORBIDDEN_MESSAGE do
        delete :confirm_delete, :program_id => @program.to_param, :id => objective.to_param
      end
    end
  end
  private

  def errors_from_rest_response(response_xml)
    doc = REXML::Document.new response_xml
    errors = REXML::XPath.match(doc, "//error").map(&:text)
  end
end
