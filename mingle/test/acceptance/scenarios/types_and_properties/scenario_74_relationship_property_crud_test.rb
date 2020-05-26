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

#Tags: tree-configuration, relationship-properties, project

class Scenario74RelationshipPropertyCrudTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  PRIORITY = 'priority'
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
  
  PLANNING_TREE = 'planning tree'
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_admin_user = users(:longbob)
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_74', :users => [@non_admin_user], :admins => [@project_admin_user, users(:admin)])
    setup_property_definitions(PRIORITY => ['high', LOW], SIZE => [1, 2, 4], STATUS => [NEW,  'close', OPEN], ITERATION => [1,2,3,4], OWNER  => ['a', 'b', 'c'])
    @type_story = setup_card_type(@project, STORY, :properties => [PRIORITY, SIZE, ITERATION, OWNER])
    @type_defect = setup_card_type(@project, DEFECT, :properties => [PRIORITY, STATUS, OWNER])
    @type_task = setup_card_type(@project, TASK, :properties => [PRIORITY, SIZE, ITERATION, STATUS, OWNER])
    @type_iteration = setup_card_type(@project, ITERATION_TYPE)
    @type_release = setup_card_type(@project, RELEASE)
    login_as_admin_user
    navigate_to_tree_configuration_management_page_for(@project)
  end
  
  def test_tree_configuration_gives_auto_suggestion_on_relationship_names
    click_create_new_card_tree_link
    type_tree_name(PLANNING_TREE)
    select_type_on_tree_node(0, RELEASE)
    assert_relationship_property_name_on_tree_configuration("#{PLANNING_TREE} - #{RELEASE}")
    select_type_on_tree_node(1, ITERATION_TYPE)
    add_new_card_type_node_to(1)
    assert_relationship_property_name_on_tree_configuration("#{PLANNING_TREE} - #{ITERATION_TYPE}", :relationship_propertys_number => 1)
  end
  
  # bug 5570
  def test_tree_configuration_gives_right_truncated_name_when_the_card_type_has_long_name
    long_name = "looooooooooooooooooooooooooooooooooooooong"
    truncated_name = "looooooooooooooooooooooooooooooooooooooo"
    type_with_long_name = setup_card_type(@project, long_name)
    click_create_new_card_tree_link
    type_tree_name(PLANNING_TREE)
    select_type_on_tree_node(0, long_name)
    assert_relationship_property_name_on_tree_configuration(truncated_name)
  end
  
  def test_renaming_relationship_property_should_retain_the_changes_on_adding_new_leaf_node
    create_and_configure_new_card_tree(@project, :name => PLANNING_TREE, :types => [RELEASE, ITERATION_TYPE, STORY], :relationship_names => ["abc", "abc"])
    assert_error_message_without_html_content("Relationship name abc is not unique")
  end
  
  def test_should_throw_error_when_relationship_property_name_already_exists_in_project
    create_and_configure_new_card_tree(@project, :name => PLANNING_TREE, :types => [RELEASE, ITERATION_TYPE], :relationship_names => [STATUS])
    @browser.assert_text_present("Name has already been taken")
  end
  
  def test_should_not_allow_empty_relationship_property_name
    create_and_configure_new_card_tree(@project, :name => PLANNING_TREE, :types => [RELEASE, ITERATION_TYPE], :relationship_names => [''])
    assert_error_message("Relationship names cannot be blank")
    assert_relationship_property_name_on_tree_configuration("")
    assert_error_box_present_for_relationship_property
  end
  
  def test_cannot_create_relationship_properties_with_names_that_are_used_as_predefined_card_properties
    predefined_properties = ['number', 'name', 'description', 'type', 'created by', 'modified by']
    variations_of_modified_by = ['modified-by', 'modified_by', 'modified:by']
    variations_of_created_by = ['created_by', 'created_by', 'created.by']
    predefined_properties = predefined_properties + variations_of_created_by + variations_of_modified_by

    click_create_new_card_tree_link
    type_tree_name(PLANNING_TREE)
    select_type_on_tree_node(0, RELEASE)
    select_type_on_tree_node(1, ITERATION_TYPE)
    
    predefined_properties.each {|relationship_property_name| assert_tree_configuraiton_not_created(relationship_property_name)}
    predefined_properties.each {|relationship_property_name| assert_tree_configuraiton_not_created(relationship_property_name.capitalize)}
    predefined_properties.each {|relationship_property_name| assert_tree_configuraiton_not_created(relationship_property_name.upcase)}
  end
  
  def test_invalid_chars_in_relationship_property_name_display_error_message
    relationship_names_with_special_chars = ['relation#ship', '5465[^&&)', '#2345', 'relation=ship']
    click_create_new_card_tree_link
    type_tree_name(PLANNING_TREE)
    select_type_on_tree_node(0, RELEASE)
    select_type_on_tree_node(1, ITERATION_TYPE)
    relationship_names_with_special_chars.each {|relationship_property_name| assert_tree_configuraiton_not_created(relationship_property_name, "Name should not contain '&', '=', '#', '\"', ';', '[' and ']' characters")}
  end
  
  def test_on_removing_a_level_and_saving_tree_show_warning_about_deleting_relationship_property
    tree = create_and_configure_new_card_tree(@project, :name => PLANNING_TREE, :types => [RELEASE, ITERATION_TYPE, STORY], :relationship_names => ["rel-#{RELEASE}", "rel-#{ITERATION_TYPE}"])
    click_on_configure_tree_for(@project, tree)
    remove_card_type_node_from_tree(1)
    click_save_link
    assert_warning_messages_on_tree_node_remove(ITERATION_TYPE, "rel-#{ITERATION_TYPE}")
  end
  
  def test_auto_suggestions_should_not_be_given_on_existing_relationship_properties_on_tree_edit
    tree1 = create_and_configure_new_card_tree(@project, :name => PLANNING_TREE, :types => [RELEASE, ITERATION_TYPE, STORY])
    navigate_to_tree_configuration_for(@project, tree1)
    select_type_on_tree_node(0, TASK)
    assert_relationship_property_name_on_tree_configuration("#{tree1.name} - #{RELEASE}")
    assert_relationship_property_name_on_tree_configuration("#{tree1.name} - #{ITERATION_TYPE}", :relationship_propertys_number => 1)

    tree2 = create_and_configure_new_card_tree(@project, :name => 'PLANNING_TREE2', :types => [RELEASE, ITERATION_TYPE, STORY], :relationship_names => ["a", "b"])
    navigate_to_tree_configuration_for(@project, tree2)
    select_type_on_tree_node(0, TASK)
    assert_relationship_property_name_on_tree_configuration("a")
    assert_relationship_property_name_on_tree_configuration("b", :relationship_propertys_number => 1)
  end
  
  def test_relationship_name_cannot_be_more_than_255_cards
    long_name = "this is too long namethis is too long namethis is too long namethis is too long namethis is too long namethis is too long namethis is too long namethis is too long namethis is too long namethis is too long namethis is too long namethis is too long name yea"
    tree = create_and_configure_new_card_tree(@project, :name => PLANNING_TREE, :types => [RELEASE, ITERATION_TYPE, STORY], :relationship_names => [long_name, "rel-#{RELEASE}"])
    assert_error_message('Relationship this is too long namet... has errors:')
    @browser.assert_text_present('Name is too long (maximum is 40 characters)')
  end
  
  # bug 3497
  def test_can_rename_relationship_property_by_only_changing_case
    relationship_property_name = 'story breakdown story'
    new_name_for_relationship_property_that_differs_only_in_case = relationship_property_name.upcase
    tree = create_and_configure_new_card_tree(@project, :name => 'story breakdown', :types => [STORY, TASK], :relationship_names => [relationship_property_name])
    story_one = create_card!(:name => 'story one', :card_type => STORY)
    project_variable = setup_project_variable(@project, :name => 'plv', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_story, :value => story_one,:properties => [relationship_property_name])
    rename_relationship_property(@project, tree, relationship_property_name, new_name_for_relationship_property_that_differs_only_in_case)
    assert_notice_message('Card tree was successfully updated.')
    assert_relationship_property_name_on_tree_configuration(new_name_for_relationship_property_that_differs_only_in_case)
    open_project_variable_for_edit(@project, project_variable)
    assert_project_variable_data_type_selected(ProjectVariable::CARD_DATA_TYPE)
    assert_card_type_selected_for_project_variable(@project, STORY)
    assert_value_for_project_variable(@project, project_variable, story_one)
    assert_properties_selected_for_project_variable(@project, new_name_for_relationship_property_that_differs_only_in_case)
  end
  
  # bug 3227
  def test_suggestion_of_relationship_property_names_works_when_changing_card_types
    click_create_new_card_tree_link
    type_tree_name('plan')
    
    select_type_on_tree_node(0, RELEASE)
    select_type_on_tree_node(1, ITERATION_TYPE)
    add_new_card_type_node_to(1)
    select_type_on_tree_node(2, TASK)
    
    assert_relationship_property_name_on_tree_configuration("plan - #{RELEASE}", :relationship_propertys_number => 0)
    assert_relationship_property_name_on_tree_configuration("plan - #{ITERATION_TYPE}", :relationship_propertys_number => 1)
    
    select_type_on_tree_node(1, STORY)
    assert_relationship_property_name_on_tree_configuration("plan - #{STORY}", :relationship_propertys_number => 1)
  end
  
  # bug 3193
  def test_relationship_property_names_are_changed_properly_even_after_new_node_added
    click_create_new_card_tree_link
    
    select_type_on_tree_node(0, RELEASE)
    assert_relationship_property_name_on_tree_configuration("#{RELEASE}", :relationship_propertys_number => 0)
    
    select_type_on_tree_node(1, ITERATION_TYPE)
    add_new_card_type_node_to(1)
    assert_relationship_property_name_on_tree_configuration("#{ITERATION_TYPE} 1", :relationship_propertys_number => 1)
    
    select_type_on_tree_node(1, TASK)
    assert_relationship_property_name_on_tree_configuration("#{TASK}", :relationship_propertys_number => 1)
  end
  
  # bug 4054
  def test_suggestion_of_relationship_property_names_does_not_make_duplicates_when_creating_two_nodes_from_the_same_node
    click_create_new_card_tree_link
    type_tree_name('plan')
    select_type_on_tree_node(1, ITERATION_TYPE)
    add_new_card_type_node_to(1)
    add_new_card_type_node_to(1)
    
    assert_relationship_property_name_on_tree_configuration("plan - #{ITERATION_TYPE}", :relationship_propertys_number => 1)
    assert_relationship_property_name_on_tree_configuration("", :relationship_propertys_number => 2)
  end
  
  # bug 11098
  def test_should_be_able_to_view_all_columns_on_card_list_view
    # The order of the creation of these 3 properties is important to reproduce the bug
    card_pd_1 = create_property_definition_for(@project, 'bug', :type => 'card')
    card_pd_1.update_attributes(:name => 'bug_11098_card_pd')

    user_pd = create_property_definition_for(@project, 'bug', :type => 'user')
    user_pd.update_attributes(:name => 'bug_11098_user_pd')

    card_pd_2 = create_property_definition_for(@project, 'bug', :type => 'card')

    create_card!(:name => 'card', :card_type => @project.card_types.first)
    navigate_to_card_list_for(@project)
    add_all_columns
    assert_column_present_for('bug_11098_card_pd', 'bug_11098_user_pd', 'bug_11098')
  end
end
