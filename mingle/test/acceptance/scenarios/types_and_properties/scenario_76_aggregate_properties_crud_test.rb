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

# Tags: tree-configuration, aggregate-properties

class Scenario76AggregatePropertiesCrudTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  PRIORITY = 'priority'
  STATUS = 'status'
  SIZE = 'size'
  SIZE2 = 'size2'
  ITERATION = 'iteration'
  OWNER = 'Zowner'

  RELEASE = 'Release'
  ITERATION_TYPE = 'Iteration'
  STORY = 'Story'
  DEFECT = 'Defect'
  TASK = 'Task'
  CARD = 'Card'

  TYPE = 'Type'
  NEW = 'new'
  OPEN = 'open'
  LOW = 'low'
  
  SUM = 'Sum'
  COUNT = 'Count'
  AVERAGE = 'Average'
  
  PLANNING_TREE = 'planning tree'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_admin_user = users(:longbob)
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_76', :users => [@non_admin_user], :admins => [@project_admin_user, users(:admin)])
    login_as_admin_user
    setup_property_definitions(PRIORITY => ['high', LOW], STATUS => [NEW,  'close', OPEN], ITERATION => [1,2,3,4], OWNER  => ['a', 'b', 'c'])
    @size_property = setup_numeric_property_definition(SIZE, [1, 2, 4])
    @size2_property = setup_numeric_property_definition(SIZE2, [0, 3, 5])
    @type_story = setup_card_type(@project, STORY, :properties => [PRIORITY, SIZE, ITERATION, OWNER])
    @type_defect = setup_card_type(@project, DEFECT, :properties => [PRIORITY, STATUS, OWNER])
    @type_task = setup_card_type(@project, TASK, :properties => [PRIORITY, SIZE2, ITERATION, STATUS, OWNER])
    @type_iteration = setup_card_type(@project, ITERATION_TYPE)
    @type_release = setup_card_type(@project, RELEASE)
    @planning_tree = setup_tree(@project, 'Planning Tree', :types => [@type_release, @type_iteration, @type_story, @type_task], 
      :relationship_names => ['PT release', 'PT iteration', 'PT story'])
    navigate_to_tree_configuration_management_page_for(@project)
  end
  
  def test_should_be_able_to_create_edit_and_delete_an_aggregate_property_successfully
    aggregate_property_sum_of_size = create_aggregate_property_for(@project, 'Sum of size', @planning_tree, @type_release, :aggregation_type => SUM,  :property_to_aggregate => SIZE)  
    assert_notice_message("Aggregate property #{aggregate_property_sum_of_size.name} was successfully created")
    assert_aggregate_property_present_on_configuration_for(aggregate_property_sum_of_size)
    click_edit_aggregate_property_for(aggregate_property_sum_of_size)
    assert_set_parameters_for_aggregate_property(aggregate_property_sum_of_size.name, SUM, '', @size_property)
    click_delete_aggregate_property_for(aggregate_property_sum_of_size)
    assert_notice_message("Aggregate property #{aggregate_property_sum_of_size.name} deleted successfully.")
  end
  
  def test_leaf_node_cannot_have_edit_aggregate_property_icon
    open_aggregate_property_management_page_for(@project, @planning_tree)
    assert_leaf_node_deos_not_have_edit_aggregate_link(@type_task)
  end
  
  def test_validations_for_aggregate_property_name
    predefined_properties = ['number', 'name', 'description', 'type', 'created by', 'modified by']
    variations_of_modified_by = ['modified-by', 'modified_by', 'modified:by']
    variations_of_created_by = ['created_by', 'created_by', 'created.by']
    predefined_properties = predefined_properties + variations_of_created_by + variations_of_modified_by
    
    open_aggregate_property_management_page_for(@project, @planning_tree)
    click_on_edit_aggregate_link_on_a_node_for(@type_release)
    select_aggregation_type(COUNT)
    select_scope('All descendants')
        
    predefined_properties.each {|aggregate_property_name| assert_error_message_for_aggregate_property_name(aggregate_property_name)}
    predefined_properties.each {|aggregate_property_name| assert_error_message_for_aggregate_property_name(aggregate_property_name.capitalize)}
    predefined_properties.each {|aggregate_property_name| assert_error_message_for_aggregate_property_name(aggregate_property_name.upcase)}
  end
  
  def test_only_project_admin_can_create_aggregate_property
    login_as(@non_admin_user.login, 'longtest')
    open_aggregate_property_management_page_for(@project, @planning_tree)
    assert_cannot_access_resource_error_message_present
  end
  
  def test_should_be_able_to_edit_aggregate_property
    aggregate_property_sum_of_size = create_aggregate_property_for(@project, 'Sum of size', @planning_tree, @type_release, :aggregation_type => SUM,  :property_to_aggregate => SIZE)  
    aggregate_property_average_of_size = edit_aggregate_property_for(@project, @planning_tree, @type_release, aggregate_property_sum_of_size, :aggregate_property_name =>  'Average of size', :aggregation_type => AVERAGE)
    assert_notice_message("Aggregate property #{aggregate_property_average_of_size.name} updated successfully")
    click_on_edit_aggregate_link_on_a_node_for(@type_release)
    @browser.assert_text_present("#{aggregate_property_average_of_size.name}: Average of size")
  end
  
  def test_error_messages_while_creating_aggregate_properties
    open_aggregate_property_management_page_for(@project, @planning_tree)
    click_on_edit_aggregate_link_on_a_node_for(@type_release)
    click_on_add_or_update_aggregate_property
    assert_error_message("Name can't be blank")
    assert_error_message('Aggregate type must be selected')
    assert_error_message('Aggregate properties must have a valid scope')
    assert_error_message("Target property definition is required unless aggregate type is 'count'")
    
    set_parameteres_for_creating_new_aggregate_property(@planning_tree.name, SUM, 'All descendants', SIZE)
    click_on_add_or_update_aggregate_property
    assert_error_message("Name has already been taken by tree name")
  end
  
  
  def test_if_scope_is_all_descendants_target_properties_should_be_union_of_all_numeric_proeprties
    open_aggregate_property_management_page_for(@project, @planning_tree)
    click_on_edit_aggregate_link_on_a_node_for(@type_release)
    set_parameteres_for_creating_new_aggregate_property('sum of size', SUM, 'All descendants')
    assert_properties_available_on_target_property_drop_down(@size_property, @size2_property)
  end
  
  def test_property_being_used_by_aggregate_property_should_not_be_able_to_be_deleted
    aggregate_property_sum_of_size = create_aggregate_property_for(@project, 'Sum of size', @planning_tree, @type_release, :aggregation_type => SUM,  :property_to_aggregate => SIZE)  
    navigate_to_property_management_page_for(@project)
    click_delete_link_for_property(@size_property)
    
    assert_error_message_for_property_can_not_deleted_because_used_as_target_property_in_aggregate(aggregate_property_sum_of_size)
  end
  
  def test_formula_or_aggregate_property_iteself_cannot_be_used_as_target_property
    @formula_property = setup_formula_property_definition("size_2", "#{SIZE} * 2")
    aggregate_property_sum_of_size = create_aggregate_property_for(@project, 'Sum of size', @planning_tree, @type_release, :aggregation_type => SUM,  :property_to_aggregate => SIZE)  
    click_on_edit_aggregate_link_on_a_node_for(@type_iteration)
    set_parameteres_for_creating_new_aggregate_property('sum of size', SUM, 'All descendants')
    assert_properties_not_available_on_target_property_drop_down(aggregate_property_sum_of_size, @formula_property)
  end
  
  def test_deleting_leaf_node_should_remove_its_parent_aggregate_property_and_also_aggregates_that_use_leaf_node
    aggregate_property_count_of_task = create_aggregate_property_for(@project, 'count of task', @planning_tree, @type_release, :scope => @type_task.name,:aggregation_type => COUNT)  
    aggregate_property_sum_of_size2 = create_aggregate_property_for(@project, 'sum of size2', @planning_tree, @type_story, :scope => @type_task.name,:aggregation_type => SUM, :property_to_aggregate => SIZE2)  
    click_on_edit_tree_structure
    remove_card_type_node_from_tree(3)
    click_save_link
    assert_warning_messages_on_tree_node_remove(@type_task.name,  'PT story', :aggregate_properties => [aggregate_property_count_of_task.name, aggregate_property_sum_of_size2.name])
    click_save_permanently_link
    
    open_aggregate_property_management_page_for(@project, @planning_tree)
    click_on_edit_aggregate_link_on_a_node_for(@type_release)
    assert_no_aggregate_configured
    assert_leaf_node_deos_not_have_edit_aggregate_link(@type_story)
  end
  
  def test_hidden_numeric_properties_are_available_to_set_aggregates
    hide_property(@project, SIZE)
    aggregate_property_sum_of_size = create_aggregate_property_for(@project, 'Sum of size', @planning_tree, @type_release, :aggregation_type => SUM,  :property_to_aggregate => SIZE) 
    assert_notice_message("Aggregate property #{aggregate_property_sum_of_size.name} was successfully created")
    click_edit_aggregate_property_for(aggregate_property_sum_of_size)
    assert_properties_available_on_target_property_drop_down(@size_property)
  end
  
  def test_cannot_be_able_to_add_duplicate_agregate_property
    count_of_task = create_aggregate_property_for(@project, 'count of task', @planning_tree, @type_release, :scope => @type_task.name,:aggregation_type => COUNT)  
    assert_notice_message("Aggregate property #{count_of_task.name} was successfully created")
    count_of_task2 = create_aggregate_property_for(@project, 'count of task', @planning_tree, @type_iteration, :scope => @type_task.name, :aggregation_type => COUNT)
    assert_error_message('Name has already been taken')
  end
  
  # bug 3517
  def test_drop_down_selector_for_target_property_should_escape_html
    name_with_html_tags = "foo <b>BAR</b>"
    name_without_html_tags = "foo BAR"
    edit_property_definition_for(@project, SIZE, :new_property_name => name_with_html_tags)
    open_aggregate_property_management_page_for(@project, @planning_tree)
    click_on_edit_aggregate_link_on_a_node_for(@type_release)
    select_scope(STORY)
    @browser.assert_element_matches('aggregate_property_definition_aggregate_target_id', /#{name_with_html_tags}/)
    @browser.assert_element_does_not_match('aggregate_property_definition_aggregate_target_id', /#{name_without_html_tags}/)
  end
  
  # Bug 3274, 7868
  def test_should_list_aggregate_properties_in_alphabetical_order
    prop_c = create_aggregate_property_for(@project, 'c', @planning_tree, @type_release, :scope => @type_task.name,:aggregation_type => COUNT)
    prop_a = create_aggregate_property_for(@project, 'a', @planning_tree, @type_release, :aggregation_type => SUM,  :property_to_aggregate => SIZE)
    prop_b = create_aggregate_property_for(@project, 'B', @planning_tree, @type_release, :aggregation_type => SUM,  :property_to_aggregate => SIZE)
    click_on_edit_aggregate_link_on_a_node_for(@type_release)
    assert_aggregate_description(0, prop_a, 'a: Sum of size')
    assert_aggregate_description(1, prop_b, 'B: Sum of size')
    assert_aggregate_description(2, prop_c, 'c: Count')
  end
  
  # bug 3211
  def test_target_property_set_when_click_edit_aggregate_link
    aggregate_property = create_aggregate_property_for(@project, 'Sum of size', @planning_tree, @type_release, :aggregation_type => SUM,  :scope => @type_story.name, :property_to_aggregate => SIZE)
    click_edit_aggregate_property_for(aggregate_property)
    assert_set_parameters_for_aggregate_property(aggregate_property.name, SUM, @type_story, @size_property)
  end
  
  # bug 7017
  def test_count_aggregate_type_should_not_allow_a_target
    open_aggregate_property_management_page_for(@project, @planning_tree)
    click_on_edit_aggregate_link_on_a_node_for(@type_release)
    select_aggregation_type(COUNT)
    assert_target_drop_down_names_are(['Not applicable'])    
  end
  
  # Bug 7017
  def test_type_should_restrict_the_target_properties
    task_size_property = setup_numeric_property_definition('task size', [1, 2, 4])
    task_size_property.card_types = [@type_task]

    open_aggregate_property_management_page_for(@project, @planning_tree)
    click_on_edit_aggregate_link_on_a_node_for(@type_release)
    select_scope(@type_task.name)
    assert_properties_available_on_target_property_drop_down(@size_property, @size2_property, task_size_property)
    
    select_scope(@type_iteration.name)
    assert_properties_available_on_target_property_drop_down(@size_property, @size2_property)
    assert_properties_not_available_on_target_property_drop_down(task_size_property)
  end
  
  private
  def set_parameteres_for_creating_new_aggregate_property(name, aggregate_type, scope, target_property = '')
    type_aggreage_property_name(name)
    select_aggregation_type(aggregate_type)
    select_scope(scope)
    select_property_to_be_aggregated(target_property) unless target_property.to_s == ''
  end
  
  def assert_error_message_for_aggregate_property_name(aggregate_property_name)
    type_aggreage_property_name(aggregate_property_name)
    click_on_add_or_update_aggregate_property
    @browser.assert_element_present(class_locator('no-aggregates-hint'))
    assert_error_message("Name #{aggregate_property_name} is a reserved property name")
  end
  
end
