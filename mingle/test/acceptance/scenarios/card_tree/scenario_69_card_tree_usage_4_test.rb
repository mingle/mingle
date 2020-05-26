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
require File.expand_path(File.dirname(__FILE__) + '/card_tree_acceptance_support.rb')

#Tags: tree-view
class Scenario69CardTreeUsage4Test < ActiveSupport::TestCase

  include CardTreeAcceptanceSupport

  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_admin_user = users(:longbob)
    @member = users(:project_member)
    @project_admin_user = users(:proj_admin)
    admin = login_as_admin_user

    @project = with_new_project(:prefix => 'scenario_69', :users => [@non_admin_user, @member], :admins => [@project_admin_user, users(:admin)]) do |project|
      setup_property_definitions(PRIORITY => ['high', LOW], SIZE => [1, 2, 4], STATUS => [NEW, CLOSED, OPEN], ITERATION => [1, 2, 3, 4], OWNER => ['a', 'b', 'c'])
      @type_story = setup_card_type(project, STORY, :properties => [PRIORITY, SIZE, ITERATION, OWNER])
      @type_defect = setup_card_type(project, DEFECT, :properties => [PRIORITY, STATUS, OWNER])
      @type_task = setup_card_type(project, TASK, :properties => [PRIORITY, SIZE, ITERATION, STATUS, OWNER])
      @type_iteration = setup_card_type(project, ITERATION_TYPE)
      @type_release = setup_card_type(project, RELEASE)
      @r1 = create_card!(:name => 'release 1', :description => "Without software, most organizations could not survive in the current marketplace see bug100", :card_type => RELEASE)
      @r2 = create_card!(:name => 'release 2', :card_type => RELEASE)
      @i1 = create_card!(:name => 'iteration 1', :card_type => ITERATION_TYPE)
      @i2 = create_card!(:name => 'iteration 2', :card_type => ITERATION_TYPE)
      @stories = create_cards(project, 5, :card_type => @type_story)
      @tasks = create_cards(project, 2, :card_type => @type_task)
      @tree = setup_tree(project, 'planning tree', :types => [@type_release, @type_iteration, @type_story, @type_task], :relationship_names => [RELATION_PLANNING_RELEASE, RELATION_PLANNING_ITERATION, RELATION_PLANNING_STORY])
    end
    navigate_to_card_list_for(@project)
  end


  # bug 3408
  def test_reset_filter_link_will_clear_exclude_card_types_filters
    release_card, iteration_card, story_card = fill_one_branch_tree
    select_tree(@tree.name)
    switch_to_tree_view_through_action_bar

    click_exclude_card_type_checkbox(@type_release)
    click_exclude_card_type_checkbox(@type_iteration)
    click_exclude_card_type_checkbox(@type_story)

    @browser.wait_for_element_visible("node_0") #If the root node is visible, the tree is redrawn
    assert_no_cards_assigned_message(@tree)

    reset_filter_when_no_card_found
    expand_collapse_nodes_in_tree_view(release_card, iteration_card)
    assert_cards_showing_on_tree(release_card, iteration_card, story_card)
  end

  # bug 3360
  def test_link_to_this_page_maintains_filters
    release_card, story_card, iteration_card = fill_one_branch_tree
    select_tree(@tree.name)
    switch_to_tree_view_through_action_bar
    add_new_tree_filter_for(@type_iteration)
    set_tree_filter_for(@type_iteration, 0, :property => RELATION_PLANNING_ITERATION, :value => NOTSET)
    click_exclude_card_type_checkbox(STORY)
    click_exclude_card_type_checkbox(ITERATION_TYPE)
    @browser.wait_for_element_visible("node_0") #If the root node is visible, the tree is redrawn
    click_link_to_this_page
    assert_properties_present_on_card_tree_filter(@type_iteration, 0, RELATION_PLANNING_ITERATION => NOTSET)
    assert_card_type_excluded(STORY)
    assert_card_type_excluded(ITERATION_TYPE)
    assert_card_type_not_excluded(RELEASE)
  end

  # bug 3410
  def test_tree_selection_is_retained_when_navigating_back_to_dirty_all_tab
    click_all_tab
    select_tree(@tree.name)
    click_overview_tab
    click_all_tab
    assert_tree_selected(@tree.name)
  end

  # bug 4086
  def test_added_card_was_not_shown_message_appears_for_the_quick_add_case
    release_1 = create_card!(:name => 'release 1', :card_type => RELEASE)
    add_card_to_tree(@tree, release_1)

    select_tree(@tree.name)
    switch_to_tree_view_through_action_bar
    expand_collapse_nodes_in_tree_view(release_1)
    click_exclude_card_type_checkbox(ITERATION_TYPE)
    quick_add_cards_on_tree(@project, @tree, release_1, :card_names => ['new iteration'], :reset_filter => 'no', :card_type => ITERATION_TYPE)
    assert_info_message("1 card was added to ##{release_1.number} #{release_1.name}, but is not shown because it does not match the current filter.")
  end

  # bug 4094
  def test_drop_card_here_bubble_disappears_after_quick_adding
    change_license_to_allow_anonymous_access
    @project.update_attribute :anonymous_accessible, true
    some_tree = setup_tree(@project, 'some tree', :types => [@type_release, @type_story], :relationship_names => ['some tree - Release'])
    navigate_to_tree_view_for(@project, some_tree.name)
    assert_drop_card_here_bubble_is_showing

    logout
    navigate_to_tree_view_for(@project, some_tree.name)
    @browser.assert_element_not_present('no-children-hint')

    login_as_admin_user
    navigate_to_tree_view_for(@project, some_tree.name)
    quick_add_cards_on_tree(@project, some_tree, :root, :card_names => ['some card name'], :reset_filter => 'no')
    assert_drop_card_here_bubble_is_not_showing
  end

  # bug 4078
  def test_filters_reset_properly_when_switching_between_trees
    @type_another = setup_card_type(@project, 'Another')
    @type_card = @project.card_types.find_by_name('Card')

    tree_1 = setup_tree(@project, 'Tree One', :types => [@type_another, @type_card], :relationship_names => ['Tree One - Another'])
    tree_2 = setup_tree(@project, 'Tree Two', :types => [@type_another, @type_card], :relationship_names => ['Tree Two - Another'])

    navigate_to_tree_view_for(@project, tree_2.name)
    add_new_tree_filter_for(@type_another)
    open_tree_filter_property_list(@type_another, 0)
    assert_filter_property_available(@type_another, 0, 'Tree Two - Another')
    assert_filter_property_not_available(@type_another, 0, 'Tree One - Another')

    select_tree(tree_1.name)
    add_new_tree_filter_for(@type_another)
    open_tree_filter_property_list(@type_another, 0)
    assert_filter_property_available(@type_another, 0, 'Tree One - Another')
    assert_filter_property_not_available(@type_another, 0, 'Tree Two - Another')
  end

  # Bug 4008
  def test_no_cards_added_to_tree_message_should_go_away_after_quick_adding_a_card
    navigate_to_tree_view_for(@project, @tree.name)
    assert_info_message("No cards have been assigned to #{@tree.name} tree.")
    quick_add_cards_on_tree(@project, @tree, 'root', :card_names => ['one'])
    assert_info_message_not_present
  end

  # bug 4178
  def test_switching_between_two_trees_will_change_root_node_appropriately
    tree2 = setup_tree(@project, 'second tree', :types => [@type_release, @type_iteration], :relationship_names => ['second tree - release'])
    navigate_to_tree_view_for(@project, @tree.name)
    assert_root_node_has_tree_name(@tree.name)
    select_tree(tree2.name)
    assert_root_node_has_tree_name(tree2.name)
  end

  # bug 4169
  def test_user_specific_transitions_will_not_show_on_card_popups_for_wrong_users
    add_card_to_tree(@tree, @tasks)
    transition = create_transition(@project, 'just for member', :card_type => @type_task, :set_properties => { :status => CLOSED }, :user_prerequisites => [@member.id])

    login_as_project_member
    navigate_to_tree_view_for(@project, @tree.name)
    click_on_card_in_tree(@tasks.first)
    assert_transition_present_on_card(transition)

    login_as_admin_user
    navigate_to_tree_view_for(@project, @tree.name)
    click_on_card_in_tree(@tasks.first)
    assert_transition_not_present_on_card(transition)
  end

  # bug 3067
  def test_reconfiguring_tree_updates_the_pivot_table
    get_planning_tree_generated_with_cards_on_tree
    edit_overview_page
    table_one = add_pivot_table_query_and_save_for(RELATION_PLANNING_RELEASE, RELATION_PLANNING_ITERATION, :empty_rows => 'true', :empty_columns => 'true', :totals => 'true')
    assert_table_row_data_for(table_one, :row_number => 1, :cell_values => ['7', BLANK, '1'])
    navigate_to_tree_configuration_for(@project, @tree)
    remove_card_type_node_from_tree(2)
    click_save_link
    assert_warning_messages_on_tree_node_remove(STORY, RELATION_PLANNING_STORY)
    click_save_permanently_link
    navigate_to_tree_view_for(@project, @tree.name, [@r1, @i1, @r2, @i2])
    assert_card_not_present_on_tree(@project, @stories[0], @stories[1], @stories[2], @stories[3], @stories[4])
    click_overview_tab
    assert_table_row_data_for(table_one, :row_number => 1, :cell_values => ['2', BLANK, '1'])
    assert_table_row_data_for(table_one, :row_number => 4, :cell_values => ['2', BLANK, '9'])
  end

  #bug 4547
  def test_card_name_having_quotes_will_not_break_while_adding_it_for_relationship_property_on_card_show
    card_with_quotes = create_card!(:name => "this card has \" in the name", :card_type => ITERATION_TYPE)
    add_card_to_tree(@tree, @r1)
    add_card_to_tree(@tree, card_with_quotes, @r1)
    open_card(@project, @stories[0])
    set_relationship_properties_on_card_show(RELATION_PLANNING_ITERATION => card_with_quotes)
    assert_properties_set_on_card_show(RELATION_PLANNING_ITERATION => card_with_quotes)
    assert_properties_set_on_card_show(RELATION_PLANNING_RELEASE => @r1)
  end

  # Story 12754 -quick add on funky tray
  def test_should_be_able_to_quick_add_card_on_tree_view
    select_tree(@tree.name)
    switch_to_tree_view_through_action_bar
    assert_quick_add_link_present_on_funky_tray
    add_card_via_quick_add("new card")
    @browser.wait_for_element_visible("notice")
    card = find_card_by_name("new card")
    assert_notice_message("Card ##{card.number} was successfully created, but is not shown because it does not match the current filter.", :escape => true)
  end

  def test_view_tree_configuration_link_present_when_switching_among_different_views
    add_card_to_tree(@tree, @r1)
    select_tree(@tree)
    assert_view_tree_configuration_present
    switch_to_grid_view
    assert_view_tree_configuration_present
    switch_to_hierarchy_view
    assert_view_tree_configuration_present
    switch_to_tree_view
    assert_view_tree_configuration_present
  end

end
