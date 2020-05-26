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

# Tags: scenario, properties, filters, project, card-selector, project-variable-usage
class Scenario84UsingProjectVariablesInFiltersTest < ActiveSupport::TestCase
  
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
    @project = create_project(:prefix => 'scenario_84', :admins => [@project_admin], :users => [@project_member])
    setup_property_definitions(STATUS => [NEW, OPEN])
    setup_user_definition(USER_PROPERTY)
    setup_text_property_definition(FREE_TEXT_PROPERTY)
    @date_property=setup_date_property_definition(DATE_PROPERTY)
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
    @planning_tree = setup_tree(@project, PLANNING_TREE, :types => [@type_release, @type_iteration, @type_story], :relationship_names => [RELEASE_PROPERTY, ITERATION_PROPERTY])
    add_card_to_tree(@planning_tree, @release1)
  end
  
  # bug 3487
  def test_saved_view_filtered_by_user_property_plv_survives_template_creation_and_project_creation_from_template
    project_variable_name = 'PM'
    project_variable = setup_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::USER_DATA_TYPE, :value => @project_member, :properties => [USER_PROPERTY])
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :type => STORY, USER_PROPERTY => plv_display_name(project_variable_name))
    assert_selected_value_for_the_filter(1, plv_display_name(project_variable_name))
    saved_view_name = 'plv view'
    create_card_list_view_for(@project, saved_view_name)
    
    create_template_for(@project)
    project_template = Project.find_by_identifier("#{@project.name}_template")
    project_template.activate
    new_project_name = 'created_from_template'
    create_new_project(new_project_name, :template_identifier => project_template.identifier)
    project_created_from_template = Project.find_by_identifier(new_project_name)
    project_created_from_template.activate
    
    navigate_to_favorites_management_page_for(project_template)
    assert_card_favorites_present_on_management_page(project_template, saved_view_name)
    navigate_to_card_list_for(project_template)
    # bug 3512
    open_saved_view(saved_view_name) 
    assert_selected_value_for_the_filter(1, plv_display_name(project_variable_name))
    
    navigate_to_favorites_management_page_for(project_created_from_template)
    assert_card_favorites_present_on_management_page(project_created_from_template, saved_view_name)
    navigate_to_card_list_for(project_template)
    open_saved_view(saved_view_name)
    assert_selected_value_for_the_filter(1, plv_display_name(project_variable_name))
  end
  
  # bug 3501
  def test_filtering_by_plv_maintains_plv_as_property_value_in_filter_widget
    user_plv = setup_project_variable(@project, :name => 'PM', :data_type => ProjectVariable::USER_DATA_TYPE, :value => @project_member, :properties => [USER_PROPERTY])
    card_plv = setup_project_variable(@project, :name => 'current release', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_release, :value => @release1, :properties => [RELEASE_PROPERTY])
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :type => STORY, USER_PROPERTY => plv_display_name(user_plv.name))
    assert_selected_value_for_the_filter(1, plv_display_name(user_plv.name))
    reset_view
    filter_card_list_by(@project, :type => STORY, RELEASE_PROPERTY => plv_display_name(card_plv.name))
    assert_selected_value_for_the_filter(1, plv_display_name(card_plv.name))
  end
  
  # bug 3503
  def test_can_create_saved_view_using_relationship_property_plv
    project_variable_name = 'current release'
    project_variable = setup_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_release, :value => @release1, :properties => [RELEASE_PROPERTY])
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :type => STORY, RELEASE_PROPERTY => plv_display_name(project_variable_name))
    assert_selected_value_for_the_filter(1, plv_display_name(project_variable_name))
    saved_view_name = 'plv view'
    saved_view = create_card_list_view_for(@project, saved_view_name)
    navigate_to_favorites_management_page_for(@project)
    assert_card_favorites_present_on_management_page(@project, saved_view_name)
  end
  
  # bug 3472
  def test_changing_plvs_data_type_deletes_saved_views_that_used_this_plv
    project_variable_name = 'plv'
    project_variable = setup_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::STRING_DATA_TYPE, :value => NEW, :properties => [STATUS])
    navigate_to_project_variable_management_page_for(@project)
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :type => STORY, STATUS => plv_display_name(project_variable_name))
    saved_view = create_card_list_view_for(@project, 'plv saved view')
    open_project_variable_for_edit(@project, project_variable_name)
    select_data_type(ProjectVariable::NUMERIC_DATA_TYPE)
    set_value(ProjectVariable::NUMERIC_DATA_TYPE, '1')
    click_save_project_variable
    @browser.assert_text_present("The following 1 team favorite will be deleted: #{saved_view.name}")
    click_on_continue_to_update
    assert_notice_message("Project variable #{project_variable_name} was successfully updated.")
    assert_project_variable_present_on_property_management_page(project_variable_name)
    navigate_to_favorites_management_page_for(@project)
    assert_favorites_not_present_on_management_page(@project, saved_view)
  end
  
  # bug 3474
  def test_removing_association_from_property_to_plv_that_is_used_in_filtered_favorite_deletes_favorite
    project_variable_name = 'plv'
    project_variable = setup_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '100', :properties => [SIZE])
    navigate_to_project_variable_management_page_for(@project)
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :type => STORY, SIZE => plv_display_name(project_variable_name))
    saved_view = create_card_list_view_for(@project, 'plv saved view')
    open_project_variable_for_edit(@project, project_variable_name)
    uncheck_properties_that_will_use_variable(@project, SIZE)
    click_save_project_variable
    @browser.assert_text_present("The following 1 team favorite will be deleted: #{saved_view.name}")
    click_on_continue_to_update
    assert_notice_message("Project variable #{project_variable_name} was successfully updated.")
    assert_project_variable_present_on_property_management_page(project_variable_name)
    navigate_to_favorites_management_page_for(@project)
    assert_favorites_not_present_on_management_page(@project, saved_view)
  end
  
  # Bug 7527
  def test_saving_project_settings_should_not_throw_mingle_sorry_when_there_is_a_saved_view_with_date_plv_in_filter
    date_type_plv_1_name = 'date type plv'
    date_type_plv_1_value = '01 Jan 2009'
    add_properties_for_card_type(@type_story, [@date_property])
    create_date_plv(@project, date_type_plv_1_name, date_type_plv_1_value, [@date_property])
    new_story1 = create_card!(:name => 'new_story1', :card_type => STORY, DATE_PROPERTY => "(#{date_type_plv_1_name})")
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :type => STORY, DATE_PROPERTY => "(#{date_type_plv_1_name})")
    saved_view = create_card_list_view_for(@project, 'story with date plv set to #{date_type_plv_1_value}')
    open_admin_edit_page_for(@project)
    click_save_link
    @browser.assert_text_present("Project was successfully updated.")
  end
end
