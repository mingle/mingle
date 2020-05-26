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
class Scenario69CardTreeUsage2Test < ActiveSupport::TestCase

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


  #bug 3078
  def test_removal_of_a_sub_node_on_a_tree_really_removes_all_children
    get_planning_tree_generated_with_cards_on_tree
    remove_card_and_its_children_from_tree_for(@project, @tree.name, @i1)
    assert_card_not_present_on_tree(@project, @i1, @stories[0], @stories[1], @stories[2], @stories[3], @stories[4], @tasks[0], @tasks[1])
  end

  # bug3078
  def test_removal_of_only_node_on_a_tree_adds_all_its_children_to_its_node_above
    get_planning_tree_generated_with_cards_on_tree
    remove_card_without_its_children_from_tree_for(@project, @tree.name, @stories[1])
    assert_card_not_present_on_tree(@project, @stories[1])
    assert_cards_on_a_tree(@project, @tasks[0], @tasks[1])
    @tasks.each { |task| assert_cards_are_linked_to_its_parent_card(task, RELATION_PLANNING_ITERATION) }
  end

  def test_removal_of_cards_from_tree_does_not_remove_cards_from_project
    get_planning_tree_generated_with_cards_on_tree
    remove_card_and_its_children_from_tree_for(@project, @tree.name, @r1)
    reset_view
    assert_cards_present(@r1, @i1, @stories[0], @stories[1], @stories[2], @stories[3], @stories[4], @tasks[0], @tasks[1])
  end

  # Relationship property change tests on card show/edit and card defaults
  def test_leaf_card_set_its_one_parent_will_automatically_set_other_parent_properties_on_card_show
    get_planning_tree_generated_with_cards_on_tree
    task_card = create_card!(:name => "card task1", :type => TASK)
    open_card(@project, task_card)
    set_relationship_properties_on_card_show(RELATION_PLANNING_STORY => @stories[0])
    assert_properties_set_on_card_show(RELATION_PLANNING_STORY => @stories[0])
    assert_properties_set_on_card_show(RELATION_PLANNING_ITERATION => @i1)
    assert_properties_set_on_card_show(RELATION_PLANNING_RELEASE => @r1)
  end

  def test_setting_parent_lavel_relationship_property_will_set_all_children_to_not_set_on_card_show
    get_planning_tree_generated_with_cards_on_tree
    open_card(@project, @tasks[0])
    set_relationship_properties_on_card_show(RELATION_PLANNING_RELEASE => @r2)
    assert_properties_set_on_card_show(RELATION_PLANNING_RELEASE => @r2)
    assert_properties_set_on_card_show(RELATION_PLANNING_STORY => NOTSET)
    assert_properties_set_on_card_show(RELATION_PLANNING_ITERATION => NOTSET)
  end

  def test_leaf_card_set_its_one_parent_will_automatically_set_other_parent_properties_on_card_edit
    get_planning_tree_generated_with_cards_on_tree
    task_card = create_card!(:name => "card task1", :type => TASK)
    open_card_for_edit(@project, task_card)
    set_relationship_properties_on_card_edit(RELATION_PLANNING_STORY => @stories[0])
    assert_properties_set_on_card_edit(RELATION_PLANNING_STORY => card_number_and_name(@stories[0]))
    save_card
    assert_notice_message("Card ##{task_card.number} was successfully updated.")
    assert_properties_set_on_card_show(RELATION_PLANNING_STORY => @stories[0])
    assert_properties_set_on_card_show(RELATION_PLANNING_ITERATION => @i1)
    assert_properties_set_on_card_show(RELATION_PLANNING_RELEASE => @r1)
  end

  def test_only_one_relationship_property_allowed_to_set_on_card_edit_mode
    get_planning_tree_generated_with_cards_on_tree
    task_card = create_card!(:name => "card task1", :type => TASK)
    open_card_for_edit(@project, task_card)
    set_relationship_properties_on_card_edit(RELATION_PLANNING_ITERATION => @i1)
    set_relationship_properties_on_card_edit(RELATION_PLANNING_RELEASE => @r2)
    assert_properties_set_on_card_edit(RELATION_PLANNING_RELEASE => @r2, RELATION_PLANNING_ITERATION => @i1)
    save_card_with_flash
    assert_error_message_without_html_content("Suggested location on tree planning tree is invalid.Cannot have #{RELATION_PLANNING_RELEASE} as #{card_number_and_name(@r2)} and #{RELATION_PLANNING_ITERATION} as #{card_number_and_name(@i1)} at the same time.")
  end

  def test_card_defaults_can_set_only_one_relationship_property_as_default
    open_edit_defaults_page_for(@project, TASK)
    set_property_defaults(@project, RELATION_PLANNING_STORY => @stories[0])
    assert_property_set_on_card_defaults(@project, RELATION_PLANNING_STORY, @stories[0])
    assert_property_not_editable_on_card_defaults(@project, RELATION_PLANNING_ITERATION)
    assert_disabled_relationship_property_value_on_card_default(@project, RELATION_PLANNING_ITERATION => "(determined by tree)", RELATION_PLANNING_RELEASE => "(determined by tree)")
  end

  def test_more_than_one_relationship_property_cannot_be_set_on_card_defaults
    open_edit_defaults_page_for(@project, TASK)
    set_property_defaults(@project, RELATION_PLANNING_RELEASE => @r1)
    assert_property_set_on_card_defaults(@project, RELATION_PLANNING_RELEASE, @r1)
    assert_properties_not_editable_on_card_defaults(@project, RELATION_PLANNING_ITERATION, RELATION_PLANNING_STORY)
    assert_disabled_relationship_property_value_on_card_default(@project, RELATION_PLANNING_ITERATION => NOTSET, RELATION_PLANNING_STORY => NOTSET)
  end

  def test_delete_link_disabled_on_setting_relationship_property_on_card_show
    task_card = create_card!(:name => "card task1", :type => TASK)
    open_card(@project, task_card)
    assert_delete_link_present
    set_relationship_properties_on_card_show(RELATION_PLANNING_RELEASE => @r1)
    assert_delete_link_on_card_show_disabled(@project, task_card.name)
  end

  # quick add cards on tree tests...
  def test_quick_add_card_on_tree
    get_planning_tree_generated_with_cards_on_tree
    quick_add_cards_on_tree(@project, @tree, @r1, :card_names => ['one', 'two', 'three', 'four', 'five', 'six'])
    assert_notice_message("6 cards were created successfully.")
    assert_cards_on_a_tree(@project, ['one', 'two', 'three', 'four', 'five', 'six'])
  end

  #8517
  def test_quick_add_card_on_tree_in_maximixed_view
    get_planning_tree_generated_with_cards_on_tree
    select_tree(@tree.name)
    switch_to_tree_view
    maximize_current_view
    quick_add_cards_on_tree(@project, @tree, @r1, :card_names => ['ein', 'zwei'], :reset_filter => 'no')
    assert_notice_message('2 cards were created successfully.')
    assert_cards_on_a_tree(@project, ['ein', 'zwei'])
  end

  def test_card_type_is_taken_while_quick_add_of_cards_on_tree
    get_planning_tree_generated_with_cards_on_tree
    quick_add_cards_on_tree(@project, @tree, @r1, :card_names => ['one'], :type => TASK)
    open_card_by_name(@project, 'one')
    assert_card_type_set_on_card_show(TASK)
  end

end
