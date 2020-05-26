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

# Tags: relationship-properties, bulk, tree-usage, properties, card-selector
class Scenario86BulkEditRelationshipPropertiesTest < ActiveSupport::TestCase
  
  fixtures :users, :login_access
  
  STATUS = 'status'
  NEW = 'new'
  OPEN = 'open'
  BLANK = ''
  NOT_SET = '(not set)'
  
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
    @project = create_project(:prefix => 'scenario_86', :admins => [@project_admin], :users => [@project_member])
    setup_property_definitions(STATUS => [NEW, OPEN])
    @type_story = setup_card_type(@project, STORY, :properties => [STATUS])
    @type_iteration = setup_card_type(@project, ITERATION, :properties => [STATUS])
    @type_release = setup_card_type(@project, RELEASE)
    login_as_admin_user
    @release1 = create_card!(:name => 'release 1', :description => "super plan", :card_type => RELEASE)
    @release2 = create_card!(:name => 'release 2', :card_type => RELEASE)
    @iteration1 = create_card!(:name => 'iteration 1', :card_type => ITERATION)
    @iteration2 = create_card!(:name => 'iteration 2', :card_type => ITERATION)
    @story1 = create_card!(:name => 'story 1', :card_type => STORY)
    @planning_tree = setup_tree(@project, PLANNING_TREE, :types => [@type_release, @type_iteration, @type_story], :relationship_names => [RELEASE_PROPERTY, ITERATION_PROPERTY])
  end
  
  def test_really_select_all_will_set_relationship_properties_on_bulk_edit
    add_card_to_tree(@planning_tree, @release1)
    cards = create_cards(@project, 26, :card_type => @type_story)
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :type => STORY)
    
    select_all
    really_select_all_cards(27)
    click_edit_properties_button
    set_bulk_properties(@project, RELEASE_PROPERTY => @release1)
    assert_notice_message('27 cards updated.')
    navigate_to_tree_view_for(@project, @planning_tree.name)
    card_names = cards.each{|card| card.id}.join(',')
    assert_cards_on_a_tree(card_names)
  end
  
  def test_setting_higher_level_type_to_not_set_will_remove_relationship_property_set_at_the_lower_level_too
    add_card_to_tree(@planning_tree, @release1)
    add_card_to_tree(@planning_tree, @iteration1, @release1)
    cards = create_cards(@project, 26, :card_type => @type_story)
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :type => STORY)
    
    select_all
    click_edit_properties_button
    set_bulk_properties(@project, RELEASE_PROPERTY => @release1)
    set_bulk_properties(@project, ITERATION_PROPERTY => @iteration1)
    assert_notice_message('25 cards updated.')
    set_bulk_properties(@project, RELEASE_PROPERTY => NOT_SET)
    assert_property_set_in_bulk_edit_panel(@project, ITERATION_PROPERTY,NOT_SET)
  end
  
  # #4201  uncomment the assertion after fix.
  def test_transitions_on_relation_ship_property_can_be_executed_through_bulk_edit
    story2 = create_card!(:name => 'story 2', :card_type => STORY)
    transition1 = create_transition_for(@project, 'set release to 1', :type => STORY, :set_properties => {RELEASE_PROPERTY => card_number_and_name(@release1)})
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :type => STORY)
    select_all
    click_edit_properties_button
    execute_bulk_transition_action(transition1)
    # assert_notice_message("#{transition1.name} successfully applied to cards ##{story2.number}, ##{@story1.number}") 
    open_card(@project, @story1)
    assert_properties_set_on_card_show(RELEASE_PROPERTY => @release1)
    assert_history_for(:card, @story1.number).version(2).shows(:set_properties => {RELEASE_PROPERTY => card_number_and_name(@release1)})

    open_card(@project, story2)
    assert_properties_set_on_card_show(RELEASE_PROPERTY => @release1)
    assert_history_for(:card, story2.number).version(2).shows(:set_properties => {RELEASE_PROPERTY => card_number_and_name(@release1)})
  end
  
  # bug 3326
  def test_values_for_relationship_properties_appear_as_card_number_and_card_name_in_bulk_edit_panel
    add_card_to_tree(@planning_tree, @release1)
    add_card_to_tree(@planning_tree, @iteration1, @release1)
    add_card_to_tree(@planning_tree, @story1, @iteration1)
    navigate_to_card_list_for(@project)
    check_cards_in_list_view(@story1)
    click_edit_properties_button
    assert_property_set_in_bulk_edit_panel(@project, RELEASE_PROPERTY, @release1)
    assert_property_set_in_bulk_edit_panel(@project, ITERATION_PROPERTY, @iteration1)
  end
  
  # bug 3331
  def test_card_history_does_not_create_extra_version_when_bulk_editing_relationship_property
    add_card_to_tree(@planning_tree, @release1)
    add_card_to_tree(@planning_tree, @iteration1, @release1)
    add_card_to_tree(@planning_tree, @story1, @iteration1)
    navigate_to_card_list_for(@project)
    check_cards_in_list_view(@story1)
    check_cards_in_list_view(@iteration1)
    click_edit_properties_button
    set_bulk_properties(@project, RELEASE_PROPERTY => @release2)
    open_card(@project, @iteration1.number)
    assert_history_for(:card, @iteration1.number).version(3).shows(:changed => RELEASE_PROPERTY, :from => card_number_and_name(@release1), :to => card_number_and_name(@release2))
    assert_history_for(:card, @iteration1.number).version(4).not_present
    # @browser.assert_ordered("card-#{@iteration1.number}-3", "card-#{@iteration1.number}-2")
    # @browser.assert_ordered("card-#{@iteration1.number}-2", "card-#{@iteration1.number}-1")
    assert_properties_set_on_card_show(RELEASE_PROPERTY => @release2)
    open_card(@project, @story1.number)
    assert_history_for(:card, @story1.number).version(3).shows(:changed => RELEASE_PROPERTY, :from => card_number_and_name(@release1), :to => card_number_and_name(@release2))
    assert_history_for(:card, @story1.number).version(3).shows(:changed => ITERATION_PROPERTY, :from => card_number_and_name(@iteration1), :to => NOT_SET)
    assert_history_for(:card, @story1.number).version(4).not_present
    # @browser.assert_ordered("card-#{@story1.number}-3", "card-#{@story1.number}-2")
    # @browser.assert_ordered("card-#{@story1.number}-2", "card-#{@story1.number}-1")
    assert_properties_set_on_card_show(RELEASE_PROPERTY => @release2, ITERATION_PROPERTY => NOT_SET)
  end
  
  # bug 3400
  def test_can_set_relationship_property_to_not_set_via_bulk
    add_card_to_tree(@planning_tree, @iteration1)
    add_card_to_tree(@planning_tree, @story1, @iteration1)
    navigate_to_card_list_for(@project)
    check_cards_in_list_view(@story1)
    click_edit_properties_button
    set_bulk_properties(@project, ITERATION_PROPERTY => NOT_SET)
    open_card(@project, @story1.number)
    assert_history_for(:card, @story1.number).version(3).shows(:changed => ITERATION_PROPERTY, :from => card_number_and_name(@iteration1), :to => NOT_SET)
    assert_history_for(:card, @story1.number).version(4).not_present
    # @browser.assert_ordered("card-#{@story1.number}-3", "card-#{@story1.number}-2")
    # @browser.assert_ordered("card-#{@story1.number}-2", "card-#{@story1.number}-1")
    assert_properties_set_on_card_show(ITERATION_PROPERTY => NOT_SET)
  end
  
  # bug 3390
  def test_can_bulk_set_relationship_property_when_type_name_is_not_all_lowercase
    bug_cluster_property = 'Bug Cluster property'
    card_type_name_that_is_not_all_lower_case = setup_card_type(@project, 'BUG Cluster')
    type_defect = setup_card_type(@project, 'Defect')
    bug_cluster_tree = setup_tree(@project, 'Bug Cluster Tree', :types => [card_type_name_that_is_not_all_lower_case, type_defect], 
      :relationship_names => [bug_cluster_property])
    bug_cluster_card = create_card!(:name => 'Bug Cluster A', :card_type => card_type_name_that_is_not_all_lower_case)
    defect_card = create_card!(:name => 'defect A', :card_type => type_defect)
    navigate_to_card_list_for(@project)
    check_cards_in_list_view(defect_card)
    click_edit_properties_button
    set_bulk_properties(@project, bug_cluster_property => bug_cluster_card)
    open_card(@project, defect_card.number)
    assert_history_for(:card, defect_card.number).version(2).shows(:set_properties => {bug_cluster_property => card_number_and_name(bug_cluster_card)})
    assert_history_for(:card, defect_card.number).version(3).not_present
    # @browser.assert_ordered("card-#{defect_card.number}-2", "card-#{defect_card.number}-1")
    assert_properties_set_on_card_show(bug_cluster_property => bug_cluster_card)
  end
  
  # bug 3061
  def test_changing_card_type_of_card_that_is_value_of_relationship_property_sets_value_to_not_set_and_moves_child_card_to_grandparent
    add_card_to_tree(@planning_tree, @release1)
    add_card_to_tree(@planning_tree, @iteration1, @release1)
    add_card_to_tree(@planning_tree, @story1, @iteration1)
    navigate_to_card_list_for(@project)
    check_cards_in_list_view(@iteration1)
    click_edit_properties_button
    set_bulk_properties(@project, :type => RELEASE)
    open_card(@project, @iteration1)
    assert_card_in_tree(@project, @planning_tree, @iteration1)
    assert_properties_set_on_card_show(:Type => RELEASE)
    assert_property_not_present_on_card_show(RELEASE_PROPERTY)
    assert_history_for(:card, @iteration1.number).version(3).shows(:changed => 'Type', :from => ITERATION, :to => RELEASE)
    assert_history_for(:card, @iteration1.number).version(3).shows(:changed => RELEASE_PROPERTY, :from => card_number_and_name(@release1), :to => NOT_SET)
    open_card(@project, @story1)
    assert_history_for(:card, @story1.number).version(3).shows(:changed => ITERATION_PROPERTY, :from => card_number_and_name(@iteration1), :to => NOT_SET)
    assert_properties_set_on_card_show(RELEASE_PROPERTY => @release1, ITERATION_PROPERTY => NOT_SET)
    assert_card_in_tree(@project, @planning_tree, @story1)
  end
  
end
