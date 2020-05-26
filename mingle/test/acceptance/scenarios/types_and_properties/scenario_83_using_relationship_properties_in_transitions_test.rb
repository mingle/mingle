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

# Tags: relationship-properties, tree-usage, transitions, properties
class Scenario83UsingRelationshipPropertiesInTransitionsTest < ActiveSupport::TestCase
  
  fixtures :users, :login_access
  
  STATUS = 'status'
  NEW = 'new'
  OPEN = 'open'
  BLANK = ''
  NOT_SET = '(not set)'
  REQUIRE_USER_INPUT = '(user input - required)'
  DETERMINED_BY_TREE = '(determined by tree)'
  
  PLANNING_TREE = 'Planning Tree'
  RELEASE_PROPERTY = 'Planning Tree release'
  ITERATION_PROPERTY = 'Planning Tree iteration'
  RELEASE = 'Release'
  ITERATION = 'Iteration'
  STORY = 'Story'
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin = users(:proj_admin)
    @project_member = users(:project_member)
    @project = create_project(:prefix => 'scenario_83', :admins => [@project_admin], :users => [@project_member])
    setup_property_definitions(STATUS => [NEW, OPEN])
    @type_story = setup_card_type(@project, STORY, :properties => [STATUS])
    @type_iteration = setup_card_type(@project, ITERATION, :properties => [STATUS])
    @type_release = setup_card_type(@project, RELEASE)
    login_as_proj_admin_user
    @release1 = create_card!(:name => 'release 1', :description => "super plan", :card_type => RELEASE)
    @release2 = create_card!(:name => 'release 2', :card_type => RELEASE)
    @iteration1 = create_card!(:name => 'iteration 1', :card_type => ITERATION)
    @iteration2 = create_card!(:name => 'iteration 2', :card_type => ITERATION)
    @story1 = create_card!(:name => 'story 1', :card_type => STORY)
    @planning_tree = setup_tree(@project, PLANNING_TREE, :types => [@type_release, @type_iteration, @type_story], :relationship_names => [RELEASE_PROPERTY, ITERATION_PROPERTY])
    add_card_to_tree(@planning_tree, @release1)
  end
  
  # requires: release1
  # sets: iteration1 that is not on release1, but is on tree root
  def test_using_transition_to_move_card_from_one_node_to_another_sibling_node_in_tree_that_is_different_card_type
    story_not_in_tree = create_card!(:name => 'story not in tree', :card_type => STORY)
    story_assigned_to_release = create_card!(:name => 'story assigned to release in tree', :card_type => STORY)
    add_card_to_tree(@planning_tree, story_assigned_to_release, @release1)
    add_card_to_tree(@planning_tree, @iteration1)
    transition_requiring_card_to_be_assigned_to_release = create_transition_for(@project, 'move from release node to iteration node', :type => STORY, 
      :required_properties => {RELEASE_PROPERTY => card_number_and_name(@release1)}, 
      :set_properties => {ITERATION_PROPERTY => card_number_and_name(@iteration1)})

    open_card(@project, story_not_in_tree.number)
    assert_transition_not_present_on_card(transition_requiring_card_to_be_assigned_to_release)

    open_card(@project, story_assigned_to_release)
    click_transition_link_on_card(transition_requiring_card_to_be_assigned_to_release)
    @browser.run_once_history_generation
    open_card(@project, story_assigned_to_release)
    load_card_history
    assert_history_for(:card, story_assigned_to_release.number).version(3).shows(:set_properties => {ITERATION_PROPERTY => card_number_and_name(@iteration1)})
    assert_history_for(:card, story_assigned_to_release.number).version(3).shows(:changed => RELEASE_PROPERTY, :from => card_number_and_name(@release1), :to => NOT_SET)
    assert_history_for(:card, story_assigned_to_release.number).version(4).not_present
    assert_properties_set_on_card_show(RELEASE_PROPERTY => NOT_SET, ITERATION_PROPERTY => @iteration1)
  end
  
  # requires: release1
  # sets: release2
  def test_using_transition_to_move_card_from_one_node_to_another_sibling_node_in_tree_that_is_same_card_type
    story_not_in_tree = create_card!(:name => 'story not in tree', :card_type => STORY)
    story_assigned_to_release = create_card!(:name => 'story assigned to release in tree', :card_type => STORY)
    add_card_to_tree(@planning_tree, story_assigned_to_release, @release1)
    add_card_to_tree(@planning_tree, @release2)
    transition_requiring_card_to_be_assigned_to_release = create_transition_for(@project, 'move from release node to iteration node', :type => STORY, 
      :required_properties => {RELEASE_PROPERTY => card_number_and_name(@release1)}, 
      :set_properties => {RELEASE_PROPERTY => card_number_and_name(@release2)})

    open_card(@project, story_not_in_tree.number)
    assert_transition_not_present_on_card(transition_requiring_card_to_be_assigned_to_release)

    open_card(@project, story_assigned_to_release)
    click_transition_link_on_card(transition_requiring_card_to_be_assigned_to_release)
    @browser.run_once_history_generation
    open_card(@project, story_assigned_to_release)
    load_card_history
    assert_history_for(:card, story_assigned_to_release.number).version(3).shows(:changed => RELEASE_PROPERTY, :from => card_number_and_name(@release1), :to => card_number_and_name(@release2))
    assert_history_for(:card, story_assigned_to_release.number).version(4).not_present
    assert_properties_set_on_card_show(RELEASE_PROPERTY => @release2, ITERATION_PROPERTY => NOT_SET)
  end
  
  # req: release
  # set: iteration that is already on release
  def test_using_transition_to_move_card_from_one_node_to_its_child_node
    story_assigned_to_release = create_card!(:name => 'story assigned to release in tree', :card_type => STORY)
    add_card_to_tree(@planning_tree, story_assigned_to_release, @release1)
    add_card_to_tree(@planning_tree, @iteration1, @release1)
    transition_requiring_card_to_be_assigned_to_release = create_transition_for(@project, 'move from release node to iteration node', :type => STORY, 
      :required_properties => {RELEASE_PROPERTY => card_number_and_name(@release1)}, 
      :set_properties => {ITERATION_PROPERTY => card_number_and_name(@iteration1)})

    open_card(@project, story_assigned_to_release)
    click_transition_link_on_card(transition_requiring_card_to_be_assigned_to_release)
    
    @browser.run_once_history_generation
    open_card(@project, story_assigned_to_release)
    load_card_history
    assert_history_for(:card, story_assigned_to_release.number).version(3).shows(:set_properties => {ITERATION_PROPERTY => card_number_and_name(@iteration1)})
    assert_history_for(:card, story_assigned_to_release.number).version(3).does_not_show(:changed => RELEASE_PROPERTY, :from => card_number_and_name(@release1), :to => NOT_SET)
    assert_history_for(:card, story_assigned_to_release.number).version(4).not_present
    assert_properties_set_on_card_show(RELEASE_PROPERTY => @release1, ITERATION_PROPERTY => @iteration1)
  end
  
  # invoking transitions on card
  # invoking transitions via bulk
  # invoking transitions via card pop-up (on grid view & tree view)
  # setting relationship properties in transitions using (not set)
  
  # bug 3202
  def test_can_create_transitions_that_set_relationship_properties_to_require_user_input
    transition_that_requires_user_input = create_transition_for(@project, 'requires user input', :type => STORY, :set_properties => {ITERATION_PROPERTY => REQUIRE_USER_INPUT})
    @browser.assert_text_present("Transition requires user input cannot be activated using the bulk transitions panel because some properties are set to (user input - required) or (user input - optional)")
    assert_transition_present_for(@project, transition_that_requires_user_input)
    open_transition_for_edit(@project, transition_that_requires_user_input)
    assert_sets_property(ITERATION_PROPERTY => REQUIRE_USER_INPUT)
  end
  
  # bug 3445
  def test_can_successfully_invoke_and_complete_transitions_that_set_relationship_properties_to_require_user_input
    transition_that_requires_user_input = create_transition_for(@project, 'requires user input', :type => STORY, :set_properties => {ITERATION_PROPERTY => REQUIRE_USER_INPUT})
    @browser.assert_text_present("Transition requires user input cannot be activated using the bulk transitions panel because some properties are set to (user input - required) or (user input - optional)")
    assert_transition_present_for(@project, transition_that_requires_user_input)
    open_transition_for_edit(@project, transition_that_requires_user_input)
    assert_sets_property(ITERATION_PROPERTY => REQUIRE_USER_INPUT)
    open_card(@project, @story1)
    click_transition_link_on_card(transition_that_requires_user_input)
    set_property_in_complete_transition_lightbox(@project, ITERATION_PROPERTY => card_number_and_name(@iteration1))
    click_on_complete_transition
    @browser.run_once_history_generation
    open_card(@project, @story1)
    load_card_history
    assert_history_for(:card, @story1.number).version(2).shows(:set_properties => {ITERATION_PROPERTY => card_number_and_name(@iteration1)})
    assert_history_for(:card, @story1.number).version(3).not_present
  end
  
  
  #bug 4596
  def test_be_able_to_set_in_popup_when_excuting_transition_which_set_relationship_property_user_input_required
    add_card_to_tree(@planning_tree, @iteration1, @release1)
    add_card_to_tree(@planning_tree, @iteration2, @release1)
    add_card_to_tree(@planning_tree, @story1, @iteration1)
    transition = create_transition_for(@project, 'Set Iteration', :type => STORY, :set_properties => {ITERATION_PROPERTY => REQUIRE_USER_INPUT})
    navigate_to_tree_view_for(@project, @planning_tree.name)
    click_on_transition_for_card_in_tree_view(@story1, transition)
    set_property_in_complete_transition_lightbox(@project, ITERATION_PROPERTY => card_number_and_name(@iteration2))
    click_on_complete_transition
    assert_notice_message("#{transition.name} successfully applied to card ##{@story1.number}")
  end
  
  # bug 3273
  def test_relationship_properties_show_card_number_and_card_name_on_transitions
    add_card_to_tree(@planning_tree, @iteration1, @release1)
    add_card_to_tree(@planning_tree, @iteration2, @release1)
    open_transition_create_page(@project)
    set_card_type_on_transitions_page(STORY)
    set_required_properties(@project, ITERATION_PROPERTY => card_number_and_name(@iteration1))
    set_sets_properties(@project, ITERATION_PROPERTY => card_number_and_name(@iteration2))
    assert_requires_property(ITERATION_PROPERTY => card_number_and_name(@iteration1))
    assert_sets_property(ITERATION_PROPERTY => card_number_and_name(@iteration2))
  end
  
  # bug 3404
  def test_setting_value_for_relationship_property_sets_parent_and_grandparent_to_determined_by_tree
    task = 'task'
    story_property = "#{PLANNING_TREE} - #{STORY}"
    type_task = setup_card_type(@project, task)
    add_new_card_type_to_node(@project, @planning_tree, task, 2, :relationship_name => story_property)
    open_transition_create_page(@project)
    set_card_type_on_transitions_page(task)
    set_sets_properties(@project, story_property => card_number_and_name(@story1))
    assert_sets_property_and_value_read_only(@project, RELEASE_PROPERTY, DETERMINED_BY_TREE)
    assert_sets_property_and_value_read_only(@project, ITERATION_PROPERTY, DETERMINED_BY_TREE)
    assert_sets_property(story_property => card_number_and_name(@story1))
  end
  
  # bug 3478
  def test_cannot_change_type_of_card_that_is_used_as_value_in_transition
    transition_requiring_card_to_be_assigned_to_release = create_transition_for(@project, 'reqs release', :type => STORY, 
      :required_properties => {RELEASE_PROPERTY => card_number_and_name(@release1)}, :set_properties => {STATUS => NEW})
    transition_setting_card_to_release = create_transition_for(@project, 'sets release', :type => STORY, :set_properties => {RELEASE_PROPERTY => card_number_and_name(@release1)})
    open_card(@project, @release1)
    set_card_type_on_card_show(ITERATION)
    @browser.wait_for_element_present('error')
    assert_error_message("Cannot change card type because card is being used in transitions: reqs release, sets release")
    navigate_to_card_list_for(@project)
    check_cards_in_list_view(@release1)
    click_edit_properties_button
    set_card_type_on_bulk_edit(STORY)
    assert_error_message("nnot change card type because some cards are being used in transitions: reqs release, sets release")
    header_row = ['Number', 'Type']
    card_data = [[@release1.number, ITERATION]]
    import(excel_copy_string(header_row, card_data))
    assert_error_message("Cannot change card type because card is being used in transitions: reqs release, sets release")
    assert_card_in_tree(@project, @planning_tree, @release1)
    open_card(@project, @release1)
    assert_card_type_set_on_card_show(RELEASE)
  end
end
