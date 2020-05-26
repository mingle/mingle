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

#Tags: tree-usage, tree-filters
class Scenario97FilterOnTreeViewTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  PRIORITY = 'riority'
  STATUS = 'status'
  SIZE = 'size'
  ITERATION = 'iteration'
  OWNER = 'Zowner'

  RELEASE = 'Release'
  ITERATION_TYPE = 'Iteration'
  STORY = 'Story'
  DEFECT = 'Defect'
  TASK = 'Task'
  CARD = 'Card'

  NOTSET = '(not set)'
  ANY = '(any)'
  TYPE = 'Type'
  NEW = 'new'
  OPEN = 'open'
  LOW = 'low'
  HIGH = 'high'

  PLANNING = 'Planning'
  NONE = 'None'

  RELATION_PLANNING_RELEASE = 'Planning tree - release'
  RELATION_PLANNING_ITERATION = 'Planning tree - iteration'
  RELATION_PLANNING_STORY = 'Planning tree - story'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_admin_user = users(:longbob)
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_97', :users => [@non_admin_user], :admins => [@project_admin_user, users(:admin)])
    setup_property_definitions(PRIORITY => [HIGH, LOW], SIZE => [1, 2, 4], STATUS => [NEW,  'close', OPEN], ITERATION => [1,2,3,4], OWNER  => ['a', 'b', 'c'])
    @type_story = setup_card_type(@project, STORY, :properties => [PRIORITY, SIZE, ITERATION, OWNER])
    @type_defect = setup_card_type(@project, DEFECT, :properties => [PRIORITY, STATUS, OWNER])
    @type_task = setup_card_type(@project, TASK, :properties => [PRIORITY, SIZE, ITERATION, STATUS, OWNER])
    @type_iteration = setup_card_type(@project, ITERATION_TYPE)
    @type_release = setup_card_type(@project, RELEASE)
    login_as_admin_user
    @r1 = create_card!(:name => 'release 1', :description => "Without software, most organizations could not survive in the current marketplace see bug100", :card_type => RELEASE)
    @r2 = create_card!(:name => 'release 2', :card_type => RELEASE)
    @i1 = create_card!(:name => 'iteration 1', :card_type => ITERATION_TYPE)
    @i2 = create_card!(:name => 'iteration 2', :card_type => ITERATION_TYPE)
    @stories = create_cards(@project, 5, :card_type => @type_story)
    @tasks = create_cards(@project, 2, :card_type => @type_task)
    @tree = setup_tree(@project, 'planning tree', :types => [@type_release, @type_iteration, @type_story, @type_task],
      :relationship_names => [RELATION_PLANNING_RELEASE, RELATION_PLANNING_ITERATION, RELATION_PLANNING_STORY])
    navigate_to_card_list_for(@project)
  end

  def test_property_tooltip_when_filter_cards_on_tree
    edit_property_definition_for(@project,PRIORITY,:description => "this property indicates priority of the each card.")
    edit_property_definition_for(@project,SIZE,:description => "this property indicates the size of the card.")
    get_planning_tree_generated_with_cards_on_tree

    navigate_to_tree_view_for(@project, @tree.name)
    set_tree_filter_for(@type_story, 0, :property => PRIORITY, :value => HIGH)
    assert_property_tooltip_on_tree_filter_panel(STORY,0,PRIORITY)
    set_tree_filter_for(@type_task, 0, :property => SIZE, :value => "4")
    assert_property_tooltip_on_tree_filter_panel(TASK,0,SIZE)

    navigate_to_hierarchy_view_for(@project, @tree)
    set_tree_filter_for(@type_release, 0, :property => RELATION_PLANNING_RELEASE, :value => NOTSET)
    assert_property_tooltip_on_tree_filter_panel(RELEASE,0,RELATION_PLANNING_RELEASE)
    set_tree_filter_for(@type_iteration, 0, :property => RELATION_PLANNING_ITERATION, :value => NOTSET)
    assert_property_tooltip_on_tree_filter_panel(ITERATION,0,RELATION_PLANNING_ITERATION)
  end

  def test_tree_view_get_filtered_on_relationship_properties
    get_planning_tree_generated_with_cards_on_tree
    navigate_to_tree_view_for(@project, @tree.name)
    set_tree_filter_for(@type_story, 0, :property => RELATION_PLANNING_STORY, :value => @stories[1].number)
    assert_cards_on_a_tree(@project, @stories[1], @tasks[0], @tasks[1])
    assert_card_not_present_on_tree(@stories[0], @stories[2])
    set_tree_filter_for(@type_iteration, 0, :property => RELATION_PLANNING_ITERATION, :value => NOTSET)
    assert_cards_on_a_tree(@project, @r1)
    assert_card_not_present_on_tree(@stories[1], @tasks[0], @tasks[1])
  end

  def test_removing_filter_set_will_repopulate_cards_on_tree
    get_planning_tree_generated_with_cards_on_tree
    navigate_to_tree_view_for(@project, @tree.name)
    set_tree_filter_for(@type_story, 0, :property => RELATION_PLANNING_STORY, :value => @stories[1].number, :wait => true)
    assert_cards_on_a_tree(@project, @stories[1], @tasks[0], @tasks[1])
    assert_card_not_present_on_tree(@stories[0], @stories[2])
    remove_filter_set(@type_story, 0, :wait => false)
    assert_cards_on_a_tree(@stories[0], @stories[2])
  end

  def test_tree_filters_are_ORing_and_does_not_AND_between_types
    add_card_to_tree(@tree, @r1)
    add_card_to_tree(@tree, [@i1, @i2] ,@r1)
    add_card_to_tree(@tree, @stories[0], @i1)
    add_card_to_tree(@tree, @stories[1], @i2)
    navigate_to_tree_view_for(@project, @tree.name)
    set_tree_filter_for(@type_release, 0, :property => RELATION_PLANNING_RELEASE, :value => @r1.number)
    set_tree_filter_for(@type_iteration, 0, :property => RELATION_PLANNING_ITERATION, :value => @i1.number)
    set_tree_filter_for(@type_iteration, 1, :property => RELATION_PLANNING_ITERATION, :value => @i2.number)
    assert_cards_on_a_tree(@project, @stories[0], @stories[1])
  end

  def test_exlude_card_type_will_not_display_card_on_tree_on_quick_add
    add_card_to_tree(@tree, @r1)
    add_card_to_tree(@tree, [@i1, @i2] ,@r1)
    navigate_to_tree_view_for(@project, @tree.name)
    click_exclude_card_type_checkbox(@type_iteration)
    quick_add_cards_on_tree(@project, @tree, @r1, :card_names => ['Iteration invisible'], :reset_filter => 'no')
    assert_notice_message("1 card was created successfully.")
    @browser.assert_text_not_present('Iteration invisible')
  end

  def test_filter_will_retain_its_sticky_state_when_switched_between_tabs_and_trees
    add_card_to_tree(@tree, @r1)
    add_card_to_tree(@tree, [@i1, @i2] ,@r1)
    navigate_to_tree_view_for(@project, @tree.name)
    set_tree_filter_for(@type_iteration, 0, :property => RELATION_PLANNING_ITERATION, :value => @i2.number, :wait => true)
    click_exclude_card_type_checkbox(@type_release)

    # tab change...
    click_history_tab
    assert_tab_highlighted('History')
    click_all_tab
    assert_card_type_excluded(@type_release)
    assert_properties_present_on_card_tree_filter(@type_iteration, 0, RELATION_PLANNING_ITERATION => card_number_and_name(@i2))

    # checking filter state on tree change
    select_tree('none')
    @browser.assert_element_not_present('tree_filter')

    select_tree(@tree.name)
    assert_card_type_excluded(@type_release)
    assert_properties_present_on_card_tree_filter(@type_iteration, 0, RELATION_PLANNING_ITERATION => card_number_and_name(@i2))

    # reset to tab defaults...
    reset_view
    click_history_tab
    assert_tab_highlighted('History')
    click_all_tab
    assert_reset_to_tab_default_link_not_present
  end

  # bug 3994
  def test_filter_will_not_be_reset_after_running_transition_on_card_popup

    transition = create_transition(@project, 'make new', :set_properties => {:status => NEW})

    add_cards_to_tree(@tree, :root, @r1, [@i1], @r2, [@i2])
    navigate_to_tree_view_for(@project, @tree.name)
    set_tree_filter_for(@type_release, 0, :property => RELATION_PLANNING_RELEASE, :value => @r1.number, :wait => true)
    assert_cards_showing_on_tree(@r1, @i1)
    assert_cards_not_showing_on_tree(@r2, @i2)

    click_on_card_in_tree(@i1)
    click_transition_link_on_card(transition)
    assert_cards_showing_on_tree(@r1, @i1)
    assert_cards_not_showing_on_tree(@r2, @i2)
  end

  # bug 4193
  def test_filtering_tree_by_deleted_property_value_does_not_cause_we_are_sorry_page
    priority_property = @project.find_property_definition(PRIORITY)
    @type_release.add_property_definition(priority_property)
    navigate_to_tree_view_for(@project, @tree.name)
    set_tree_filter_for(@type_release, 0, :property => PRIORITY, :value => HIGH)
    delete_enumeration_value_for(@project, PRIORITY, HIGH)
    click_all_tab
    assert_error_message("Filter is invalid. Property #{PRIORITY} contains invalid value #{HIGH}")
  end

  # bug 4195
  def test_filtering_tree_by_disassociated_plv_does_not_cause_we_are_sorry_page
    priority_property = @project.find_property_definition(PRIORITY)
    @type_release.add_property_definition(priority_property)
    current_priority = create_project_variable(@project, :name => 'current priority', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => HIGH, :properties => [PRIORITY])

    navigate_to_tree_view_for(@project, @tree.name)
    set_tree_filter_for(@type_release, 0, :property => PRIORITY, :value => '(current priority)')

    open_project_variable_for_edit(@project, current_priority)
    uncheck_properties_that_will_use_variable(@project, PRIORITY)
    click_save_project_variable

    click_all_tab
    assert_error_message("Filter is invalid. Project variable \\(current priority\\) is not valid for the property #{PRIORITY}.")
  end

  # Bug 6924
  def test_renaming_relationship_property_and_returning_to_tab_using_that_relationship_property_gives_500
    get_planning_tree_generated_with_cards_on_tree
    navigate_to_card_list_by_clicking(@project)
    switch_to_grid_view
    select_tree(@tree.name)
    set_tree_filter_for(@type_iteration, 0, :property => RELATION_PLANNING_ITERATION, :value => @i1.number)
    update_tab_with_current_view('I am favorite')
    rename_relationship_property(@project, @tree, RELATION_PLANNING_ITERATION, 'planning tree new iteration name')
    click_all_tab
    assert_error_message("Filter is invalid. Property Planning tree - iteration does not exist.")
  end

  def click_up_to_all_link
    @browser.click_and_wait('link=Up to All')
  end

  def get_planning_tree_generated_with_cards_on_tree
    add_card_to_tree(@tree, @r1)
    add_card_to_tree(@tree, @i1, @r1)
    add_card_to_tree(@tree, @stories, @i1)
    add_card_to_tree(@tree, @tasks, @stories[1])
  end
end
