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

# Tags: tree-usage, transitions, properties, project-variable
class Scenario82RelPropertiesInTransitionsTest < ActiveSupport::TestCase

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
    @project = create_project(:prefix => 'scenario_82', :admins => [@project_admin], :users => [@project_member])
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
    add_card_to_tree(@planning_tree, @release1)
  end

  def test_deleting_plv_that_is_used_in_transitions_deletes_transition_that_sets_relationship_property_to_that_plv
    project_variable_name = 'current release'
    project_variable = setup_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_release, :value => @release1, :properties => [RELEASE_PROPERTY])
    transition_setting_plv = create_transition_for(@project, 'setting using relationship plv', :type => ITERATION, :set_properties => {RELEASE_PROPERTY => plv_display_name(project_variable_name)})
    assert_transition_present_for(@project, transition_setting_plv)
    navigate_to_project_variable_management_page_for(@project)
    delete_project_variable(@project, project_variable_name)
    @browser.assert_text_present("The following 1 transition will be deleted: #{transition_setting_plv.name}")
    click_continue_to_delete_link
    assert_project_variable_not_present_on_property_management_page(project_variable_name)
    @browser.assert_text_present("There are currently no project variables to list. You can create a new project variable from the action bar.")
    navigate_to_transition_management_for(@project)
    assert_transition_not_present_for(@project, transition_setting_plv)
  end

  def test_deleting_plv_that_is_used_in_transitions_deletes_transition_that_requires_relationship_property_set_to_that_plv
    project_variable_name = 'current iteration'
    project_variable = setup_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_iteration, :value => @iteration1, :properties => [ITERATION_PROPERTY])
    transition_requiring_plv = create_transition_for(@project, 'requiring set to relationship plv', :type => STORY, :required_properties => {ITERATION_PROPERTY => plv_display_name(project_variable_name)}, :set_properties => {STATUS => NEW})
    navigate_to_transition_management_for(@project)
    assert_transition_present_for(@project, transition_requiring_plv)
    navigate_to_project_variable_management_page_for(@project)
    delete_project_variable(@project, project_variable_name)
    @browser.assert_text_present("The following 1 transition will be deleted: #{transition_requiring_plv.name}")
    click_continue_to_delete_link
    assert_project_variable_not_present_on_property_management_page(project_variable_name)
    @browser.assert_text_present("There are currently no project variables to list. You can create a new project variable from the action bar.")
    navigate_to_transition_management_for(@project)
    assert_transition_not_present_for(@project, transition_requiring_plv)
  end

  def test_renaming_plv_that_is_used_in_transition_updates_plv_name_in_transition
    project_variable_name = 'current iteration'
    new_name_for_project_variable = 'FOO !'
    project_variable = setup_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_iteration, :value => @iteration1, :properties => [ITERATION_PROPERTY])
    transition_setting_plv = create_transition_for(@project, 'setting using relationship plv', :type => STORY, :set_properties => {ITERATION_PROPERTY => plv_display_name(project_variable_name)})
    transition_requiring_plv = create_transition_for(@project, 'requiring set to relationship plv', :type => STORY, :required_properties => {ITERATION_PROPERTY => plv_display_name(project_variable_name)}, :set_properties => {STATUS => NEW})
    navigate_to_transition_management_for(@project)
    assert_transition_present_for(@project, transition_setting_plv)
    assert_transition_present_for(@project, transition_requiring_plv)
    edit_project_variable(@project, project_variable, :new_name => new_name_for_project_variable)
    assert_notice_message("Project variable #{new_name_for_project_variable} was successfully updated.")
    navigate_to_transition_management_for(@project)
    assert_transition_present_for(@project, transition_setting_plv)
    assert_transition_present_for(@project, transition_requiring_plv)
    open_transition_for_edit(@project, transition_setting_plv)
    assert_sets_property(ITERATION_PROPERTY => plv_display_name(new_name_for_project_variable))
    open_transition_for_edit(@project, transition_requiring_plv)
    assert_requires_property(ITERATION_PROPERTY => plv_display_name(new_name_for_project_variable))
  end

  def test_changing_data_type_of_plv_that_is_used_in_transition_set_deletes_transition
    project_variable_name = 'current release'
    project_variable = setup_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_release, :value => @release1, :properties => [RELEASE_PROPERTY])
    transition_setting_plv = create_transition_for(@project, 'setting using relationship plv', :type => ITERATION, :set_properties => {RELEASE_PROPERTY => plv_display_name(project_variable_name)})
    assert_transition_present_for(@project, transition_setting_plv)
    new_data_type = ProjectVariable::STRING_DATA_TYPE
    edit_project_variable(@project, project_variable, :new_data_type => new_data_type)
    @browser.assert_text_present("The following 1 transition will be deleted: #{transition_setting_plv.name}")
    click_continue_to_update
    assert_notice_message("Project variable #{project_variable_name} was successfully updated.")
    assert_project_variable_present_on_property_management_page(project_variable_name)
    assert_card_value_not_present_on_property_management_page(@release1)
    open_project_variable_for_edit(@project, project_variable)
    assert_project_variable_data_type_selected(new_data_type)
    assert_properties_not_present_for_association_to_project_variable(@project, RELEASE_PROPERTY)
    navigate_to_transition_management_for(@project)
    assert_transition_not_present_for(@project, transition_setting_plv)
  end

  def test_changing_data_type_of_plv_that_is_used_in_transition_require_deletes_transition
    project_variable_name = 'current release'
    project_variable = setup_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_release, :value => @release1, :properties => [RELEASE_PROPERTY])
    transition_requiring_plv = create_transition_for(@project, 'requiring set to relationship plv', :type => STORY, :required_properties => {RELEASE_PROPERTY => plv_display_name(project_variable_name)}, :set_properties => {STATUS => NEW})
    assert_transition_present_for(@project, transition_requiring_plv)
    new_data_type = ProjectVariable::NUMERIC_DATA_TYPE
    edit_project_variable(@project, project_variable, :new_data_type => new_data_type)
    @browser.assert_text_present("The following 1 transition will be deleted: #{transition_requiring_plv.name}")
    click_continue_to_update
    assert_notice_message("Project variable #{project_variable_name} was successfully updated.")
    assert_project_variable_present_on_property_management_page(project_variable_name)
    assert_card_value_not_present_on_property_management_page(@release1)
    open_project_variable_for_edit(@project, project_variable)
    assert_project_variable_data_type_selected(new_data_type)
    assert_properties_not_present_for_association_to_project_variable(@project, RELEASE_PROPERTY)
    navigate_to_transition_management_for(@project)
    assert_transition_not_present_for(@project, transition_requiring_plv)
  end

  def test_create_from_template_maintains_transitions_using_relationship_property_plvs
    project_variable_name = 'current release'
    project_variable = setup_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_release, :value => @release1, :properties => [RELEASE_PROPERTY])
    transition_setting_plv_name = 'setting using relationship plv'
    transition_setting_plv = create_transition_for(@project, transition_setting_plv_name, :type => ITERATION, :set_properties => {RELEASE_PROPERTY => plv_display_name(project_variable_name)})
    transition_requiring_plv_name = 'requiring set to relationship plv'
    transition_requiring_plv = create_transition_for(@project, transition_requiring_plv_name, :type => STORY, :required_properties => {RELEASE_PROPERTY => plv_display_name(project_variable_name)}, :set_properties => {STATUS => NEW})
    create_template_for(@project)
    project_template = Project.find_by_identifier("#{@project.name}_template")
    project_template.activate
    new_project_name = 'created_from_template'
    create_new_project(new_project_name, :template_identifier => project_template.identifier, :exclude_cards => true)
    project_created_from_template = Project.find_by_identifier(new_project_name)
    project_created_from_template.activate

    navigate_to_project_variable_management_page_for(new_project_name)
    assert_project_variable_present_on_property_management_page(project_variable_name)
    assert_card_value_not_present_on_property_management_page(@release1)
    open_project_variable_for_edit(new_project_name, project_variable_name)
    assert_project_variable_data_type_selected(ProjectVariable::CARD_DATA_TYPE)
    assert_value_for_project_variable(new_project_name, project_variable_name, NOT_SET)
    assert_properties_selected_for_project_variable(new_project_name, RELEASE_PROPERTY)

    navigate_to_transition_management_for(new_project_name)
    assert_transition_present_for(new_project_name, transition_setting_plv_name)
    open_transition_for_edit(new_project_name, transition_setting_plv_name)
    assert_sets_property(RELEASE_PROPERTY => plv_display_name(project_variable_name))

    navigate_to_transition_management_for(new_project_name)
    assert_transition_present_for(new_project_name, transition_requiring_plv_name)
    open_transition_for_edit(new_project_name, transition_requiring_plv_name)
    assert_sets_property(STATUS => NEW)
    assert_requires_property(RELEASE_PROPERTY => plv_display_name(project_variable_name))
  end

  def test_using_plv_in_transition_to_set_relationship_property_value
    project_variable_name = 'current release'
    project_variable = setup_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_release, :value => @release1, :properties => [RELEASE_PROPERTY])
    transition_setting_plv = create_transition_for(@project, 'setting using relationship plv', :type => ITERATION, :set_properties => {RELEASE_PROPERTY => plv_display_name(project_variable_name)})
    open_card(@project, @iteration1)
    click_transition_link_on_card(transition_setting_plv)
    @browser.run_once_history_generation
    open_card(@project, @iteration1)
    assert_history_for(:card, @iteration1.number).version(2).shows(:set_properties => {RELEASE_PROPERTY => card_number_and_name(@release1)})
    assert_history_for(:card, @iteration1.number).version(3).not_present
    assert_properties_set_on_card_show(RELEASE_PROPERTY => @release1)
  end

  def test_using_plv_in_transition_to_require_relationship_property_value
    story_not_in_tree = create_card!(:name => 'story not in tree', :card_type => STORY)
    story_assigned_to_release = create_card!(:name => 'story assigned to release in tree', :card_type => STORY)
    add_card_to_tree(@planning_tree, story_assigned_to_release, @release1)
    release_project_variable = setup_project_variable(@project, :name => 'current release', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_release, :value => @release1, :properties => [RELEASE_PROPERTY])
    transition_requiring_card_to_be_assigned_to_release = create_transition_for(@project, 'requiring card plv', :type => STORY,
      :required_properties => {RELEASE_PROPERTY => plv_display_name(release_project_variable.name)}, :set_properties => {STATUS => NEW})

    open_card(@project, story_not_in_tree.number)
    assert_transition_not_present_on_card(transition_requiring_card_to_be_assigned_to_release)

    open_card(@project, story_assigned_to_release)
    click_transition_link_on_card(transition_requiring_card_to_be_assigned_to_release)

    @browser.run_once_history_generation
    open_card(@project, story_assigned_to_release)

    assert_history_for(:card, story_assigned_to_release.number).version(3).shows(:set_properties => {STATUS => NEW})
    assert_history_for(:card, story_assigned_to_release.number).version(3).does_not_show(:set_properties => {RELEASE_PROPERTY => NOT_SET})
    assert_history_for(:card, story_assigned_to_release.number).version(4).not_present
    assert_properties_set_on_card_show(RELEASE_PROPERTY => @release1)
  end

  # bug 3398
  def test_transition_setting_value_of_rel_property_sets_correct_value
    add_card_to_tree(@planning_tree, @iteration1)
    new_name_for_release2_card = 'r 2000'
    release_project_variable = setup_project_variable(@project, :name => 'current release', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_release, :value => @release2, :properties => [RELEASE_PROPERTY])
    transition = create_transition_for(@project, 'going to rename the release card', :type => STORY, :set_properties => {RELEASE_PROPERTY => card_number_and_name(@release2)})
    open_card(@project, @release2)
    edit_card(:name => new_name_for_release2_card)
    open_card(@project, @story1)
    click_transition_link_on_card(transition)
    assert_properties_set_on_card_show(RELEASE_PROPERTY => "##{@release2.number} #{new_name_for_release2_card}")
  end

  # def test_reconfiguring_tree
  #     type_task = setup_card_type(@project, 'task')
  #     story_property = 'story breakdown - story'
  #     story_breakdown_tree = setup_tree(@project, 'story breakdown', :types => [@type_story, type_task], :relationship_names => [story_property])
  #     project_variable = setup_project_variable(@project, :name => 'current story', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_story, :value => @story1, :properties => [story_property])
  #     open_configure_a_tree_through_url(@project, story_breakdown_tree)
  #     remove_card_type_tree(@project, story_breakdown_tree, @story_type)
  #   end
end
