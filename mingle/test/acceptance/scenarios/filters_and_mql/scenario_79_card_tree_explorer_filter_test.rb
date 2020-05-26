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

require File.expand_path(File.dirname(__FILE__) + '/../../../acceptance/acceptance_test_helper')

#Tags: tree-usage, card-selector, tree-filters, card-list
class Scenario79CardTreeExplorerFilterTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  RELEASE = 'Release'
  ITERATION = 'Iteration'
  STORY = 'Story'
  TASK = 'Task'

  NOT_SET = '(not set)'
  ANY = '(any)'
  TYPE = 'Type'
  STATUS = 'status'
  NEW = 'new'
  OPEN = 'open'

  RELATIONSHIP_RELEASE = 'Planning Tree release'
  RELATIONSHIP_ITERATION = 'Planning Tree iteration'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_admin_user = users(:longbob)
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_79', :users => [@non_admin_user], :admins => [@project_admin_user])
    @property_status = setup_property_definitions(STATUS => [NEW,  OPEN])
    @type_story = setup_card_type(@project, STORY, :properties => [STATUS])
    @type_iteration = setup_card_type(@project, ITERATION)
    @type_release = setup_card_type(@project, RELEASE)
    @type_task = setup_card_type(@project, TASK, :properties => [STATUS])
    login_as_proj_admin_user
    @release1 = create_card!(:name => 'release 1', :description => "super plan", :card_type => RELEASE)
    @release2 = create_card!(:name => 'release 2', :card_type => RELEASE)
    @iteration1 = create_card!(:name => 'iteration 1', :card_type => ITERATION)
    @iteration2 = create_card!(:name => 'iteration 2', :card_type => ITERATION)
    @story1 = create_card!(:name => 'story 1', :card_type => STORY)
    @planning_tree = setup_tree(@project, 'Planning', :types => [@type_release, @type_iteration, @type_story], :relationship_names => [RELATIONSHIP_RELEASE, RELATIONSHIP_ITERATION])
    add_card_to_tree(@planning_tree, @release1)
  end

  #bug 4225
  def test_reset_filter_link_on_tree_view_should_not_deselects_tree
     add_properties_for_existing_card_type(@project, @type_release, STATUS)
     navigate_to_tree_view_for(@project, @planning_tree.name,[])
     add_new_tree_filter_for(@type_release)
     set_the_tree_filter_property_option(@type_release, 0, STATUS)
     set_the_tree_filter_value_option(@type_release, 0, NEW)
     delete_enumeration_value_for(@project, STATUS, NEW, :requires_confirmation => false, :stop_at_confirmation => false)
     click_all_tab
     assert_error_message("Filter is invalid. Property #{STATUS} contains invalid value #{NEW}")
     reset_tree_filter
     assert_location_url("/projects/#{@project.identifier}/cards/tree?tab=All&tree_name=#{@planning_tree.name}")
  end

  def test_only_types_configured_in_tree_are_available_in_explorer_filter
    open_card_explorer_for(@project, @planning_tree)
    assert_value_not_present_in_filter(TASK, 0)
    assert_value_present_in_filter(RELEASE, 0)
    assert_value_present_in_filter(ITERATION, 0)
    assert_value_present_in_filter(STORY, 0)
  end

  def test_filter_for_type_always_exsists_and_set_to_any
    open_card_explorer_for(@project, @planning_tree)
    assert_type_present_with_default_selected_as_any
    assert_first_filter_cannot_be_deleted
  end

  def test_all_filters_except_first_one_can_be_removed
    open_card_explorer_for(@project, @planning_tree)
    add_new_filter_for_explorer
    set_the_filter_property_and_value(1, :property => TYPE, :value => STORY)
    assert_explorer_results_message("Showing 1 result.")
    assert_card_present_in_explorer_filter_results(@story1)
    assert_card_not_present_in_explorer_filter_results(@iteration1)
    assert_card_not_present_in_explorer_filter_results(@iteration2)
    assert_card_not_present_in_explorer_filter_results(@release1)
    assert_card_not_present_in_explorer_filter_results(@release2)

    add_new_filter_for_explorer
    set_the_filter_property_and_value(2, :property => STATUS, :value => NEW)
    assert_explorer_results_message("Your filter did not match any cards for the current tree.") # bug 3483
    assert_card_not_present_in_explorer_filter_results(@story1)
    assert_card_not_present_in_explorer_filter_results(@iteration1)
    assert_card_not_present_in_explorer_filter_results(@iteration2)
    assert_card_not_present_in_explorer_filter_results(@release1)
    assert_card_not_present_in_explorer_filter_results(@release2)

    remove_a_filter_set(2)
    assert_filter_not_present_for(2)
    assert_explorer_results_message("Showing 1 result.")
    assert_card_present_in_explorer_filter_results(@story1)
    assert_card_not_present_in_explorer_filter_results(@iteration1)
    assert_card_not_present_in_explorer_filter_results(@iteration2)
    assert_card_not_present_in_explorer_filter_results(@release1)
    assert_card_not_present_in_explorer_filter_results(@release2)

    remove_a_filter_set(1)
    assert_filter_not_present_for(1)
    assert_explorer_results_message("Showing 5 results.")
    assert_card_present_in_explorer_filter_results(@story1)
    assert_card_present_in_explorer_filter_results(@iteration1)
    assert_card_present_in_explorer_filter_results(@iteration2)
    assert_card_present_in_explorer_filter_results(@release1)
    assert_card_present_in_explorer_filter_results(@release2)
  end

  def test_type_does_not_have_not_set_as_a_option
    open_card_explorer_for(@project, @planning_tree)
    assert_filter_value_not_present_on(0, :property_values => [NOT_SET])
    add_new_filter_for_explorer
    set_the_filter_property_option(1, TYPE)
    assert_filter_value_not_present_on(1, :property_values => [NOT_SET])
  end

  def test_can_filter_by_more_than_one_type
    open_card_explorer_for(@project, @planning_tree)
    set_the_filter_value_option(0, ITERATION)
    assert_explorer_results_message("Showing 2 results")
    assert_card_present_in_explorer_filter_results(@iteration1)
    assert_card_present_in_explorer_filter_results(@iteration2)
    assert_card_not_present_in_explorer_filter_results(@story1)
    assert_card_not_present_in_explorer_filter_results(@release1)
    assert_card_not_present_in_explorer_filter_results(@release2)
    add_new_filter_for_explorer
    set_the_filter_property_and_value(1, :property => TYPE, :value => STORY)
    assert_explorer_results_message("Showing 3 results")
    assert_card_present_in_explorer_filter_results(@iteration1)
    assert_card_present_in_explorer_filter_results(@iteration2)
    assert_card_present_in_explorer_filter_results(@story1)
    assert_card_not_present_in_explorer_filter_results(@release1)
    assert_card_not_present_in_explorer_filter_results(@release2)
  end

  def test_cards_already_in_tree_appear_in_filter_results_but_are_not_enabled
    open_card_explorer_for(@project, @planning_tree)
    assert_card_present_in_explorer_filter_results(@release1)
    assert_card_disabled_in_card_explorer_filter_results(@release1)
  end

  def test_can_select_all_does_not_select_card_that_is_already_in_tree_but_present_in_filter_results
    open_card_explorer_for(@project, @planning_tree)
    select_all
    assert_card_not_selected_in_explorer(@release1)
    assert_card_disabled_in_card_explorer_filter_results(@release1)
    assert_card_selected_in_explorer(@release2)
    assert_card_selected_in_explorer(@iteration1)
    assert_card_selected_in_explorer(@iteration2)

    select_none
    assert_card_not_selected_in_explorer(@release1)
    assert_card_disabled_in_card_explorer_filter_results(@release1)
    assert_card_not_selected_in_explorer(@release2)
    assert_card_not_selected_in_explorer(@iteration1)
    assert_card_not_selected_in_explorer(@iteration2)
  end

  def test_only_global_properties_displayed_for_filter_property_options_when_type_is_set_to_any
    open_card_explorer_for(@project, @planning_tree)
    add_new_filter_for_explorer
    assert_filter_property_present_on(1, :properties => [TYPE])
    assert_filter_property_not_present_on(1, :properties => [STATUS, RELATIONSHIP_ITERATION, RELATIONSHIP_RELEASE])
  end

  def test_filtering_by_type_shows_global_relationship_properties
    open_card_explorer_for(@project, @planning_tree)
    set_the_filter_value_option(0, STORY)
    add_new_filter_for_explorer
    assert_filter_property_present_on(1, :properties => [RELATIONSHIP_RELEASE, RELATIONSHIP_ITERATION])

    set_the_filter_property_and_value(1, :property => TYPE, :value => ITERATION)
    add_new_filter_for_explorer
    assert_filter_property_present_on(2, :properties => [RELATIONSHIP_RELEASE])
    assert_filter_property_not_present_on(2, :properties => [RELATIONSHIP_ITERATION])
  end

  def test_value_for_relationship_properties_in_filters_can_only_be_cards_that_are_already_in_the_tree
    open_card_explorer_for(@project, @planning_tree)
    set_the_filter_value_option(0, ITERATION)
    add_new_filter_for_explorer
    set_the_filter_property_option(1, RELATIONSHIP_RELEASE)
    open_filter_values_widget_for_relationship_property(1)

    @browser.assert_element_present(card_selector_result_locator(:filter, @release1.number))
    [@release2, @iteration1, @iteration2, @story1].each do |card|
      @browser.assert_element_not_present(card_selector_result_locator(:filter, card.number))
    end
  end

  # bug 3483
  def test_explorer_gives_no_cards_in_project_message_when_project_has_no_cards
    project_with_out_cards = create_project(:prefix => 'has_no_cards', :users => [@non_admin_user], :admins => [@project_admin_user])
    story = setup_card_type(project_with_out_cards, STORY)
    iteration = setup_card_type(project_with_out_cards, ITERATION)
    tree = setup_tree(project_with_out_cards, 'tree', :types => [iteration, story], :relationship_names => [RELATIONSHIP_ITERATION])
    open_card_explorer_for(project_with_out_cards, tree)
    assert_explorer_results_message("There are no cards in this project.")
    assert_explorer_refresh_link_is_present
  end
end
