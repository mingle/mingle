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
require File.expand_path(File.dirname(__FILE__) + '/project_variable_acceptance_support.rb')

# Tags: properties,project-variable
class Scenario72ProjectVariableCrud1Test < ActiveSupport::TestCase

  include ProjectVariableAcceptanceSupport

  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @admin = users(:admin)
    @project_admin = users(:proj_admin)
    @project_member = users(:project_member)
    @non_team_member = users(:first)
    @project = create_project(:prefix => 'scenario_72', :admins => [@project_admin], :users => [@admin, @project_member])

    setup_property_definitions(STATUS => [NEW, OPEN])
    setup_user_definition(USER_PROPERTY)
    setup_text_property_definition(FREE_TEXT_PROPERTY)
    setup_date_property_definition(DATE_PROPERTY)
    @size_property = setup_numeric_property_definition(SIZE, [2, 4])
    setup_formula_property_definition(FORMULA_PROPERTY, "#{SIZE} * 2")
    login_as_proj_admin_user
  end

  def test_value_created_by_plv_maintains_order_of_enum_with_existing_proeprty_values
    project_variable_name = 'new size'
    plv = create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '3', :properties => [SIZE])
    assert_notice_message("Project variable #{project_variable_name} was successfully created.")
    open_edit_enumeration_values_list_for(@project, SIZE)
    assert_all_enum_values_in_order(@project, SIZE, ['2', '3', '4'])
  end

  def test_should_warn_when_trying_to_delete_enumeration_value_which_is_being_used_by_plv
    project_variable_name = 'new size'
    plv = create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '3', :properties => [SIZE])
    open_edit_enumeration_values_list_for(@project, SIZE)
    delete_enumeration_value_for(@project, @size_property, '3', :requires_confirmation => true, :stop_at_confirmation => true)
    @browser.assert_text_present("The following 1 project variable will be disassociated from property #{SIZE}: (#{project_variable_name})")
  end

  def test_non_admin_team_members_cannot_create_or_edit_or_delete_project_variables
    project_variable_name = 'current iteration'
    create_project_variable(@project, :name => project_variable_name)
    project_variable_definition = Project.find_by_identifier(@project.identifier).project_variables.find_by_name(project_variable_name)
    logout
    login_as_project_member
    navigate_to_project_variable_management_page_for(@project)
    @browser.assert_element_not_present("link=Create new project variable")
    assert_link_not_present_and_cannot_access_via_browser("/projects/#{@project.identifier}/project_variables/edit/#{project_variable_definition.id}")
    navigate_to_project_variable_management_page_for(@project)
    assert_project_variable_present_on_property_management_page(project_variable_name)

    navigate_to_project_variable_management_page_for(@project)
    assert_link_not_present_and_cannot_access_via_browser("/projects/#{@project.identifier}/project_variables/confirm_delete/#{project_variable_definition.id}") #bug 3166
    navigate_to_project_variable_management_page_for(@project)
    assert_project_variable_present_on_property_management_page(project_variable_name)
  end

  def test_project_variable_value_cannot_begin_and_end_with_parens
    project_variable_name = 'testing'
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::STRING_DATA_TYPE, :value => '(invalid)')
    assert_error_message("Value cannot both start with '(' and end with ')'", :escape => true)
    navigate_to_project_variable_management_page_for(@project)
    assert_project_variable_not_present_on_property_management_page(project_variable_name)
  end

  def test_project_variable_name_cannot_match_reserved_names
    reserved_names = ['current user', 'today', 'user input - required', 'user input - optional', 'not set', 'any', 'no change']
    reserved_names.each do |reserved_name|
      create_project_variable(@project, :name => reserved_name, :data_type => ProjectVariable::STRING_DATA_TYPE)
      assert_error_message("Name #{reserved_name} is a reserved property value.")
      navigate_to_project_variable_management_page_for(@project)
      assert_project_variable_not_present_on_property_management_page(reserved_name)
    end
  end

  def test_project_variable_name_cannot_exceed_255_characters
    name_with_255_characters = 'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Etiam iaculis neque. Maecenas risus. Maecenas eget felis vitae ipsum tempus consectetuer. Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Etiam iaculis neque. Maecenas risus. Maecenas ris'
    name_with_256_characters = name_with_255_characters + '1'
    create_project_variable(@project, :name => name_with_255_characters)
    assert_notice_message("Project variable #{name_with_255_characters} was successfully created.")
    create_project_variable(@project, :name => name_with_256_characters)
    assert_error_message("Name is too long (maximum is 255 characters)", :escape => true)
    navigate_to_project_variable_management_page_for(@project)
    assert_project_variable_not_present_on_property_management_page(name_with_256_characters)
  end

  def test_project_variable_name_cannot_be_blank
    create_project_variable(@project, :name => BLANK)
    assert_error_message("Name can't be blank")
  end

  def test_cannot_create_multiple_project_variables_with_the_same_name
    project_variable_name = 'current iteration'
    same_name_with_extra_spaces = 'current   iteration'
    same_name_with_caps = project_variable_name.upcase
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::STRING_DATA_TYPE, :value => '1')
    assert_notice_message("Project variable #{project_variable_name} was successfully created.")
    click_create_new_project_variable
    type_project_variable_name(project_variable_name)
    click_create_project_variable
    assert_error_message('Name has already been taken')
    type_project_variable_name(same_name_with_extra_spaces)
    click_create_project_variable
    assert_error_message('Name has already been taken')
    type_project_variable_name(same_name_with_caps)
    click_create_project_variable
    assert_error_message('Name has already been taken')
    navigate_to_project_variable_management_page_for(@project)
    assert_project_variable_present_on_property_management_page(project_variable_name)
    assert_project_variable_not_present_on_property_management_page(same_name_with_extra_spaces)
    assert_project_variable_not_present_on_property_management_page(same_name_with_caps)
  end

  # bug 3089
  def test_formula_properties_do_not_appear_as_associations_for_project_level_variables
    project_variable_name = 'no formulae allowed'
    open_project_variable_create_page_for(@project)
    select_data_type(ProjectVariable::DATE_DATA_TYPE)
    assert_properties_not_present_for_association_to_project_variable(@project, FORMULA_PROPERTY)

    select_data_type(ProjectVariable::NUMERIC_DATA_TYPE)
    assert_properties_not_present_for_association_to_project_variable(@project, FORMULA_PROPERTY)
  end

  def test_project_variable_can_be_created_without_setting_value_and_value_will_be_not_set
    project_variable_name = 'testing'
    create_project_variable(@project, :name => project_variable_name)
    assert_notice_message("Project variable #{project_variable_name} was successfully created.")
    @browser.assert_text_present(NOT_SET)
    open_project_variable_for_edit(@project, project_variable_name)
    assert_value_for_project_variable(@project, project_variable_name, BLANK)
  end

  def test_project_variable_can_be_created_when_project_does_not_have_properties
    project_without_properties = create_project(:prefix => 'no_properties', :admins => [@project_admin], :users => [@admin, @project_member])
    project_variable_name = 'without properties'
    create_project_variable(@project, :name => project_variable_name)
    assert_notice_message("Project variable #{project_variable_name} was successfully created.")
    assert_project_variable_present_on_property_management_page(project_variable_name)
  end

  def test_project_variable_can_be_created_without_selecting_properties
    project_variable_name = 'current iteration'
    ninety_nine = '99'
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => ninety_nine)
    assert_notice_message("Project variable #{project_variable_name} was successfully created.")
    open_project_variable_for_edit(@project, project_variable_name)
    assert_value_for_project_variable(@project, project_variable_name, ninety_nine)
    assert_properties_not_selected_for_project_variable(@project, SIZE, FORMULA_PROPERTY)
  end

  def test_project_variable_can_be_created_when_project_has_no_team_members
    logout
    login_as_admin_user
    project_without_team_members = create_project(:prefix => 'no_team_members')
    setup_user_definition(USER_PROPERTY)
    project_variable_name = 'without team members'
    create_project_variable(project_without_team_members, :name => project_variable_name, :data_type => ProjectVariable::USER_DATA_TYPE, :properties => [USER_PROPERTY])
    assert_notice_message("Project variable #{project_variable_name} was successfully created.")
    assert_project_variable_present_on_property_management_page(project_variable_name)
    open_project_variable_for_edit(project_without_team_members, project_variable_name)
    assert_properties_selected_for_project_variable(project_without_team_members, USER_PROPERTY)
  end

  def test_only_team_members_are_available_as_values_for_user_project_variables

    # 6612, scenario 6, auto enrolled user should be available as value for user project variable

    logout
    login_as_admin_user

    navigate_to_user_management_page
    click_new_user_link
    @new_user = add_new_user("new_user@gmail.com", "password1.")

    add_full_member_to_team_for(@project, @new_user)

    project_variable_name = 'user variable'
    open_project_variable_create_page_for(@project)
    select_data_type(ProjectVariable::USER_DATA_TYPE)
    assert_user_not_available_as_value(@non_team_member)
    assert_users_available_as_value(@admin, @project_admin, @project_member, @new_user)

  end

  def test_removing_team_member_that_is_value_of_variable_sets_value_of_plv_to_not_set_but_does_not_deselect_property
    project_variable_name = 'current owner'
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::USER_DATA_TYPE, :value => @project_member.name, :properties => [USER_PROPERTY])
    assert_notice_message("Project variable #{project_variable_name} was successfully created.")
    remove_from_team_for(@project, @project_member)
    @browser.assert_text_present("1 Project Variable changed to (not set): #{project_variable_name}")
    click_continue_to_remove
    open_project_variable_for_edit(@project, project_variable_name)
    assert_user_not_available_as_value(@project_member)
    assert_value_for_project_variable(@project, project_variable_name, NOT_SET)
    assert_properties_selected_for_project_variable(@project, USER_PROPERTY)
  end

  def test_changing_user_name_updates_value_for_project_variable
    project_variable_name = 'current owner'
    new_name_for_team_member = 'the big hurt'
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::USER_DATA_TYPE, :value => @project_admin.name, :properties => [USER_PROPERTY])
    assert_notice_message("Project variable #{project_variable_name} was successfully created.")
    open_edit_profile_for(@project_admin)
    type_full_name_in_user_profile(new_name_for_team_member)
    click_save_profile_button
    open_project_variable_for_edit(@project, project_variable_name)
    assert_value_for_project_variable(@project, project_variable_name, new_name_for_team_member)
    assert_properties_selected_for_project_variable(@project, USER_PROPERTY)
  end

  # bug 3072
  def test_default_setting_user_property_sets_it_to_not_set_when_creating_project_from_template
    logout
    login_as_admin_user
    project_variable_name = 'current owner'
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::USER_DATA_TYPE, :value => @project_member.name, :properties => [USER_PROPERTY])

    create_template_for(@project)
    project_template = Project.find_by_identifier("#{@project.name}_template")
    project_template.activate

    new_project_name = 'created_from_template'
    create_new_project(new_project_name, :template_identifier => project_template.identifier)
    project_created_from_template = Project.find_by_identifier(new_project_name)
    open_project_variable_for_edit(project_created_from_template, project_variable_name)
    assert_properties_not_selected_for_project_variable(@project, USER_PROPERTY)
    assert_value_for_project_variable(project_created_from_template, project_variable_name, NOT_SET)
  end

end
