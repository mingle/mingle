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

# Tags: scenario, project, template, #1460, #1502, #1715
class Scenario39ProjectTemplateTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  UPDATE_SUCCESSFUL_MESSAGE = 'Project was successfully updated.'
  PRIORITY = 'Priority'
  HIGH = 'high'
  LOW = 'low'

  OLD_TYPE = 'old_type'
  STORY = 'story'
  BUG = 'BUG'
  USER_INPUT_OPTIONAL = '(user input - optional)'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @admin = users(:admin)
    @team_member = users(:longbob)
    @project_admin = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_39', :users => [@admin, @team_member], :admins => [@project_admin])
    setup_property_definitions(:Priority => [HIGH, LOW], :old_type => [STORY, BUG])
    login_as_admin_user
    create_card!(:name => "card")
  end

  # bug 1502
  def test_template_creation_validation_errors
    forty_character_long_name = 'veryvery_important_and_long_project_name'
    navigate_to_all_projects_page
    create_new_project(forty_character_long_name)
    project = Project.find_by_name(forty_character_long_name)
    create_template_for(project)
    navigate_to_template_management_page
    assert_template_present("#{forty_character_long_name} template")
  end

  # bug 1715
  def test_project_created_from_template_does_not_contain_duplicates_of_properties
    create_template_for(@project)
    click_new_project_link
    type_project_name('testing')
    select_template("#{@project.identifier}_template")
    click_create_project_button
    navigate_to_property_management_page_for(@project)
    @browser.assert_element_matches('property_definitions', /#{OLD_TYPE}{1}/)
    @browser.assert_element_matches('property_definitions', /#{PRIORITY}{1}/)
  end

  def test_template_does_not_keep_projects_team_members
    create_template_for(@project)
    template_identifier = "#{@project.identifier}_template"
    navigate_to_team_list_for(template_identifier)
    assert_user_is_not_team_member(@admin)
    assert_user_is_not_team_member(@project_admin)
    assert_user_is_not_team_member(@team_member)
  end

  def test_template_retains_saved_views
    navigate_to_card_list_for(@project)
    add_column_for(@project, [PRIORITY])
    filter_card_list_by(@project, OLD_TYPE => STORY)
    list_saved_view = create_card_list_view_for(@project, 'high stories')
    reset_view
    switch_to_grid_view
    group_columns_by(OLD_TYPE)
    grid_saved_view = create_card_list_view_for(@project, 'all types')
    reset_view
    navigate_to_favorites_management_page_for(@project)
    @browser.click "id=#{move_to_tab_cardlistview(grid_saved_view)}"

    create_template_for(@project)
    project_template = Project.find_by_identifier("#{@project.name}_template")
    project_template.activate

    navigate_to_template_management_page
    click_template_link("#{@project.name} template")

    click_link(grid_saved_view.name)
    assert_grouped_by(OLD_TYPE)

    @browser.click_and_wait("link=#{list_saved_view.name}")
    assert_filter_is(1, OLD_TYPE, "is", STORY)
  end

  # bug 1460
  def test_projects_created_from_templates_with_assigned_transitions_default_to_all_team_members
    transition_name = 'assigned to'
    transition = create_transition_for(@project, transition_name, :set_properties => {PRIORITY => LOW}, :for_team_members => [@project_admin])
    create_template_for(@project)
    project_template = Project.find_by_identifier("#{@project.name}_template")
    project_template.activate

    new_project_name = 'created_from_template'
    create_new_project_from_template(new_project_name, project_template.identifier)
    project_created_from_template = Project.find_by_identifier(new_project_name)
    transition_in_new_project = project_created_from_template.transitions.find_by_name(transition_name)
    navigate_to_transition_management_for(project_created_from_template)
    assert_transition_available_to_all_team_members(transition_in_new_project)
  end

  def test_transitions_set_user_input_optional_should_be_carried_to_template_and_imported_project_via_template
    transition_name = 'assigned to'
    create_transition_for(@project, transition_name, :set_properties => {PRIORITY => USER_INPUT_OPTIONAL})
    create_template_for(@project)
    project_template = Project.find_by_identifier("#{@project.name}_template")
    project_template.activate

    new_project_name = 'created_from_template'
    create_new_project_from_template(new_project_name, project_template.identifier)
    project_created_from_template = Project.find_by_identifier(new_project_name)
    transition = project_created_from_template.transitions.find_by_name(transition_name)
    assert_not_blank project_created_from_template.transitions.find_by_name(transition_name)
    navigate_to_transition_management_for(project_created_from_template)
    assert_property_set_on_transition_list_for_transtion(transition, PRIORITY => USER_INPUT_OPTIONAL )
  end

  # bug 2386
  def test_user_property_set_to_require_user_input_if_the_project_does_not_hold_that_users
    user_property_name = 'owner'
    create_property_definition_for(@project, user_property_name, :type => 'user')
    @project.reload.activate
    transition = create_transition_for(@project, 'set to bob', :set_properties => {:owner => @team_member.name})

    create_template_for(@project)

    template_identifier = "#{@project.identifier}_template"
    project_template = Project.find_by_identifier("#{@project.name}_template")
    project_template.activate

    new_project_name = 'created_from_template'
    create_new_project_from_template(new_project_name, project_template.identifier)
    project_created_from_template = Project.find_by_identifier(new_project_name)
    transition_in_new_project = project_created_from_template.transitions.find_by_name('set to bob')
    navigate_to_transition_management_for(project_created_from_template)
    @browser.assert_text_present('(user input - required)')
  end

  # bug 1347
  def test_mingle_users_selected_while_creating_transitions_should_defaulted_to_all_users_when_marked_as_templet
    transition_name = 'assigned to'
    transition = create_transition_for(@project, transition_name, :set_properties => {PRIORITY => LOW}, :for_team_members => [@admin, @team_member])
    create_template_for(@project)
    project_template = Project.find_by_identifier("#{@project.name}_template")
    project_template.activate

    create_template_for(@project)

    template_identifier = "#{@project.identifier}_template"
    project_template = Project.find_by_identifier("#{@project.name}_template")
    project_template.activate

    new_project_name = 'created_from_template'
    create_new_project_from_template(new_project_name, project_template.identifier)
    project_created_from_template = Project.find_by_identifier(new_project_name)
    transition_in_new_project = project_created_from_template.transitions.find_by_name(transition_name)
    navigate_to_transition_management_for(project_created_from_template)
    @browser.assert_text_present('This transition can be used by all team members.')
  end

  #1477
  def test_card_keywords_maintained_when_exported_as_templets
    navigate_to_card_keywords_for(@project)
    @browser.type 'project[card_keywords]', 'card, #, bug, defect'
    @browser.click_and_wait('link=Update keywords')
    assert_notice_message('Project was successfully updated.')

    create_template_for(@project)
    template_identifier = "#{@project.identifier}_template"
    project_template = Project.find_by_identifier("#{@project.name}_template")
    project_template.activate

    new_project_name = 'created_from_template'
    create_new_project_from_template(new_project_name, project_template.identifier)
    project_created_from_template = Project.find_by_identifier(new_project_name)
    navigate_to_card_keywords_for(@project)
    assert_card_keywords_present('card, #, bug, defect')
  end

  #1780
  def test_mingle_admin_can_delete_templates
    create_template_for(@project)
    template_identifier = "#{@project.identifier}_template"
    project_template = Project.find_by_identifier("#{@project.name}_template")
    project_template.activate

    new_project_name = 'created_from_template'
    create_new_project_from_template(new_project_name, project_template.identifier)
    navigate_to_template_management_page
    delete_template_permanently(@project)
    assert_notice_message("#{@project.identifier} template was successfully deleted")
  end

  #bug 2892
  def test_project_created_thorough_template_could_quick_add_a_card
    create_template_for(@project)
    template_identifier = "#{@project.identifier}_template"
    project_template = Project.find_by_identifier("#{@project.name}_template")
    project_template.activate
    new_project_name = 'created_from_template'
    project_created_from_template = create_new_project_from_template(new_project_name, project_template.identifier)
    project_created_from_template.activate
    click_all_tab
    add_card_via_quick_add("new card", :type => "Card", :project => project_created_from_template)
    assert_notice_message("Card #\\d was successfully created.")
  end

  # bug 3363
  def test_can_update_project_description_on_an_existing_template
    create_template_for(@project)
    template_identifier = "#{@project.identifier}_template"
    project_template = Project.find_by_identifier("#{@project.name}_template")
    project_template.activate
    navigate_to_project_admin_for(project_template)
    project_description = 'this is great!'
    type_project_description(project_description)
    click_save_link
    assert_notice_message(UPDATE_SUCCESSFUL_MESSAGE)
    navigate_to_template_management_page
    @browser.assert_text_present(project_description)
  end

  # bug 3757
  def test_can_try_to_update_template_identifier_to_end_with_an_underscore_without_500_error
    create_template_for(@project)
    template_identifier = "#{@project.identifier}_template"
    project_template = Project.find_by_identifier("#{@project.name}_template")
    project_template.activate
    navigate_to_project_admin_for(project_template)
    project_description = 'this is great!'
    new_template_identifier = "#{template_identifier}_"
    type_project_identifier(new_template_identifier)
    click_save_link
    assert_notice_message(UPDATE_SUCCESSFUL_MESSAGE)
  end

end
