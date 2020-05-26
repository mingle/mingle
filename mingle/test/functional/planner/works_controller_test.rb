# coding: utf-8

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

class WorksControllerTest < ActionController::TestCase
  def setup
    @controller = WorksController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as_admin
    @program = program('simple_program')
    @plan = @program.plan
  end

  def test_cards_should_accept_a_project_id_param_to_initialize_project_selection
    objective = @program.objectives.first
    get :cards, :program_id => @program.to_param, :objective_id => objective.to_param, :project_id => sp_second_project.identifier
    assert_response :success
    assert_select "input[name=project_id][value=#{sp_second_project.identifier}]"
  end

  def test_cards_on_plan_with_no_projects_should_display_warning
    program = create_program
    objective = create_planned_objective(program, :name => 'factotum')
    get :cards, :program_id => program.to_param, :objective_id => objective.to_param
    assert_select 'h1 span', :text => 'Step 1:', :count => 0
    assert_select 'p', :text => /projects/
  end

  def test_cards_should_not_display_checkbox_for_assigned_card
    objective = @program.objectives.first
    with_sp_first_project do |project|
      @plan.assign_cards(project, 1, objective)
    end

    get :cards, :project_id => sp_first_project.identifier, :filters => '[type][is][card]', :program_id => @program.to_param, :objective_id => objective.to_param
    assert_select '#filters_result input[disabled=disabled].select_card', :count => 1
  end

  def test_cards_should_not_find_results_for_other_projects
    first_project_card_name = ""
    objective = @program.objectives.first
      with_sp_first_project do |project|
      card = project.cards.first
      first_project_card_name = card.name
      @plan.works.created_from(project).scheduled_in(objective).create(:card_number => card.number)
    end
    second_project_card_name = ""
    with_sp_second_project do |project|
      card = project.cards.first
      second_project_card_name = card.name
      @plan.works.created_from(project).scheduled_in(objective).create(:card_number => card.number)
    end
    get :cards, :project_id => sp_first_project.identifier, :filters => '[type][is][card]', :program_id => @program.to_param, :objective_id => objective.to_param
    assert_select 'td', :text => first_project_card_name
    assert_select 'td', :text => second_project_card_name, :count => 0
  end

  def test_cards_should_display_last_page_when_page_number_is_greater_than_max_page_number
    objective = @program.objectives.first
    with_page_size(1) do
      get :cards, :project_id => sp_first_project.identifier, :filters => '[type][is][card]', :program_id => @program.to_param, :objective_id => objective.to_param, :page => 100
      assert_select ".pagination .current", :text => '2', :count => 2
    end
  end

  def test_fetch_cards_should_pull_cards_from_specific_project
    objective = @program.objectives.first
    get :cards, :project_id => sp_first_project.identifier, :filters => '[type][is][card]', :program_id => @program.to_param, :objective_id => objective.to_param
    assert_response :success
    assert_select "#filters_result tbody > tr", :count => 2
    with_sp_first_project do |project|
      project.cards.each do |card|
        assert_select "td a", :value => card.number
        assert_select "td a", :text => card.name
      end
    end
    assert_select "input", :value => 'Cancel'
  end

  def test_the_selected_project_should_be_the_one_pulled_cards
    objective = @program.objectives.first
    get :cards, :project_id => sp_second_project.identifier, :filters => '[type][is][card]', :program_id => @program.to_param, :objective_id => objective.to_param
    assert_response :success
    assert_select "input[name=project_id][value=#{sp_second_project.identifier}]"
  end

  def test_pull_cards_paginates_should_show_correct_page_of_cards
    objective = @program.objectives.first
    with_page_size(1) do
      with_sp_first_project do |project|
        assert_equal 2, project.cards.count
        get :cards, :project_id => sp_first_project.identifier, :filters => "[type][is][card]", :page => 2, :program_id => @program.to_param, :objective_id => objective.to_param
        second_card = project.cards.sort_by(&:number).reverse[1]
        assert_select "td a", :text => second_card.name
        assert_select ".pagination .current", :text => '2', :count => 2
      end
    end
  end

  def test_bulk_create_should_rais_user_access_authorization_error_when_project_is_not_assigned_to_plan
    objective = @program.objectives.first
    assert_raise ErrorHandler::UserAccessAuthorizationError, ErrorHandler::FORBIDDEN_MESSAGE do
      post :bulk_create, :program_id => @program.to_param, :objective_id => objective.to_param, :card_numbers => [1], :project_id => first_project.identifier
    end
  end

  def test_bulk_create_works_from_cards
    objective = @program.objectives.first
    assert_difference "Work.count", 2 do
      post :bulk_create, :program_id => @program.to_param, :objective_id => objective.to_param, :card_numbers => [1, 2], :filters => '[type][is][card]', :project_id => sp_first_project.identifier
      assert_redirected_to cards_program_plan_objective_works_url(@plan.program, objective, :filters => '[type][is][card]', :project_id => sp_first_project.identifier)
      assert_equal "2 cards added to the feature #{objective.name.bold}.", flash[:notice]
    end
  end

  def test_bulk_create_works_should_redirect_to_same_page_number
    objective = @program.objectives.first
    with_page_size(1) do
      params = { :project_id => sp_first_project.identifier, :filters => '[type][is][card]', :filter_page => 1 }
      post :bulk_create, { :program_id => @program.to_param, :objective_id => objective.to_param, :card_numbers => [1,2] }.merge(params)
      assert_redirected_to cards_program_plan_objective_works_url(@plan.program, objective, params)
    end
  end

  def test_cards_should_not_display_cards_for_project_not_related_to_plan
    objective = @program.objectives.first
    assert_raise ErrorHandler::UserAccessAuthorizationError, ErrorHandler::FORBIDDEN_MESSAGE do
      get :cards, :project_id => first_project.identifier, :program_id => @program.to_param, :objective_id => objective.to_param
    end
  end

  def test_cards_action_should_make_objectives_tab_selected
    objective = @program.objectives.first
    get :cards, :project_id => sp_first_project.identifier, :program_id => @program.to_param, :objective_id => objective.to_param
    assert_select "li.selected a", :text => "Plan"
  end

  def test_should_show_navigation_bar_when_add_works_to_objective
    objective = @program.objectives.find_by_name('objective a')
    get :cards, :program_id => @program.to_param, :objective_id => objective.to_param
    assert_select "#page_navigator", :text => "objective a &raquo; Add Work"
  end

  def test_should_show_all_works_in_objective

    objective = @program.objectives.first
    @plan.assign_cards(sp_first_project, [1, 2], objective)
    get :index, :program_id => @program.to_param, :objective_id => objective.to_param
    assert_select "tr.work_row", :count => 2
  end

  def test_index_paginates

    objective = @program.objectives.first
    with_page_size(1) do
      @plan.assign_cards(sp_first_project, [1, 2], objective)
      get :index, :program_id => @program.to_param, :objective_id => objective.to_param, :page => 2
      assert_select "tr.work_row", :count => 1
    end
  end

  def test_index_should_display_last_page_when_page_number_is_greater_than_max_page_number

    objective = @program.objectives.first
    with_page_size(1) do
      @plan.assign_cards(sp_first_project, [1, 2], objective)
      get :index, :program_id => @program.to_param, :objective_id => objective.to_param, :page => 100

      assert_select ".pagination .current", :text => '2', :count => 2
    end
  end

  def test_index_sorted_by_project_name_ascending
    objective = @program.objectives.first
    @plan.assign_cards(sp_second_project, 1, objective)
    @plan.assign_cards(sp_first_project, [1, 2], objective)

    get :index, :program_id => @program.to_param, :objective_id => objective.to_param, :page => 1
    assert_select '.project a' do |elements|
      assert_equal ['Simple Program sp_first_project', 'Simple Program sp_first_project', 'Simple Program sp_second_project'], elements.map { |element| element.children.first.to_s.strip }
    end
  end

  def test_index_sorted_by_project_name_and_then_card_number_descending
    objective = @program.objectives.first
    @plan.assign_cards(sp_first_project, [1, 2], objective)

    get :index, :program_id => @program.to_param, :objective_id => objective.to_param, :page => 1
    assert_select '.number a' do |elements|
      assert_equal '2', elements[0].children.first.to_s
      assert_equal '1', elements[1].children.first.to_s
    end
  end

  def test_message_instead_of_table_when_there_are_no_works

    objective = @program.objectives.first
    get :index, :program_id => @program.to_param, :objective_id => objective.to_param
    assert_select "#work_index", :count => 0
    assert_select ".results_notice", :text=> /no work/
  end

  def test_works_should_link_to_cards

    objective = @program.objectives.first
    @plan.assign_cards(sp_first_project, [1, 2], objective)

    get :index, :program_id => @program.to_param, :objective_id => objective.to_param
    assert_response :success

    assert_select 'a[href=?]', "/projects/sp_first_project/cards/1", {:text => '1', :count => 1}
    assert_select 'a[href=?]', "/projects/sp_first_project/cards/1", {:text => 'sp_first_project card 1', :count => 1}
    assert_select 'a[href=?]', "/projects/sp_first_project/cards/2", {:text => '2', :count => 1}
    assert_select 'a[href=?]', "/projects/sp_first_project/cards/2", {:text => 'sp_first_project card 2', :count => 1}
  end

  def test_should_raise_invalid_planner_resources_error_when_plan_doesnt_exist

    objective = @program.objectives.first
    assert_raise(ErrorHandler::InvalidResourceError) do
      get :index, :plan_id => "doesnnotexist", :objective_id => objective.to_param
    end
  end

  def test_should_raise_invalid_planner_resources_when_objective_doesnt_exist

    assert_raise(ErrorHandler::InvalidResourceError) do
      get :cards, :program_id => @program.to_param, :objective_id => 'notexistobjective'
    end
  end

  def test_query_cards_by_filters

    objective = @program.objectives.first
    with_sp_first_project do |project|
      create_card!(:number => 3, :name => 'status is open', :status => 'open')
    end
    get :cards, :project_id => sp_first_project.identifier, :filters => ["[status][is][open]"], :program_id => @program.to_param, :objective_id => objective.to_param
    assert_response :success
    assert_equal 1, assigns['filters_cards'].size
  end

  def test_query_card_by_invalid_filters

    objective = @program.objectives.first
    get :cards, :project_id => sp_first_project.identifier, :filters => ["[status][is][notexist]"], :program_id => @program.to_param, :objective_id => objective.to_param
    assert_response :success
    assert_equal 0, assigns['filters_cards'].size
    assert_equal 0, assigns['matching_card_count']
    assert_match /.*contains invalid value .*notexist.*/i, flash.now[:error]
  end

  def test_index_should_render_works_sorted_by_project_and_card_number_desc
    objective_a = @program.objectives.find_by_name('objective a')
    objective_b = @program.objectives.find_by_name('objective b')

    @plan.assign_cards(sp_second_project, 3, objective_b)
    @plan.assign_cards(sp_second_project, 1, objective_b)
    @plan.assign_cards(sp_first_project, 1, objective_b)
    @plan.assign_cards(sp_first_project, 2, objective_a)

    get :index, :program_id => @program.to_param, :objective_id => objective_b.to_param

    objective_names = assigns['works'].map(&:objective).map(&:name)
    project_names = assigns['works'].map(&:project).map(&:name)
    card_numbers = assigns['works'].map(&:card_number)

    rows = objective_names.zip(project_names, card_numbers)

    assert_equal [
                  ['objective b', 'Simple Program sp_first_project', 1],
                  ['objective b', 'Simple Program sp_second_project', 3],
                  ['objective b', 'Simple Program sp_second_project', 1],
                 ], rows
  end

  def test_index_should_render_works_sorted_by_project_name_case_insensitive
    project1 = with_new_project(:name => 'project a') do |project|
      create_card!(:number => 1, :name => 'sp a card')
      project
    end
    project2 = with_new_project(:name => 'project B') do |project|
      create_card!(:number => 1, :name => 'sp B card')
      project
    end
    project3 = with_new_project(:name => 'project c') do |project|
      create_card!(:number => 1, :name => 'sp c card')
      project
    end
    @program.projects = @program.projects + [project1, project2, project3]
    objective = @program.objectives.find_by_name('objective a')
    @plan.assign_cards(project1, 1, objective)
    @plan.assign_cards(project2, 1, objective)
    @plan.assign_cards(project3, 1, objective)

    get :index, :program_id => @program.to_param, :objective_id => objective.to_param

    project_names = assigns['works'].map(&:project).map(&:name)
    assert_equal ['project a', 'project B', 'project c'], project_names
  end

  def test_index_should_show_correct_data

    objective = @program.objectives.find_by_name('objective a')
    @plan.assign_cards(sp_first_project, 1, objective)
    get :index, :program_id => @program.to_param, :objective_id => objective.to_param
    assert_select '#header-pills li.selected', :text => 'Plan'
    assert_select "td.project a", :text => sp_first_project.name
    assert_select "td.number a[href=?]", "/projects/sp_first_project/cards/1", :text => '1'
    assert_select "td.name a[href=?]", "/projects/sp_first_project/cards/1", :text => 'sp_first_project card 1'
  end

  def test_should_show_status_as_done_if_matched_status_mapping

    objective = @program.objectives.first
    @plan.assign_cards(sp_first_project, 1, objective)
    update_card_properties(sp_first_project, :number => 1, :status => 'closed')
    get :index, :program_id => @program.to_param, :objective_id => objective.to_param
    assert_select "td.status", :text => 'Done'
  end

  def test_should_show_status_as_not_done_if_not_matched

    objective = @program.objectives.first
    @plan.assign_cards(sp_first_project, 1, objective)
    get :index, :program_id => @program.to_param, :objective_id => objective.to_param
    assert_select "td.status", :text => 'Not done'
  end

  def test_should_show_status_as_not_defined_if_done_status_not_mapped

    objective = @program.objectives.first
    @plan.assign_cards(sp_second_project, 1, objective)
    get :index, :program_id => @program.to_param, :objective_id => objective.to_param
    assert_select "td.status a", :text => /status not defined for project/
  end

  def test_index_should_see_no_work_message

    objective = @program.objectives.first
    get :index, :program_id => @program.to_param, :objective_id => objective.to_param
    assert_select 'td', :text => 'This plan has no work.'
  end

  def test_can_delete_work

    objective = @program.objectives.first
    @plan.assign_cards(sp_first_project, 1, objective)
    assert_difference "Work.count", -1 do
      post :bulk_delete, :program_id => @program.to_param, :objective_id => objective.to_param, :works => [@plan.works.first.id]
      assert_redirected_to :action => :index
    end
  end

  def test_bulk_delete_should_remember_filters

    objective = @program.objectives.first
    @plan.assign_cards(sp_first_project, 1, objective)
    post :bulk_delete, :program_id => @program.to_param, :objective_id => objective.to_param, :works => [@plan.works.first.id]
    assert_redirected_to :action => :index
  end

  def test_can_bulk_delete_work

    objective = @program.objectives.first
    @plan.assign_cards(sp_first_project, [1, 2], objective)
    assert_difference "Work.count", -2 do
      post :bulk_delete, :program_id => @program.to_param, :objective_id => objective.to_param, :works => @plan.works.collect(&:id)
      assert flash[:notice].present?
    end
  end

  def test_bulk_delete_should_stay_on_same_page

    objective = @program.objectives.first
    @plan.assign_cards(sp_first_project, 1, objective)
    post :bulk_delete, :program_id => @program.to_param, :objective_id => objective.to_param, :works => [@plan.works.first.id], :page => 2
    assert_redirected_to :action => :index, :page => 2
  end

  def test_apply_filter_to_work_list

    objective_a = @program.objectives.find_by_name('objective a')
    objective_b = @program.objectives.find_by_name('objective b')
    @plan.assign_cards(sp_first_project, 1, objective_a)
    @plan.assign_cards(sp_first_project, 2, objective_b)

    get :index, :program_id => @program.to_param, :objective_id => objective_b.to_param, :filters => ['[status][is not][done]']
    assert_equal 1, assigns['works'].size
  end

  def test_should_show_message_about_reset_filter_when_no_work_found_but_there_are_work_in_objective

    objective = @program.objectives.find_by_name('objective a')
    @plan.assign_cards(sp_first_project, 1, objective)

    get :index, :program_id => @plan.program.to_param, :objective_id => objective.to_param, :filters => ['[status][is][done]']

    assert_select 'td', :text => 'There are no work items that match the current filter – Reset filter.'
    assert_select '.results_notice a', :text => 'Reset filter'
  end

  def test_apply_filter_by_ajax_call

    objective_a = @program.objectives.find_by_name('objective a')
    objective_b = @program.objectives.find_by_name('objective b')
    @plan.assign_cards(sp_first_project, 1, objective_a)
    @plan.assign_cards(sp_first_project, 2, objective_b)

    xhr :get, :index, :program_id => @program.to_param, :objective_id => objective_a.to_param
    assert_equal 1, assigns['works'].size
    assert_rjs :replace, 'work_list'
  end

  def test_should_have_correct_title_for_index

    objective = @program.objectives.first
    get :index, :program_id => @program.to_param, :objective_id => objective.to_param
    assert_select "head title", :text => "Work - Mingle"
  end

  def test_should_have_correct_title_for_cards

    objective = @program.objectives.first
    get :cards, :program_id => @program.to_param, :objective_id => objective.to_param
    assert_select "head title", :text => "Add Work - Mingle"
  end

  def test_turn_on_autosync_should_create_objective_filter

    objective = @program.objectives.first
    project = sp_first_project
    xhr :post, :cards, :autosync => 'on', :project_id => project.identifier, :filters => ["[Type][is][card]"], :program_id => @program.to_param, :objective_id => objective.to_param
    assert_redirected_to :action => 'cards'

    assert_equal 1, objective.reload.filters.size
    filter = objective.filters.first
    assert_equal project, filter.project
    assert_equal({:filters => ["[Type][is][card]"]}, filter.params)
  end

  def test_turn_off_autosync_should_remove_objective_filter

    objective = @program.objectives.first
    project = sp_first_project
    xhr :post, :cards, :autosync => 'on', :project_id => project.identifier, :filters => ["[Type][is][card]"], :program_id => @program.to_param, :objective_id => objective.to_param
    xhr :post, :cards, :project_id => project.identifier, :filters => ["[Type][is][card]"], :program_id => @program.to_param, :objective_id => objective.to_param

    assert_redirected_to :action => 'cards'
    assert_equal 0, objective.reload.filters.size
  end

  def test_turn_off_an_invalid_objective_filter

    objective = @program.objectives.first
    project = sp_first_project
    xhr :post, :cards, :autosync => 'on', :project_id => project.identifier, :filters => ["[status][is][new]"], :program_id => @program.to_param, :objective_id => objective.to_param

    project.with_active_project do |project|
      project.find_property_definition('status').enumeration_values_association.find_by_value('new').destroy
    end

    xhr :post, :cards, :project_id => project.identifier, :program_id => @program.to_param, :objective_id => objective.to_param

    assert_equal 0, objective.reload.filters.size
  end

  def test_autosync_should_create_only_one_filter_per_project

    objective = @program.objectives.first
    project = sp_first_project
    xhr :post, :cards, :autosync => 'on', :project_id => project.identifier, :filters => ["[Type][is][card]"], :program_id => @program.to_param, :objective_id => objective.to_param
    xhr :post, :cards, :autosync => 'on', :project_id => project.identifier, :filters => ["[status][is][new]"], :program_id => @program.to_param, :objective_id => objective.to_param

    assert_equal 1, objective.reload.filters.size
    assert_equal({:filters => ["[Type][is][card]"]}, objective.filters.first.params)
  end

  def test_should_not_turn_off_autosync_when_get_cards_page

    objective = @program.objectives.first
    project = sp_first_project

    get :cards, :project_id => project.identifier, :program_id => @program.to_param, :objective_id => objective.to_param
    assert_select '#autosync[checked]', false

    xhr :post, :cards, :autosync => 'on', :project_id => project.identifier, :filters => ["[Type][is][card]"], :mql => "status is new", :program_id => @program.to_param, :objective_id => objective.to_param

    get :cards, :project_id => project.identifier, :program_id => @program.to_param, :objective_id => objective.to_param

    assert_equal 1, objective.reload.filters.size
    assert_select '#autosync[checked=checked]', true
  end

  def test_should_apply_objective_filter_if_turned_on_autosync

    objective = @program.objectives.first
    project = sp_first_project
    get :cards, :project_id => project.identifier, :program_id => @program.to_param, :objective_id => objective.to_param
    assert_select '#filters_result .cards .card-number', :count => 2

    xhr :post, :cards, :autosync => 'on', :project_id => project.identifier, :filters => ["[number][is][1]"], :program_id => @program.to_param, :objective_id => objective.to_param

    get :cards, :project_id => project.identifier, :program_id => @program.to_param, :objective_id => objective.to_param
    assert_select '.cards', :count => 0
    assert_select '#filters_result .info-box', :text => /1 card currently matches/
  end

  def test_should_update_hidden_fields_on_filters_update

    project = @program.projects.create(:name => 'new project', :identifier => 'new_project')
    project.save!

    card_type_bug = project.card_types.create :name => 'bug'
    card_type_story = project.card_types.create :name => 'story'
    card_type_bug.save!
    card_type_story.save!

    card_one = project.cards.create :number => 1, :name => 'one', :card_type => card_type_bug
    card_two = project.cards.create :number => 2, :name => 'two', :card_type => card_type_story
    card_one.save!
    card_two.save!

    xhr :get, :cards, :project_id => project.identifier, :filters => ["[Type][is][bug]"], :program_id => @program.to_param, :objective_id => @program.objectives.first.to_param
    assert_rjs :replace_html, "filters_result"
    assert_equal 1, assigns('matching_card_count')
    assert_rjs :replace, "autosync_form"
  end

  def test_should_hide_cards_table_and_show_match_count_after_turned_on_autosync

    objective = @program.objectives.first
    project = sp_first_project
    xhr :post, :cards, :autosync => 'on', :project_id => project.identifier, :filters => ["[number][is][1]"], :program_id => @program.to_param, :objective_id => objective.to_param
    get :cards, :project_id => project.identifier, :program_id => @program.to_param, :objective_id => objective.to_param

    assert_select '.condition-container .first-operand', :text => 'Number'
    assert_select '.condition-container .operator', :text => 'is'
    assert_select '.condition-container .second-operand', :text => '1'
    assert_select '#filters_result .cards', :count => 0
    assert_select '#filters_result .info-box', :text => /1 card currently matches/
  end

  def test_should_render_type_is_any_filter_when_auto_sync_without_any_filters

    objective = @program.objectives.first
    project = sp_first_project
    xhr :post, :cards, :autosync => 'on', :project_id => project.identifier, :filters => [], :program_id => @program.to_param, :objective_id => objective.to_param
    get :cards, :project_id => project.identifier, :program_id => @program.to_param, :objective_id => objective.to_param

    assert_select '.condition-container .first-operand', :text => 'Type'
    assert_select '.condition-container .operator', :text => 'is'
    assert_select '.condition-container .second-operand', :text => '(any)'
  end

  def test_readonly_filters_when_filter_is_invalid

    objective = @program.objectives.first
    project = sp_first_project
    xhr :post, :cards, :autosync => 'on', :project_id => project.identifier, :filters => ["[nonexistant][is][new]"], :program_id => @program.to_param, :objective_id => objective.to_param

    get :cards, :project_id => project.identifier, :program_id => @program.to_param, :objective_id => objective.to_param

    assert_select '.condition-container .first-operand', :text => 'nonexistant'
    assert_select '.condition-container .operator', :text => 'is'
    assert_select '.condition-container .second-operand', :text => 'new'
  end

  def test_redirect_to_clean_state_when_invalid_autosync_filter_is_turned_off

    objective = @program.objectives.first
    project = sp_first_project
    filter = objective.filters.new(:project => project, :params => {:filters => ["[unexisting][is][new]"]})
    filter.save(false)

    post :cards, :project_id => project.identifier, :program_id => @program.to_param, :objective_id => objective.to_param

    assert_redirected_to :action => 'cards', :project_id => project.identifier, :objective_id => objective.to_param, :program_id => @program.to_param, :filters => nil
  end

  def test_should_disable_work_checkbox_in_work_list_when_autosync_is_on_for_the_objective_and_project_of_the_work

    objective = @program.objectives.first
    project = sp_first_project
    @plan.assign_cards(project, [1], objective)
    xhr :post, :cards, :autosync => 'on', :project_id => project.identifier, :filters => ["[number][is][1]"], :program_id => @program.to_param, :objective_id => objective.to_param
    get :index, :program_id => @program.to_param, :objective_id => objective.to_param
    assert_select '.select_work[disabled=disabled]', :count => 1
  end

  def test_cards_should_not_be_accessible_when_readonly_mode_is_toggled_on
    MingleConfiguration.overridden_to(readonly_mode: true) do
      objective = @program.objectives.first
      assert_raise ErrorHandler::UserAccessAuthorizationError, ErrorHandler::FORBIDDEN_MESSAGE do
        get :cards, :program_id => @program.to_param, :objective_id => objective.to_param, :project_id => sp_second_project.identifier
      end
    end
  end

  def test_bulk_create_should_not_be_accessible_when_readonly_mode_is_toggled_on
    MingleConfiguration.overridden_to(readonly_mode: true) do
      objective = @program.objectives.first
      assert_raise ErrorHandler::UserAccessAuthorizationError, ErrorHandler::FORBIDDEN_MESSAGE do
        post :bulk_create, :program_id => @program.to_param, :objective_id => objective.to_param, :card_numbers => [1, 2], :filters => '[type][is][card]', :project_id => sp_first_project.identifier
      end
    end
  end

  def test_bulk_delete_should_not_be_accessible_when_readonly_mode_is_toggled_on
    MingleConfiguration.overridden_to(readonly_mode: true) do
      objective = @program.objectives.first
      @plan.assign_cards(sp_first_project, 1, objective)
      assert_raise ErrorHandler::UserAccessAuthorizationError, ErrorHandler::FORBIDDEN_MESSAGE do
        post :bulk_delete, :program_id => @program.to_param, :objective_id => objective.to_param, :works => [@plan.works.first.id]
      end
    end
  end

  def test_index_should_not_render_table_actions
    MingleConfiguration.overridden_to(readonly_mode: true) do
      objective = @program.objectives.first
      @plan.assign_cards(sp_first_project, [1, 2], objective)
      get :index, :program_id => @program.to_param, :objective_id => objective.to_param
      assert_select 'div.table_actions', :count => 0
      assert_select 'table thead tr th.checkbox', :count => 0
      assert_select 'table tbody tr td.checkbox .select_work', :count => 0
    end
  end
end
