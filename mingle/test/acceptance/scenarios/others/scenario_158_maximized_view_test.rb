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

#Tags: maximized_view, gridview, cardlist, tree_view

class Scenario158MaximizedViewTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  MANAGED_TEXT_TYPE = "Managed text list"
  FREE_TEXT_TYPE = "Allow any text"
  MANAGED_NUMBER_TYPE = "Managed number list"
  FREE_NUMBER_TYPE = "Allow any number"
  USER_TYPE = "team"
  DATE_TYPE = "date"
  CARD_TYPE = "card"

  MANAGED_TEXT = 'managed text'
  FREE_TEXT = 'free_text'
  MANAGED_NUMBER = 'managed number'
  FREE_NUMBER = 'free_number'
  USER = 'user'
  DATE = 'date'
  RELATED_CARD = 'related_card'

  RELEASE = 'Release'
  ITERATION = 'Iteration'
  STORY = 'Story'
  TASK = 'Task'

  RED = "rgb(212, 41, 43)"

  TRANSITION_ONLY = "transition_only"

  PLANNING_TREE = "planning_tree"
  RELEASE_ITERATION = "release-iteration"
  ITERATION_TASK = "iteration-task"
  TASK_STORY = "task-story"

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin = users(:proj_admin)
    @project_member = users(:project_member)
    @read_only_user = users(:read_only_user)
    login_as_proj_admin_user
    @project = create_project(:prefix => 'scenario_158', :admins => [users(:proj_admin)], :users => [users(:project_member)], :read_only_users => [users(:read_only_user)])
    add_properties_for_project(@project)
    add_card_types_for_project(@project)
    add_cards_of_different_card_types_for_project(@project)
    add_tree_and_card_for_project(@project)
  end

  def teardown
    super
    clear_user_display_preferences
  end

  def test_changing_pagination_and_refreshing_page_should_not_loose_maxmize_view_mode
    create_cards(@project,50)
    user_is_on_maximized_list_view

    @browser.click_and_wait('link=Next')
    user_is_still_on_maximized_view

    @browser.click_and_wait('link=3')
    user_is_still_on_maximized_view

    @browser.click_and_wait('link=Previous')
    user_is_still_on_maximized_view

    reload_current_page
    user_is_still_on_maximized_view
  end

  def test_clicking_refresh_link_should_not_loose_maximum_view_mode
    user_is_on_maximized_grid_view(@project)
    filter_cards_on_maximized_view_with_mql("type is null")

    click_on_reset_filter_link
    user_is_still_on_maximized_view
  end

  def test_can_not_create_tab_from_a_fav_saved_in_maxmized_view
    user_is_on_maximized_grid_view(@project)
    ensure_sidebar_open
    create_card_list_view_for(@project,"test",:skip_clicking_all => true)

    navigate_to_favorites_management_page_for(@project)
    assert_can_not_make_tab_from_maximized_favorite("test")
  end

  def test_user_should_be_able_to_save_maximize_view_mode_as_personal_favorite
    Outline(<<-Examples, :skip_setup => true) do |create_favorite,                                  open_favorite |
      |{save_current_view_as_my_favorite("test_fav")}                              |{open_my_favorite("test_fav")}|
      |{create_card_list_view_for(@project,"test_view",:skip_clicking_all => true)}|{open_saved_view("test_view")}|
      Examples

      user_is_on_maximized_grid_view(@project)
      ensure_sidebar_open
      create_favorite.happened

      navigate_to_card_list_for(@project)
      open_favorite.happened
      user_is_still_on_maximized_view
    end
  end

  def test_user_should_be_able_to_maximise_and_restore_view
    Outline(<<-Examples, :skip_setup => true) do |navigate_to_different_view |
      |{navigate_to_card_list_for(@project)}|
      |{navigate_to_grid_view_for(@project)}|
      |{navigate_to_tree_view_for(@project, @planning_tree.name)}|
      |{navigate_to_hierarchy_view_for(@project, @planning_tree)}|
      Examples
      navigate_to_different_view.happened
      assert_maximise_view_link_present
      maximize_current_view
      assert_restore_view_link_present_on_the_action_bar
    end
  end

  def test_readonly_user_should_be_able_to_maximise_and_restore_view
    Outline(<<-Examples, :skip_setup => true) do |navigate_to_different_view |
      |{navigate_to_card_list_for(@project)}|
      |{navigate_to_grid_view_for(@project)}|
      |{navigate_to_tree_view_for(@project, @planning_tree.name)}|
      |{navigate_to_hierarchy_view_for(@project, @planning_tree)}|
      Examples
      login_as_read_only_user
      navigate_to_different_view.happened
      assert_maximise_view_link_present
      maximize_current_view
      assert_restore_view_link_present_on_the_action_bar
    end
  end

  def test_user_should_not_see_irrelevant_element_on_maximized_view
    Outline(<<-Examples, :skip_setup => true) do |navigate_to_different_view, assert_irrelevant_element_not_present |
      |{navigate_to_card_list_for(@project)}|{assert_irrelevant_element_not_present_on_maximized_list_view}|
      |{navigate_to_grid_view_for(@project)}|{assert_irrelevant_element_not_present_on_maximized_grid_view}|
      |{navigate_to_tree_view_for(@project, @planning_tree.name)}|{assert_irrelevant_element_not_present_on_maximized_tree_view}|
      |{navigate_to_hierarchy_view_for(@project, @planning_tree)}|{assert_irrelevant_element_not_present_on_maximized_hierarchy_view}|
      Examples
      navigate_to_different_view.happened
      maximize_current_view
      assert_irrelevant_element_not_present.happened
      assert_side_bar_collapsed
    end
  end

  def test_side_bar_should_remember_user_preference_expanded
    navigate_to_card_list_for(@project)
    ensure_sidebar_open
    collapse_the_side_bar_on_maximized_view
    restore_current_view
    assert_side_bar_expanded

    ensure_sidebar_closed
    expand_the_side_bar_on_maximized_view
    restore_current_view
    assert_side_bar_collapsed
  end

  # maximized list view
  def test_user_should_be_able_to_add_collumns_and_sort_on_maximized_list_view
    user_is_on_maximized_list_view
    user_added_one_collumn_and_sort_by_it
    user_should_get_correct_sorted_result
    user_is_still_on_maximized_view
  end

  def test_user_should_be_albe_to_use_filter_on_maximized_list_view
    Outline(<<-Examples, :skip_setup => true) do |different_ways_to_filter_cards_on_maximized_view|
      |{filter_cards_on_maximized_view}|
      |{filter_cards_on_maximized_view_with_mql("type = story")}|
      Examples
      user_is_on_maximized_list_view
      different_ways_to_filter_cards_on_maximized_view.happened
      user_should_get_correct_filtered_results
      user_is_still_on_maximized_view
    end
  end

  # maximized grid view
  def test_user_should_be_able_to_rank_on_maximized_grid_view
    does_not_work_on_ie do
      user_is_on_maximized_grid_view(@project)
      drag_and_drop_card_to(@release_2, @iteration_1)
      assert_ordered("card_#{@iteration_1.number}", "card_#{@release_2.number}")
      user_is_still_on_maximized_view
    end
  end

  def test_user_should_be_able_to_user_filters_on_grid_view
    Outline(<<-Examples, :skip_setup => true) do |different_ways_to_filter_cards_on_maximized_view|
      |{filter_cards_on_maximized_view}|
      |{filter_cards_on_maximized_view_with_mql("type = story")}|
      Examples
      user_is_on_maximized_grid_view(@project)
      different_ways_to_filter_cards_on_maximized_view.happened
      user_should_get_correct_filtered_results
      user_is_still_on_maximized_view
    end
  end

  def test_escape_key_should_minimize_view
    if !using_google_chrome?
      user_is_on_maximized_grid_view(@project)
      press_escape_key_and_wait
      assert_maximise_view_link_present
    end
  end

  # bug 8275
  def test_escape_key_should_not_collapse_sidebar_on_non_maximized_view
    navigate_to_grid_view_for(@project)
    ensure_sidebar_open
    assert_side_bar_expanded
    press_escape_key
    assert_side_bar_expanded
  end

  # tree-related
  def test_user_should_be_able_to_use_tree_filter_on_maximized_view
    Outline(<<-Examples) do |user_is_on_different_maximized_view, user_should_get_correct_result|
      |{user_is_on_maximized_list_view_with_tree}|{user_should_get_correct_filtered_list_view}|
      |{user_is_on_maximized_grid_view_with_tree}|{user_should_get_correct_filtered_grid_view}|
      |{user_is_on_maximized_hierarchy_view}|{user_should_get_correct_filtered_list_view}|
      |{user_is_on_maximized_tree_view}|{user_should_get_correct_filtered_tree_view}|
      Examples
      user_have_more_cards_on_tree
      user_is_on_different_maximized_view.happened
      filter_cards_on_maximized_view_using_tree_filter
      user_should_get_correct_result.happened
      user_is_still_on_maximized_view
    end
  end

  def test_user_should_be_able_to_add_lane_and_sort_on_maximized_hierarchy_view
    user_have_more_cards_on_tree
    user_is_on_maximized_hierarchy_view
    user_expand_nodes_added_one_collumn_and_sort_by_it
    user_should_get_correct_sorted_result
    user_is_still_on_maximized_view
  end

  def test_user_should_be_able_to_expand_collapse_nodes_on_maximized_tree_view
    user_is_on_maximized_tree_view
    expand_collapse_nodes_in_tree_view(@release_1)
    assert_nodes_expanded_in_tree_view(@release_1)
    expand_collapse_nodes_in_tree_view(@release_1)
    assert_nodes_collapsed_in_tree_view(@release_1)
    user_is_still_on_maximized_view
  end

  def test_user_should_be_able_to_DND_cards_on_tree_on_maximized_view
    navigate_to_tree_view_for(@project, @planning_tree.name)
    maximize_current_view
    drag_and_drop_card_in_tree(@release_1, @story_1)
    assert_parent_node(@release_1, @story_1)
    user_is_still_on_maximized_view
  end

  def test_user_should_be_able_to_quick_add_cards_on_maximized_view
    user_is_on_maximized_tree_view
    quick_add_cards_on_tree(@project, @planning_tree, :root, :card_names => ['quick_added'], :type => @type_story.name, :reset_filter => 'no')
    assert_notice_message("1 card was created successfully.")
    user_is_still_on_maximized_view
  end

  def test_user_should_be_able_to_remove_cards_on_maximized_view
    navigate_to_tree_view_for(@project, @planning_tree.name)
    maximize_current_view
    click_remove_link_for_card(@story_1)
    assert_card_not_in_tree(@project, @planning_tree, @story_1)
    user_is_still_on_maximized_view
  end

  #bug #8770 The pagination got lost after exit maximum view mode
  def test_should_stay_on_the_same_page_of_maxmized_view
    create_cards(@project, 26)
    navigate_to_card_list_for(@project)
    click_page_link(2)
    maximize_current_view
    current_page_number_should_be(2)
  end

  #bug #8769
  def test_should_not_be_able_to_update_tab_with_maximized_view_favorite
    create_tabbed_view("testing", @project)
    user_is_on_maximized_grid_view(@project)
    ensure_sidebar_open
    update_tab_with_current_view("testing")
    assert_error_message("Validation failed: Maximized views cannot be saved as tabs")
  end

  #bug #8685
  def test_maximizing_favorite_should_not_loose_filter_and_columns
    navigate_to_card_list_for(@project)
    set_the_filter_value_option(0, 'Card')
    select_is_not(0)
    add_column_for(@project, ["Type", "Created by","Modified by"])
    create_card_list_view_for(@project,"test",:skip_clicking_all => true)

    navigate_to_card_list_for(@project)
    open_saved_view("test")
    maximize_current_view
    assert_column_present_for("Type","Created by","Modified by")
    assert_selected_value_for_the_filter(0, "Card")
    assert_filter_operator_set_to(0,"is not")
  end

  def test_should_not_show_grid_settings_button_on_maxmized_view
    navigate_to_grid_view_for(@project)
    maximize_current_view
    assert_show_hide_grid_settings_button_is_not_present
  end

  private
  def add_properties_for_project(project)
    project.activate
    create_property_for_card(MANAGED_TEXT_TYPE, MANAGED_TEXT)
    create_property_for_card(FREE_TEXT_TYPE, FREE_TEXT)
    create_property_for_card(MANAGED_NUMBER_TYPE, MANAGED_NUMBER)
    create_property_for_card(FREE_NUMBER_TYPE, FREE_NUMBER)
    create_property_for_card(USER_TYPE, USER)
    create_property_for_card(DATE_TYPE, DATE)
    create_property_for_card(CARD_TYPE, RELATED_CARD)
    @transition_only = create_property_for_card(MANAGED_NUMBER_TYPE, TRANSITION_ONLY)
    @transition_only.update_attribute(:transition_only, true)
  end

  def add_card_types_for_project(project)
    @type_release = setup_card_type(project, RELEASE, :properties => [MANAGED_NUMBER, MANAGED_TEXT, FREE_NUMBER, FREE_TEXT, DATE, RELATED_CARD, USER, TRANSITION_ONLY])
    @type_iteration = setup_card_type(project, ITERATION, :properties => [MANAGED_NUMBER, MANAGED_TEXT, FREE_NUMBER, FREE_TEXT, DATE, RELATED_CARD, USER, TRANSITION_ONLY])
    @type_task = setup_card_type(project, TASK, :properties => [MANAGED_NUMBER, MANAGED_TEXT, FREE_NUMBER, FREE_TEXT, DATE, RELATED_CARD, USER, TRANSITION_ONLY])
    @type_story = setup_card_type(project, STORY, :properties => [MANAGED_NUMBER, MANAGED_TEXT, FREE_NUMBER, FREE_TEXT, DATE, RELATED_CARD, USER, TRANSITION_ONLY])
  end

  def add_cards_of_different_card_types_for_project(project)
    project.activate
    @release_1 = create_card!(:name => 'release 1', :card_type => RELEASE, MANAGED_NUMBER => 1, FREE_TEXT => 'a', RELATED_CARD => nil, USER => users(:project_member).id)
    @release_2 = create_card!(:name => 'release 2', :card_type => RELEASE, MANAGED_NUMBER => 1, FREE_TEXT => 'a', RELATED_CARD => @release_1, USER => users(:project_member).id)
    @iteration_1 = create_card!(:name => 'iteration 1', :card_type => ITERATION, MANAGED_NUMBER => 2, FREE_TEXT => 'b', USER => users(:project_member).id)
    @iteration_2 = create_card!(:name => 'iteration 2', :card_type => ITERATION, MANAGED_NUMBER => 2, FREE_TEXT => 'b', USER => users(:project_member).id)
    @story_1 = create_card!(:name => 'story 1', :card_type => STORY, MANAGED_NUMBER => 3, FREE_TEXT => 'c', USER => users(:read_only_user).id)
    @story_2 = create_card!(:name => 'story 2', :card_type => STORY, MANAGED_NUMBER => 3, FREE_TEXT => 'c', USER => users(:read_only_user).id)
    @tasks_1 = create_card!(:name => 'task 1', :card_type => TASK, MANAGED_NUMBER => 4, FREE_TEXT => 'd', USER => users(:read_only_user).id)
    @tasks_2 = create_card!(:name => 'task 2', :card_type => TASK, MANAGED_NUMBER => 4, FREE_TEXT => 'd', USER => users(:read_only_user).id)
    @special_card = project.cards.create!(:name => 'xyz', :card_type => @type_story, :cp_related_card => @release_1, :cp_free_text => "abcdefg")
  end

  def add_tree_and_card_for_project(project)
    @planning_tree = setup_tree(project, PLANNING_TREE, :types => [@type_release, @type_iteration, @type_story, @type_task], :relationship_names => [RELEASE_ITERATION, ITERATION_TASK, TASK_STORY])
    add_card_to_tree(@planning_tree, @release_1)
    add_card_to_tree(@planning_tree, @iteration_1, @release_1)
    add_card_to_tree(@planning_tree, @story_1, @iteration_1)
  end

  def user_is_on_maximized_grid_view(project)
    navigate_to_grid_view_for(project, :color_by => 'Type')
    maximize_current_view
    @browser.wait_for_all_ajax_finished
  end

  def user_is_on_maximized_list_view
    navigate_to_card_list_for(@project)
    maximize_current_view
  end


  def user_is_on_maximized_hierarchy_view
    navigate_to_hierarchy_view_for(@project, @planning_tree)
    maximize_current_view
  end

  def user_is_on_maximized_tree_view
    navigate_to_card_list_for(@project)
    select_tree(@planning_tree.name)
    switch_to_tree_view
    maximize_current_view
  end

  def user_is_on_maximized_list_view_with_tree
    navigate_to_tree_view_for(@project, @planning_tree.name)
    switch_to_list_view
    maximize_current_view
  end

  def user_is_on_maximized_grid_view_with_tree
    navigate_to_tree_view_for(@project, @planning_tree.name)
    switch_to_grid_view
    maximize_current_view
  end

  def user_should_get_correct_filtered_results
     assert_cards_present(@story_1, @story_2)
     assert_cards_not_present(@release_1, @release_2, @iteration_1, @iteration_2, @tasks_1, @tasks_2)
   end

   def press_escape_key
     @browser.key_down("dom=document.body", Keycode::ESC)
   end

   def press_escape_key_and_wait
     press_escape_key
     @browser.wait_for_page_to_load
   end

   # no tree
   def user_should_get_correct_filtered_list_view
     assert_cards_present_in_list(@story_1)
     assert_cards_not_present_in_list(@release_1, @release_2, @iteration_1, @iteration_2, @tasks_1, @tasks_2, @story_2)
   end

   def user_should_get_correct_filtered_grid_view
     assert_cards_present_in_grid_view(@story_1)
     assert_cards_not_present_in_grid_view(@release_1, @release_2, @iteration_1, @iteration_2, @tasks_1, @tasks_2, @story_2)
   end

   ## list view
   def user_added_one_collumn_and_sort_by_it
     add_column_for(@project, %w(Type))
     click_card_list_column_and_wait("Type")
   end

   def user_should_get_correct_sorted_result
     cards = HtmlTable.new(@browser, 'cards', ['number', 'name', 'Type'], 1, 1)
     cards.assert_ascending("Type")
   end

   ## grid view
   def change_color_in_color_legend_on_side_bar
     @browser.click("collapsible-header-for-Color-legend")
     change_color(@type_story, RED)
   end

   def color_on_mini_card_should_changed
     assert_card_color(RED, @story_1.number)
     assert_card_color(RED, @story_2.number)
   end

   def user_has_a_user_required_transition(project)
     @transition = create_transition_for(project, 'new transition',:type => "Story", :set_properties => {'managed text' => 'very high'}, :require_comment => true)
   end

   def user_trigger_the_transtion_on_maximized_view(story,transition)
     click_on_transition_for_card_in_grid_view(story, transition)
     add_comment_for_transition_to_complete_text_area('comment from here')
     click_on_complete_transition
   end

   def filter_cards_on_maximized_view
     @browser.click('sidebar-control')
     set_the_filter_value_option(0, 'Story')
   end

   def filter_cards_on_maximized_view_with_mql(condition)
     @browser.click('sidebar-control')
     set_mql_filter_for(condition)
   end

   def user_have_more_cards_on_tree
     add_card_to_tree(@planning_tree, @story_2)
   end

   def user_expand_nodes_added_one_collumn_and_sort_by_it
     click_twisty_for(@release_1, @iteration_1)
     user_added_one_collumn_and_sort_by_it
   end

   def user_should_get_correct_filtered_tree_view
     assert_cards_on_a_tree(@project, @story_1)
     assert_card_not_present_on_tree(@project, @release_1, @release_2, @iteration_1, @iteration_2, @tasks_1, @tasks_2, @story_2)
   end

   def filter_cards_on_maximized_view_using_tree_filter
     @browser.click('sidebar-control')
     click_exclude_card_type_checkbox(@type_release, @type_iteration)
     add_new_tree_filter_for(@type_release)
     set_the_tree_filter_property_option(@type_release, 0, RELEASE_ITERATION)
     set_the_tree_filter_value_option_to_card_number(@type_release, 0, @release_1.number)
   end

   def user_is_still_on_maximized_view
     assert_restore_view_link_present_on_the_action_bar
     assert_maximise_view_link_not_present
   end

   # irrelevant element for maximized view
   def assert_irrelevant_element_not_present_on_maximized_hierarchy_view
     assert_maximized_view_should_not_have_navigation_tabs
     assert_maximized_view_should_not_have_card_action_bar
     @browser.assert_not_visible("css=table#cards tr.cards-header a.print")
     @browser.assert_visible("css=table#cards tr.cards-header a.link")
   end

   def assert_irrelevant_element_not_present_on_maximized_tree_view
     assert_maximized_view_should_not_have_navigation_tabs
     assert_maximized_view_should_not_have_card_action_bar
     @browser.assert_visible("css=#card_results .tree-actions a.link")
   end

   def assert_irrelevant_element_not_present_on_maximized_grid_view
     assert_maximized_view_should_not_have_navigation_tabs
     assert_maximized_view_should_not_have_card_action_bar
     @browser.assert_visible("css=#card_results .grid-actions a.link")
   end

   def assert_irrelevant_element_not_present_on_maximized_list_view
     assert_maximized_view_should_not_have_navigation_tabs
     assert_maximized_view_should_not_have_card_action_bar
     assert_maximized_view_should_not_have_action_buttons_on_list_header
     assert_maximized_view_should_not_have_card_checkbox_on_card_list
   end

   def assert_maximized_view_should_not_have_card_checkbox_on_card_list
     @browser.assert_not_visible("css=#card_results td.checkbox")
   end

   def assert_maximized_view_should_not_have_navigation_tabs
     @browser.assert_not_visible("css=#hd-nav li")
   end

   def assert_maximized_view_should_not_have_action_buttons_on_list_header
     @browser.assert_not_visible("css=table#cards tr.cards-header a.print")
     @browser.assert_visible("css=table#cards tr.cards-header a.link")
     @browser.assert_not_visible("css=table#cards tr.cards-header a#select_all")
     @browser.assert_not_visible("css=table#cards tr.cards-header a#select_none")
   end

   def assert_maximized_view_should_not_have_card_action_bar
     @browser.assert_not_visible("css=#card_list_view .action-bar")
   end

   def assert_can_not_make_tab_from_maximized_favorite(view_name)
     view = Project.current.reload.card_list_views.find_by_name(view_name)
     @browser.assert_element_not_present "move-to-tab-#{view.html_id}"
   end

end
