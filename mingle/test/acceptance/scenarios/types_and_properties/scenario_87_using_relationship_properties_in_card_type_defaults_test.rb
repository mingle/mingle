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

# Tags: relationship-properties, tree-usage, defaults
class Scenario87UsingRelationshipPropertiesInCardTypeDefaultsTest < ActiveSupport::TestCase
  
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
  
  DETERMINED_BY_TREE = '(determined by tree)'
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin = users(:proj_admin)
    @project_member = users(:project_member)
    @project = create_project(:prefix => 'scenario_87', :admins => [@project_admin], :users => [@project_member])
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
  
  # bug 3065
  def test_removing_card_from_tree_that_is_also_default_value_for_card_type_readds_card_to_tree_when_card_created_using_defaults
    add_card_to_tree(@planning_tree, @release1)
    add_card_to_tree(@planning_tree, @iteration1, @release1)
    open_edit_defaults_page_for(@project, STORY)
    set_property_defaults(@project, ITERATION_PROPERTY => @iteration1)
    click_save_defaults
    remove_card_from_tree(@planning_tree, @iteration1)
    assert_card_not_in_tree(@project, @planning_tree, @iteration1)
    open_edit_defaults_page_for(@project, STORY)
    assert_property_set_on_card_defaults(@project, ITERATION_PROPERTY, @iteration1)
    assert_disabled_relationship_property_set_on_card_defaults(@project, RELEASE_PROPERTY, DETERMINED_BY_TREE)
    # navigate_to_card_list_for(@project)
    open_add_card_via_quick_add
    set_quick_add_card_type_to(STORY)
    type_card_name('story created with defaults')
    submit_quick_add_card
    card = find_card_by_name('story created with defaults')
    
    @browser.run_once_history_generation
    open_card(@project, card)
    assert_property_set_on_card_show(ITERATION_PROPERTY, @iteration1)
    assert_history_for(:card, card.number).version(1).shows(:set_properties => {ITERATION_PROPERTY => card_number_and_name(@iteration1)})
    assert_card_in_tree(@project, @planning_tree, @iteration1)
  end
  
  # bug 3218
   def test_that_tree_names_are_smart_sorted_on_card_default_and_card_show
     type_task = setup_card_type(@project, 'Task')
     tree_two = setup_tree(@project, 'Release Planning', :types => [@type_iteration, type_task], :relationship_names => ['second property'])
     tree_one = setup_tree(@project, 'a release plan', :types => [@type_iteration, type_task], :relationship_names => ['first property'])
     tree_three = setup_tree(@project, 'task breakdown', :types => [@type_iteration, type_task], :relationship_names => ['third property'])    
     open_edit_defaults_page_for(@project, "Task")
     assert_tree_position_on_card_default("a release plan", 0) 
     assert_tree_position_on_card_default("Release Planning", 1) 
     assert_tree_position_on_card_default("task breakdown", 2) 
   end

   def test_card_will_be_add_to_specified_location_in_tree_if_tree_relationship_property_are_set_in_card_defaults
     open_edit_defaults_page_for(@project, STORY)
     set_property_defaults(@project, ITERATION_PROPERTY => @iteration1)
     click_save_defaults
     add_card_to_tree(@planning_tree, @release1)
     add_card_to_tree(@planning_tree, [@iteration1,@iteration2], @release1)
     navigate_to_hierarchy_view_for(@project, @planning_tree)
     add_new_card("new story", :type => STORY)
     new_story_card = find_card_by_name("new story")
     navigate_to_tree_view_for(@project, @planning_tree.name)
     assert_parent_node(@iteration1, new_story_card)
   end   
end
