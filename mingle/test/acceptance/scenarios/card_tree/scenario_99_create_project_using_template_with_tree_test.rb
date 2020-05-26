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

#Tags: tree-usage, template, project
class Scenario99CreateProjectUsingTemplateWithTreeTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  STATUS = 'status'
  NEW = 'new'
  OPEN = 'open'
  USER_PROPERTY = 'owner'
  DATE_PROPERTY = 'closedOn'
  FREE_TEXT_PROPERTY = 'resolution'
  SIZE = 'Size'
  BLANK = ''
  NOT_SET = '(not set)'
  ANY = '(any)'

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
    @project = create_project(:prefix => 'scenario_99', :admins => [@project_admin], :users => [@project_member])
    setup_property_definitions(STATUS => [NEW, OPEN])
    setup_user_definition(USER_PROPERTY)
    setup_text_property_definition(FREE_TEXT_PROPERTY)
    setup_date_property_definition(DATE_PROPERTY)
    setup_numeric_property_definition(SIZE, [2, 4])
    @type_story = setup_card_type(@project, STORY, :properties => [STATUS, SIZE, FREE_TEXT_PROPERTY, USER_PROPERTY])
    @type_iteration = setup_card_type(@project, ITERATION, :properties => [STATUS])
    @type_release = setup_card_type(@project, RELEASE)
    login_as_admin_user
    @release1 = create_card!(:name => 'release 1', :description => "super plan", :card_type => RELEASE)
    @release2 = create_card!(:name => 'release 2', :card_type => RELEASE)
    @iteration1 = create_card!(:name => 'iteration 1', :card_type => ITERATION)
    @iteration2 = create_card!(:name => 'iteration 2', :card_type => ITERATION)
    @story1 = create_card!(:name => 'story 1', :card_type => STORY)
    @story2 = create_card!(:name => 'story 2', :card_type => STORY)

    @planning_tree = setup_tree(@project, PLANNING_TREE, :types => [@type_release, @type_iteration, @type_story], :relationship_names => [RELEASE_PROPERTY, ITERATION_PROPERTY])
    add_card_to_tree(@planning_tree, @release1)
    @project_variable = setup_project_variable(@project, :name => "current release", :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_release, :value => @release1, :properties => [RELEASE_PROPERTY])

  end

  def test_project_variables_gets_in_as_saved_views_through_templates
    add_card_to_tree(@planning_tree, @iteration1, @release1)
    navigate_to_card_list_for(@project)
    url = "cards/tree?tab=All&tf_Release[]=[#{RELEASE_PROPERTY}][is][(#{@project_variable.name})]&tree_name=#{@planning_tree.name}"
    set_filter_by_url(@project, url)
    current_release_saved_view = create_card_list_view_for(@project, 'current release')

    create_template_for(@project)
    project_template = Project.find_by_identifier("#{@project.name}_template")
    created_project = create_new_project('testing', :template_identifier => project_template.identifier)
    open_saved_view(current_release_saved_view.name)
    imported_type_release = created_project.card_types.find_by_name(@type_release.name)
    assert_properties_present_on_card_tree_filter(imported_type_release, 0, RELEASE_PROPERTY => "(#{@project_variable.name})")
  end

  def test_project_variable_gets_set_to_not_set_when_importing_from_template
    add_card_to_tree(@planning_tree, @iteration1, @release1)
    navigate_to_card_list_for(@project)
    url_with_tree_selected = "cards/tree?tab=All&tf_Release[]=[#{RELEASE_PROPERTY}][is][(#{@project_variable.name})]&tree_name=#{@planning_tree.name}"
    url_without_tree_selected = "cards/list?&filters[]=[Type][is][#{ITERATION}]&filters[]=[#{RELEASE_PROPERTY}][is][(#{@project_variable.name})]"
    set_filter_by_url(@project, url_with_tree_selected)
    current_release_with_tree_selected = create_card_list_view_for(@project, 'current_release_with_tree_selected')
    set_filter_by_url(@project, url_without_tree_selected)
    current_release_without_tree_selected = create_card_list_view_for(@project, 'crt_rel_without_tree_selected')

    create_template_for(@project)
    project_template = Project.find_by_identifier("#{@project.name}_template")
    project_created_from_template = create_new_project_from_template('testing', project_template.identifier)

    open_saved_view(current_release_with_tree_selected.name)

    imported_type_release = project_created_from_template.card_types.find_by_name(@type_release.name)
    assert_properties_present_on_card_tree_filter(imported_type_release, 0, RELEASE_PROPERTY => "(#{@project_variable.name})")

    navigate_to_card_list_for(project_created_from_template)
    open_saved_view(current_release_without_tree_selected.name)
    assert_filter_set_for(1, RELEASE_PROPERTY => "(#{@project_variable.name})")

    open_project_variable_for_edit(project_created_from_template, @project_variable.name)
    assert_value_for_project_variable(project_created_from_template, @project_variable.name, NOT_SET)
  end

  def test_relationship_property_used_in_filters_for_favorites_get_deleted_when_creating_project_from_template
    add_card_to_tree(@planning_tree, @iteration1, @release1)
    navigate_to_card_list_for(@project)
    url_with_tree_selected = "cards/tree?tab=All&tf_Release[]=[#{RELEASE_PROPERTY}][is][#{@release1.number}]&tree_name=#{@planning_tree.name}"
    url_without_tree_selected = "cards/list?&filters[]=[Type][is][#{ITERATION}]&filters[]=[#{RELEASE_PROPERTY}][is][#{@release1.number}]"
    set_filter_by_url(@project, url_with_tree_selected)
    filter_relationship_property_with_tree_selected = create_card_list_view_for(@project, 'crt_rel_with_tree_selected')
    set_filter_by_url(@project, url_without_tree_selected)
    filter_relationship_property_without_tree_selected = create_card_list_view_for(@project, 'crt_rel_without_tree_selected')

    create_template_for(@project)
    project_template = Project.find_by_identifier("#{@project.name}_template")
    project_created_from_template = create_new_project_from_template('testing', project_template.identifier)

    navigate_to_favorites_management_page_for(project_created_from_template)
    assert_favorites_not_present_on_management_page([filter_relationship_property_with_tree_selected, filter_relationship_property_without_tree_selected])
  end

  def test_transitions_using_relationship_properties_in_project_created_from_template
    add_card_to_tree(@planning_tree, @iteration1, @release1)
    transition_using_relationship_property = create_transition_for(@project, 'my transition', :type => ITERATION, :required_properties => {RELEASE_PROPERTY => card_number_and_name(@release1)}, :set_properties => {RELEASE_PROPERTY => card_number_and_name(@release2)})

    create_template_for(@project)
    project_template = Project.find_by_identifier("#{@project.name}_template")
    project_created_from_template = create_new_project_from_template('testing', project_template.identifier)
    release_prop = project_created_from_template.find_property_definition_or_nil(RELEASE_PROPERTY, :with_hidden => true)
    open_transition_for_edit(project_created_from_template, transition_using_relationship_property.name)
    assert_requires_property(release_prop => ANY)
    assert_sets_property(release_prop => NOT_SET)
  end

  def test_card_defaults_using_relationship_property_should_be_set_to_not_set_on_project_created_from_template
    add_card_to_tree(@planning_tree, @iteration1, @release1)
    navigate_to_card_type_management_for(@project)
    set_property_defaults_and_save_default_for(@project, @type_iteration.name, :properties => {RELEASE_PROPERTY => @release1}, :description => "h3. Iteration details")
    assert_notice_message("Defaults for card type #{@type_iteration.name} were successfully updated")

    create_template_for(@project)
    project_template = Project.find_by_identifier("#{@project.name}_template")
    project_created_from_template = create_new_project_from_template('testing', project_template.identifier)
    open_edit_defaults_page_for(project_created_from_template, @type_iteration.name)
    assert_property_set_on_card_defaults(project_created_from_template, RELEASE_PROPERTY, NOT_SET)
  end

end
