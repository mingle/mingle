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

# Tags: tree-usage, properties, project-variable
class Scenario81ProjectVariableWithRelationshipPropertiesCrudTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  SIZE = 'size'
  STATUS = 'status'
  NEW = 'new'
  OPEN = 'open'
  BLANK = ''
  NOT_SET = '(not set)'
  DEPENDENCY= 'dependency'

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
    @project = create_project(:prefix => 'scenario_81', :admins => [@project_admin], :users => [@project_member])
    setup_property_definitions(STATUS => [NEW, OPEN])
    setup_numeric_property_definition(SIZE, [2, 4])
    @type_story = setup_card_type(@project, STORY, :properties => [STATUS, SIZE])
    @type_iteration = setup_card_type(@project, ITERATION)
    @type_release = setup_card_type(@project, RELEASE)
    login_as_proj_admin_user
    @release1 = create_card!(:name => 'release 1', :description => "super plan", :card_type => RELEASE)
    @release2 = create_card!(:name => 'release 2', :card_type => RELEASE)
    @iteration1 = create_card!(:name => 'iteration 1', :card_type => ITERATION)
    @iteration2 = create_card!(:name => 'iteration 2', :card_type => ITERATION)
    @story1 = create_card!(:name => 'story 1', :card_type => STORY)
    @planning_tree = setup_tree(@project, PLANNING_TREE, :types => [@type_release, @type_iteration, @type_story], :relationship_names => [RELEASE_PROPERTY, ITERATION_PROPERTY])
  end

  #story 4933
  def test_user_can_set_tree_relationship_with_available_card_type_plv_on_card_show_or_card_edit
    story2 = create_card!(:name => 'story 2', :card_type => STORY)
    card_type_plv_name = 'card type plv - iteration'
    card_type_plv_value = '#3 iteration 1'
    iteration_plv = setup_project_variable(@project, :name => card_type_plv_name, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_iteration, :value => @iteration1, :properties => [ITERATION_PROPERTY])

    open_card(@project, @story1)
    set_properties_on_card_show(ITERATION_PROPERTY => "(#{card_type_plv_name})")
    assert_properties_set_on_card_show(ITERATION_PROPERTY => card_type_plv_value)

    open_card_for_edit(@project, story2)
    set_properties_in_card_edit(ITERATION_PROPERTY => "(#{card_type_plv_name})")
    assert_edit_property_set(ITERATION_PROPERTY, "(#{card_type_plv_name})")
    save_card
    assert_properties_set_on_card_show(ITERATION_PROPERTY => card_type_plv_value)

    delete_project_variable(@project, card_type_plv_name)
    click_continue_to_delete
    assert_notice_message("Project variable #{card_type_plv_name} was successfully deleted")

    open_card(@project, @story1)
    assert_properties_set_on_card_show(ITERATION_PROPERTY => card_type_plv_value)
  end

  #bug 3904
  def test_card_type_of_cards_that_are_not_value_of_project_variable_should_be_able_to_be_changed
    add_card_to_tree(@planning_tree, @release1)
    add_card_to_tree(@planning_tree, @release2)
    add_card_to_tree(@planning_tree, @iteration1, @release1)
    add_card_to_tree(@planning_tree, @story1, @iteration1)
    navigate_to_tree_view_for(@project, @planning_tree.name)
    switch_to_list_view
    project_variable = setup_project_variable(@project, :name => 'current release', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_release, :value => @release1, :properties => [RELEASE_PROPERTY])
    click_exclude_card_type_checkbox(@type_story)
    select_all
    uncheck_card_in_list_view(@release1)
    click_edit_properties_button
    set_card_type_on_bulk_edit(@type_iteration.name)
    assert_notice_message('2 cards updated.')
  end

  def test_can_create_plv_using_relationship_property
    project_variable_name = 'plv using relationship property'
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => RELEASE, :value => @release1, :properties => RELEASE_PROPERTY)
    assert_notice_message("Project variable #{project_variable_name} was successfully created.")
    assert_project_variable_present_on_property_management_page(project_variable_name)
    open_transition_create_page(@project)
    set_card_type_on_transitions_page(ITERATION)
    assert_set_property_does_have_value(@project, RELEASE_PROPERTY, plv_display_name(project_variable_name))
  end

  def test_deleting_tree_removes_relationship_property_from_plv_but_does_not_delete_plv
    project_variable = setup_project_variable(@project, :name => 'current iteration', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_iteration, :value => @iteration1, :properties => [ITERATION_PROPERTY])
    delete_tree_configuration_for(@project, @planning_tree)
    navigate_to_project_variable_management_page_for(@project)
    assert_project_variable_present_on_property_management_page(project_variable.name)
    open_project_variable_for_edit(@project, project_variable)
    assert_project_variable_name(project_variable.name)
    assert_property_not_present_in_property_table_on_plv_edit_page(ITERATION_PROPERTY)
    click_save_project_variable
    assert_on_project_variables_list_page_for(@project)
  end

  def test_deleting_tree_removes_relationship_property_from_plv_but_keeps_association_to_other_tree_relationship_properties
    iteration_breakdown_iteration_property = 'iteration breakdown iteration'
    iteration_breakdown_tree = setup_tree(@project, 'iteration breakdown', :types => [@type_iteration, @type_story], :relationship_names => [iteration_breakdown_iteration_property])
    project_variable = setup_project_variable(@project, :name => 'current iteration', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_iteration, :value => @iteration1, :properties => [ITERATION_PROPERTY, iteration_breakdown_iteration_property])
    delete_tree_configuration_for(@project, @planning_tree)
    navigate_to_project_variable_management_page_for(@project)
    assert_project_variable_present_on_property_management_page(project_variable.name)
    open_project_variable_for_edit(@project, project_variable)
    assert_project_variable_data_type_selected(ProjectVariable::CARD_DATA_TYPE)
    assert_card_type_selected_for_project_variable(@project, ITERATION)
    assert_value_for_project_variable(@project, project_variable, @iteration1)
    assert_property_not_present_in_property_table_on_plv_edit_page(ITERATION_PROPERTY)
    assert_properties_selected_for_project_variable(@project, iteration_breakdown_iteration_property)
  end

  # def test_card_data_type_option_disabled_when_project_has_no_trees
  #   delete_tree_configuration_for(@project, @planning_tree)
  #   open_project_variable_create_page_for(@project)
  #   assert_CARD_DATA_TYPE_is_disabled
  # end
  # make some changes because a new card property is introduced to Mingle

  def test_card_types_for_plvs_are_restricted_to_types_that_are_used_in_trees_and_not_the_bottom_most_type_in_the_tree
    card_type_not_in_a_tree = setup_card_type(@project, 'not in tree', :properties => [STATUS])
    @project.reload
    open_project_variable_create_page_for(@project)
    select_data_type(ProjectVariable::CARD_DATA_TYPE)
    assert_card_types_not_present_on_plv_create_edit_page(@project, card_type_not_in_a_tree, STORY)
    assert_card_types_present_on_plv_create_edit_page(@project, RELEASE, ITERATION)
  end

  def test_only_relationship_properties_that_correspond_to_selected_type_appear_as_options_in_table
    open_project_variable_create_page_for(@project)
    select_data_type(ProjectVariable::CARD_DATA_TYPE)
    select_card_type(@project, ITERATION)
    assert_properties_present_for_association_to_project_variable(@project, ITERATION_PROPERTY)
    assert_properties_not_present_for_association_to_project_variable(@project, RELEASE_PROPERTY)
  end

  def test_deleting_card_that_is_value_of_plv_changes_value_to_not_set
    project_variable = setup_project_variable(@project, :name => 'current iteration', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_iteration, :value => @iteration1, :properties => [ITERATION_PROPERTY])
    iteration1_card_display_value = card_number_and_name(@iteration1)
    open_project_variable_for_edit(@project, project_variable)
    assert_project_variable_data_type_selected(ProjectVariable::CARD_DATA_TYPE)
    assert_card_type_selected_for_project_variable(@project, ITERATION)
    assert_value_for_project_variable(@project, project_variable, @iteration1)
    assert_properties_selected_for_project_variable(@project, ITERATION_PROPERTY)
    navigate_to_project_variable_management_page_for(@project)
    assert_card_value_present_on_property_management_page(@iteration1)
    delete_card(@project, @iteration1)
    navigate_to_project_variable_management_page_for(@project)
    assert_card_value_not_present_on_property_management_page(iteration1_card_display_value)
    open_project_variable_for_edit(@project, project_variable)
    assert_project_variable_data_type_selected(ProjectVariable::CARD_DATA_TYPE)
    assert_card_type_selected_for_project_variable(@project, ITERATION)
    assert_properties_selected_for_project_variable(@project, ITERATION_PROPERTY)
    assert_value_for_project_variable(@project, project_variable, NOT_SET)
  end

  def test_renaming_card_that_is_value_of_plv_maintains_plv_configuration
    project_variable = setup_project_variable(@project, :name => 'current release', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_release, :value => @release1, :properties => [RELEASE_PROPERTY])
    add_card_to_tree(@planning_tree, @release1)
    open_project_variable_for_edit(@project, project_variable)
    assert_value_for_project_variable(@project, project_variable, @release1)
    open_card(@project, @release1)
    new_card_name = 'new FOO'
    edit_card(:name => new_card_name)
    assert_notice_message("Card ##{@release1.number} was successfully updated")
    assert_card_name_in_show(new_card_name)
    assert_card_in_tree(@project, @planning_tree, @release1)
    open_project_variable_for_edit(@project, project_variable)
    assert_project_variable_data_type_selected(ProjectVariable::CARD_DATA_TYPE)
    assert_card_type_selected_for_project_variable(@project, RELEASE)
    assert_value_for_project_variable(@project, project_variable, "##{@release1.number} #{new_card_name}")
    assert_properties_selected_for_project_variable(@project, RELEASE_PROPERTY)
  end

  def test_should_not_allow_change_of_card_type_for_card_that_is_used_as_value_for_plv
    card_that_switches_types = create_card!(:name => 'card whose type will change', :card_type => RELEASE)
    project_variable = setup_project_variable(@project, :name => 'current release', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_release, :value => card_that_switches_types, :properties => [RELEASE_PROPERTY])
    open_card(@project, card_that_switches_types)
    set_card_type_on_card_show(STORY)
    assert_error_message('Cannot change card type because card is being used as the value of project variable: (current release)', :escape => true)

    navigate_to_grid_view_for(@project, :group_by => "Type")
    @browser.wait_for_all_ajax_finished
    drag_and_drop_card_from_lane(card_that_switches_types.html_id, "Type", STORY)
    assert_error_message('Cannot change card type because card is being used as the value of project variable: (current release)', :escape => true)
  end


  def test_can_still_remove_card_from_tree_if_it_is_used_as_value_for_plv
    add_card_to_tree(@planning_tree, @release1)
    project_variable = setup_project_variable(@project, :name => 'current release', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_release, :value => @release1, :properties => [RELEASE_PROPERTY])
    remove_card_without_its_children_from_tree_for(@project, PLANNING_TREE, @release1)
    open_project_variable_for_edit(@project, project_variable)
    assert_project_variable_data_type_selected(ProjectVariable::CARD_DATA_TYPE)
    assert_card_type_selected_for_project_variable(@project, RELEASE)
    assert_value_for_project_variable(@project, project_variable, @release1)
    assert_properties_selected_for_project_variable(@project, RELEASE_PROPERTY)
  end

  def test_renaming_card_type_that_is_associated_to_plv_updates_correctly
    project_variable = setup_project_variable(@project, :name => 'current iteration', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_iteration, :value => @iteration1, :properties => [ITERATION_PROPERTY])
    open_project_variable_for_edit(@project, project_variable)
    assert_project_variable_data_type_selected(ProjectVariable::CARD_DATA_TYPE)
    assert_card_type_selected_for_project_variable(@project, ITERATION)
    open_edit_card_type_page(@project, ITERATION)
    new_card_type_name = 'new type name'
    edit_card_type_for_project(@project, ITERATION, :new_card_type_name => new_card_type_name)
    open_project_variable_for_edit(@project, project_variable)
    assert_project_variable_data_type_selected(ProjectVariable::CARD_DATA_TYPE)
    assert_card_type_selected_for_project_variable(@project, new_card_type_name)
    assert_value_for_project_variable(@project, project_variable, @iteration1)
  end

  def test_renaming_relationship_property_used_by_plv_maintains_association_to_plv
    project_variable = setup_project_variable(@project, :name => 'current release', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_release, :value => @release1, :properties => [RELEASE_PROPERTY])
    open_project_variable_for_edit(@project, project_variable)
    new_name_for_release_property = 'new FOO'
    rename_relationship_property(@project, @planning_tree, RELEASE_PROPERTY, new_name_for_release_property)
    assert_notice_message("Card tree was successfully updated.")
    open_project_variable_for_edit(@project, project_variable)
    assert_project_variable_data_type_selected(ProjectVariable::CARD_DATA_TYPE)
    assert_card_type_selected_for_project_variable(@project, RELEASE)
    assert_value_for_project_variable(@project, project_variable, @release1)
    assert_properties_selected_for_project_variable(@project, new_name_for_release_property)
  end

  def test_removing_card_type_from_tree_when_other_trees_use_card_type
    iteration_breakdown_tree_relationship_property = 'iteration breakdown - iteration'
    iteration_planning = setup_tree(@project, 'iteration breakdown', :types => [@type_iteration, @type_story], :relationship_names => [iteration_breakdown_tree_relationship_property])
    project_variable = setup_project_variable(@project, :name => 'current iteration', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_iteration, :value => @iteration1, :properties => [ITERATION_PROPERTY])
    open_configure_a_tree_through_url(@project, @planning_tree)
    remove_card_type_tree(@project, PLANNING_TREE, ITERATION)
    save_tree_permanently
    open_project_variable_for_edit(@project, project_variable)
    assert_project_variable_data_type_selected(ProjectVariable::CARD_DATA_TYPE)
    assert_card_type_selected_for_project_variable(@project, ITERATION)
    assert_value_for_project_variable(@project, project_variable, @iteration1)
    assert_property_not_present_in_property_table_on_plv_edit_page(ITERATION_PROPERTY)
    assert_properties_not_selected_for_project_variable(@project, iteration_breakdown_tree_relationship_property)
    click_save_project_variable
    assert_on_project_variables_list_page_for(@project)
  end

  def test_renaming_plv_updates_plv_management_page_and_maintains_plv_configuration
    project_variable = setup_project_variable(@project, :name => 'current iteration', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_iteration, :value => @iteration1, :properties => [ITERATION_PROPERTY])
    new_name_for_project_variable = 'iteration 1000'
    open_project_variable_for_edit(@project, project_variable)
    type_project_variable_name(new_name_for_project_variable)
    click_save_project_variable
    assert_project_variable_present_on_property_management_page(new_name_for_project_variable)
    assert_card_value_present_on_property_management_page(@iteration1)
    open_project_variable_for_edit(@project, project_variable)
    assert_project_variable_name(new_name_for_project_variable)
    assert_project_variable_data_type_selected(ProjectVariable::CARD_DATA_TYPE)
    assert_card_type_selected_for_project_variable(@project, ITERATION)
    assert_value_for_project_variable(@project, project_variable, @iteration1)
    assert_properties_selected_for_project_variable(@project, ITERATION_PROPERTY)
  end

  def test_deleting_plv_removes_it_from_plv_management_page
    project_variable_name = 'current iteration'
    project_variable = setup_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_iteration, :value => @iteration1, :properties => [ITERATION_PROPERTY])
    navigate_to_project_variable_management_page_for(@project)
    delete_project_variable(@project, project_variable_name)
    click_continue_to_delete
    assert_project_variable_not_present_on_property_management_page(project_variable_name)
    @browser.assert_text_present("There are currently no project variables to list. You can create a new project variable from the action bar.")
  end

  def test_create_from_template_maintains_plv_data_type_and_property_association_but_value_becomes_not_set
    login_as_mingle_admin
    project_variable_name = 'current release'
    project_variable = setup_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_release, :value => @release1, :properties => [RELEASE_PROPERTY])
    create_template_for(@project)
    project_template = Project.find_by_identifier("#{@project.name}_template")
    project_template.activate
    new_project_name = 'created_from_template'
    create_new_project_from_template(new_project_name, project_template.identifier)
    project_created_from_template = Project.find_by_identifier(new_project_name)
    project_created_from_template.activate

    navigate_to_project_variable_management_page_for(new_project_name)
    assert_project_variable_present_on_property_management_page(project_variable_name)
    assert_card_value_not_present_on_property_management_page(@release1)
    open_project_variable_for_edit(new_project_name, project_variable_name)
    assert_project_variable_data_type_selected(ProjectVariable::CARD_DATA_TYPE)
    assert_value_for_project_variable(new_project_name, project_variable_name, NOT_SET)
    assert_properties_selected_for_project_variable(new_project_name, RELEASE_PROPERTY)
  end

  def test_deleting_project_variable_deletes_transitions_that_use_project_variable
    login_as_mingle_admin
    project_variable_name = 'current release'
    project_variable = setup_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_release, :value => @release1, :properties => [RELEASE_PROPERTY])
    transition = create_transition_for(@project, 'trans using plv', :type => @type_iteration.name, :set_properties => {RELEASE_PROPERTY => plv_display_name(project_variable)})
    navigate_to_project_variable_management_page_for(@project)
    delete_project_variable(@project, project_variable.name)
    assert_info_box_light_message("The following 1 transition will be deleted: #{transition.name}.")
    click_on_continue_to_delete_link
    assert_notice_message("Project variable #{project_variable_name} was successfully deleted")
    assert_transition_not_present_for(@project, transition)
  end

  # bug 3253
  def test_renaming_card_that_is_value_of_relationship_property_updates_plv_page
    project_variable_name = 'current iteration'
    project_variable = setup_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_iteration, :value => @iteration1, :properties => [ITERATION_PROPERTY])
    new_name_for_card = 'iteration 1000'
    open_card(@project, @iteration1.number)
    edit_card(:name => new_name_for_card)
    open_project_variable_for_edit(@project, project_variable)
    assert_project_variable_name('current iteration')
    assert_project_variable_data_type_selected(ProjectVariable::CARD_DATA_TYPE)
    assert_card_type_selected_for_project_variable(@project, ITERATION)
    card_number_and_new_name = "##{@iteration1.number} #{new_name_for_card}"
    assert_value_for_project_variable(@project, project_variable, card_number_and_new_name)
    assert_properties_selected_for_project_variable(@project, ITERATION_PROPERTY)
    navigate_to_project_variable_management_page_for(@project)
    assert_project_variable_present_on_property_management_page(project_variable_name)
    assert_card_value_present_on_property_management_page(card_number_and_new_name) # bug 3251
  end

  # bug 3477
  def test_card_types_are_smart_sorted_on_plv_management_page
    epic = 'epic'
    task = 'task'
    type_epic = setup_card_type(@project, epic)
    type_task = setup_card_type(@project, task)
    another = setup_tree(@project, 'another tree', :types => [@type_release, type_epic, @type_story, type_task], :relationship_names => ['release property', 'iteration property', 'story property'])
    open_project_variable_create_page_for(@project)
    select_data_type(ProjectVariable::CARD_DATA_TYPE)
    assert_card_types_ordered_on_card_type_management_page(@project, epic, ITERATION, RELEASE, STORY)
  end

  # bug 3246
  def test_card_types_on_plv_create_page_escape_html
    name_with_html_tags = "foo <b>BAR</b>"
    same_name_without_html_tags = "foo BAR"
    type_with_html_in_name = setup_card_type(@project, name_with_html_tags, :properties => [STATUS])
    another = setup_tree(@project, 'another tree', :types => [type_with_html_in_name, @type_story], :relationship_names => ['does not matter'])
    open_project_variable_create_page_for(@project)
    select_data_type(ProjectVariable::CARD_DATA_TYPE)
    @browser.assert_element_matches("value_field_container", /#{name_with_html_tags}/)
    @browser.assert_element_does_not_match("value_field_container", /#{same_name_without_html_tags}/)
  end

  # bug 3648
  def test_can_change_data_type_of_existing_plv_to_card_data_type
    project_variable = setup_project_variable(@project, :name => 'future iteration', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '100', :properties => [SIZE])
    transition_setting_plv = create_transition_for(@project, 'setting plv', :type => STORY, :set_properties => {SIZE => plv_display_name(project_variable.name)})
    open_project_variable_for_edit(@project, project_variable)
    select_data_type(ProjectVariable::CARD_DATA_TYPE)
    select_card_type(@project, ITERATION)
    set_value(ProjectVariable::CARD_DATA_TYPE, @iteration1)
    click_save_project_variable
    @browser.assert_text_present("The following 1 transition will be deleted: #{transition_setting_plv.name}.")
    click_on_continue_to_update
    assert_successful_project_variable_update(project_variable)
    assert_card_value_present_on_property_management_page(@iteration1)
  end

  # bug 3479
  def test_cannot_change_the_card_type_of_card_that_is_also_the_value_of_project_variable
    project_variable = setup_project_variable(@project, :name => 'future iteration', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_iteration, :value => @iteration1, :properties => [ITERATION_PROPERTY])
    transition = create_transition_for(@project, 'setting plv', :type => STORY, :set_properties => {ITERATION_PROPERTY => plv_display_name(project_variable.name)})
    open_card(@project, @iteration1)
    set_card_type_on_card_show(RELEASE)
    assert_error_message_without_html_content_includes("Cannot change card type because card is being used as the value of project variable: (#{project_variable.name})")
    assert_history_for(:card, @iteration1.number).version(2).not_present
    assert_card_type_set_on_card_show(ITERATION)

    navigate_to_card_list_for(@project)
    check_cards_in_list_view(@iteration1)
    click_edit_properties_button
    set_bulk_properties(@project, 'Type' => RELEASE)
    assert_error_message_without_html_content_includes("Cannot change card type because card ##{@iteration1.number} is being used as the value of project variable: (#{project_variable.name})")
    open_card(@project, @iteration1)
    assert_history_for(:card, @iteration1.number).version(2).not_present
    assert_card_type_set_on_card_show(ITERATION)

    header_row = ['Number', 'Type']
    card_data = [[@iteration1.number, RELEASE]]
    navigate_to_card_list_for(@project)
    import(excel_copy_string(header_row, card_data))
    assert_error_message_without_html_content_includes("Importing complete, 0 rows, 0 updated, 0 created, 1 error.Error detail:Row 1: Validation failed: Cannot change card type because card is being used as the value of project variable: (#{project_variable.name})")
    open_card(@project, @iteration1)
    assert_history_for(:card, @iteration1.number).version(2).not_present
    assert_card_type_set_on_card_show(ITERATION)
  end

  # bug 4088
  def test_card_plv_still_useable_after_its_card_type_is_removed_from_tree
    project_variable = setup_project_variable(@project, :name => 'current iteration', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_iteration, :value => @iteration1, :properties => [ITERATION_PROPERTY])
    edit_card_tree_configuration(@project, PLANNING_TREE, :types => [RELEASE, STORY])
    open_project_variable_for_edit(@project, project_variable)
    click_save_project_variable
    assert_successful_project_variable_update(project_variable)
  end

  #bug 5093
  def test_available_properties_for_plvs_should_not_be_lost_when_updated_or_its_value_is_removed
    create_property_definition_for(@project, DEPENDENCY, :type => 'card')
    project_variable_name = 'plv using relationship property'
    project_variable=setup_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_iteration, :value => @iteration1, :properties => [DEPENDENCY, ITERATION_PROPERTY])
    open_project_variable_for_edit(@project, project_variable)
    select_card_type(@project, RELEASE)
    set_value(ProjectVariable::CARD_DATA_TYPE, @release1)
    assert_properties_selected_for_project_variable(@project, DEPENDENCY)
    assert_properties_not_selected_for_project_variable(@project, RELEASE_PROPERTY)
    click_save_project_variable
    assert_successful_project_variable_update(project_variable)
  end

  def login_as_mingle_admin
    logout
    login_as_admin_user
  end
end
