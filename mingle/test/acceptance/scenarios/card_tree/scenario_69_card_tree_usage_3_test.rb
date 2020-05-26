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
class Scenario69CardTreeUsage3Test < ActiveSupport::TestCase

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


  def test_leaf_node_cards_will_not_have_quick_add_card_link
    get_planning_tree_generated_with_cards_on_tree
    navigate_to_tree_view_for(@project, @tree.name)
    assert_quick_add_link_not_present_on_card(@tasks[0])
  end

  # bug 3255
  def test_tree_root_and_nonleaf_node_have_quick_add_card_link
    navigate_to_tree_view_for(@project, @tree.name)
    assert_quick_add_link_present_on_root
    get_planning_tree_generated_with_cards_on_tree
    navigate_to_tree_view_for(@project, @tree.name)
    expand_collapse_nodes_in_tree_view(@r1, @i1)
    assert_quick_add_link_present_on_cards(@r1, @i1, @stories[0], @stories[1], @stories[2], @stories[3], @stories[4])
  end

  def test_remove_and_add_button_in_quick_add_form
    navigate_to_tree_view_for(@project, @tree.name)
    click_on_quick_add_cards_to_tree_link_for('root')
    assert_remove_button_present(5)
    assert_add_button_present
    add_new_line_in_quick_add
    assert_remove_button_present(6)
    type_card_name_on_quick_add(4, 'card 5')
    assert_card_name_on_quick_add_row(4, 'card 5')
    delete_line_from_quick_add(4)
    assert_remove_button_present(5)
    assert_card_name_on_quick_add_row(4, '')
  end

  def test_cards_will_have_relevent_card_types_for_quick_add
    get_planning_tree_generated_with_cards_on_tree
    navigate_to_tree_view_for(@project, @tree.name)
    click_on_quick_add_cards_to_tree_link_for('root')
    assert_card_types_present_on_quick_add(RELEASE, ITERATION_TYPE, STORY, TASK)
    click_on_quick_add_cards_to_tree_link_for(@stories[0])
    assert_card_types_present_on_quick_add(TASK)
    assert_card_types_not_present_on_quick_add(RELEASE, ITERATION_TYPE, STORY)
  end

  def test_create_children_for_tree_widget_avaible_on_card_except_leaf_node_card
    tree = create_and_configure_new_card_tree(@project, :name => 'PLANNING_TREE', :types => [RELEASE, ITERATION_TYPE, STORY], :relationship_names => ["abc", "cde"])
    release_card = create_card!(:name => 'release 1', :card_type => @type_release)
    story_card = create_card!(:name => 'story A', :card_type => @type_story)
    add_card_to_tree(tree, story_card)
    add_card_to_tree(tree, release_card)
    open_card(@project, story_card.number)
    assert_create_new_children_link_not_present_for(tree)
    open_card(@project, release_card.number)
    assert_create_new_children_link_present_for(tree)
  end

  def test_create_children_will_have_valid_types_for_the_tree
    tree1 = create_and_configure_new_card_tree(@project, :name => 'PLANNING_TREE1', :types => [RELEASE, ITERATION_TYPE, STORY], :relationship_names => ["planning_tree1-release", "planning_tree1-iteration"])
    tree2 = create_and_configure_new_card_tree(@project, :name => 'PLANNING_TREE2', :types => [RELEASE, ITERATION_TYPE, TASK], :relationship_names => ["planning_tree2-release", "planning_tree2-iteration"])
    release_card = create_card!(:name => 'release 1', :card_type => @type_release)
    add_card_to_tree(tree1, release_card)
    add_card_to_tree(tree2, release_card)

    open_card(@project, release_card.number)
    click_on_create_children_for(tree1)
    assert_card_types_present_on_quick_add(ITERATION_TYPE, STORY)
    assert_card_types_not_present_on_quick_add(RELEASE, TASK)

    click_on_create_children_for(tree2)
    assert_card_types_present_on_quick_add(ITERATION_TYPE, TASK)
    assert_card_types_not_present_on_quick_add(RELEASE, STORY)
  end

  def test_should_be_able_to_add_cards_to_tree_on_card_show
    tree = create_and_configure_new_card_tree(@project, :name => 'PLANNING_TREE1', :types => [RELEASE, ITERATION_TYPE, STORY], :relationship_names => ["planning_tree1-release", "planning_tree1-iteration"])
    release_card = create_card!(:name => 'release 1', :card_type => @type_release)
    add_card_to_tree(tree, release_card)
    open_card(@project, release_card)
    card_names = ['story 1', 'story 2', 'story 3']
    quick_add_cards_to_tree_on_card_show(@project, tree, :type => STORY, :card_names => card_names)
    assert_notice_message("3 cards were created successfully.")
    navigate_to_card_list_for(@project)
    select_tree(tree.name)
    expand_collapse_nodes_in_tree_view(release_card)
    assert_cards_showing_on_tree(*@project.cards.find_all_by_name(card_names))
  end

  # bug 8691
  def test_close_create_children_box_should_not_leave_select_type_dropdown_opened
    tree = create_and_configure_new_card_tree(@project, :name => 'PLANNING_TREE1', :types => [RELEASE, ITERATION_TYPE, STORY], :relationship_names => ["planning_tree1-release", "planning_tree1-iteration"])
    release_card = create_card!(:name => 'release 1', :card_type => @type_release)
    add_card_to_tree(tree, release_card)
    open_card(@project, release_card)
    click_on_create_children_for(tree)
    @browser.click("card_type_select_link")
    @browser.wait_for_element_visible("card_tree_quick_add_card_type_drop_down")
    @browser.click("tree_cards_quick_add_cancel_button")
    @browser.wait_for_element_not_visible("tree_cards_quick_add")
    # PS: on ie, it still present but invisible
    assert !@browser.is_element_present("card_tree_quick_add_card_type_drop_down") || !@browser.is_visible("card_tree_quick_add_card_type_drop_down"), "you should not see dropdown any more"
  end

  def test_card_name_more_than_255_char_gives_error_message_for_add_children_widget
    name_with_255_characters = 'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Etiam iaculis neque. Maecenas risus. Maecenas eget felis vitae ipsum tempus consectetuer. Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Etiam iaculis neque. Maecenas risus. Maecenas risq'
    tree = create_and_configure_new_card_tree(@project, :name => 'PLANNING_TREE1', :types => [RELEASE, ITERATION_TYPE, STORY], :relationship_names => ["planning_tree1-release", "planning_tree1-iteration"])
    release_card = create_card!(:name => 'release 1', :card_type => @type_release)
    add_card_to_tree(tree, release_card)
    open_card(@project, release_card)
    quick_add_cards_to_tree_on_card_show(@project, tree, :type => STORY, :card_names => ['story 1', 'story 2', name_with_255_characters])
    assert_error_message("No cards have been created.")
    @browser.assert_element_present(class_locator("card-name-input.error"))
  end

  # bug 3248
  def test_grouping_by_type_when_project_has_tree_does_not_cause_were_sorry
    foo_type = setup_card_type(@project, 'foo')
    bar_type = setup_card_type(@project, 'bar')
    foo_tree = setup_tree(@project, 'foo tree', :types => [foo_type, bar_type], :relationship_names => ['foo property'])
    bar_card = create_card!(:name => 'bar one')
    navigate_to_grid_view_for(@project)
    group_columns_by('Type')
    assert_lane_present('Type', 'bar')
    @browser.assert_text_not_present("We're sorry")
  end

  # bug 3434
  def test_filtering_out_all_cards_will_result_in_message_and_reset_filter_link
    select_tree(@tree.name)
    switch_to_tree_view_through_action_bar

    release_card = create_card!(:name => 'release 1', :card_type => @type_release)
    add_card_to_tree(@tree, release_card)

    navigate_to_tree_view_for(@project, @tree.name)
    click_exclude_card_type_checkbox(RELEASE)

    assert_card_not_showing_on_tree(release_card)

    assert_no_cards_assigned_message(@tree)
    reset_filter_when_no_card_found
    assert_card_showing_on_tree(release_card)
  end

  # bug 3192
  def test_up_link_on_card_show_when_coming_from_tree_will_show_correct_message
    release_card = create_card!(:name => 'release 1', :card_type => @type_release)
    story_card = create_card!(:name => 'story 1', :card_type => @type_story)
    add_card_to_tree(@tree, release_card)
    add_card_to_tree(@tree, story_card, release_card)

    select_tree(@tree.name)
    switch_to_tree_view_through_action_bar
    view = create_card_list_view_for(@project, 'some tree')

    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(view)

    click_tab('some tree')
    expand_collapse_nodes_in_tree_view(release_card)

    open_a_card_in_tree_view(@project, story_card.number)

    assert_up_link_text("Up to some tree")
    click_up_link
    assert_tab_highlighted('some tree')
  end

  # bug 3408
  def test_reset_filter_link_will_clear_the_filters_to_tab_state
    release_card, iteration_card, story_card = fill_one_branch_tree
    select_tree(@tree.name)
    switch_to_tree_view_through_action_bar

    click_exclude_card_type_checkbox(@type_release)
    view = create_card_list_view_for(@project, 'tree without releases showing')
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(view)

    click_tab('tree without releases showing')
    wait_for_tree_result_load
    assert_card_not_showing_on_tree(release_card)

    assert_cards_showing_on_tree(iteration_card)
    expand_collapse_nodes_in_tree_view(iteration_card)
    assert_cards_showing_on_tree(story_card)

    add_new_tree_filter_for(@type_iteration)
    set_tree_filter_for(@type_iteration, 0, :property => RELATION_PLANNING_ITERATION, :value => NOTSET)

    @browser.wait_for_element_visible("node_0") #If the root node is visible, the tree is redrawn
    assert_no_cards_assigned_message(@tree)

    reset_filter_when_no_card_found
    assert_card_not_showing_on_tree(release_card)
    assert_cards_showing_on_tree(iteration_card, story_card)
  end

end
