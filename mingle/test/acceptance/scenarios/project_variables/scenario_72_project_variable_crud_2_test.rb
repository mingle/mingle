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
class Scenario72ProjectVariableCrud2Test < ActiveSupport::TestCase

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

  # bug 3073
  def test_can_change_value_for_user_data_type_project_variable_to_not_set
    project_variable_name = 'current owner'
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::USER_DATA_TYPE, :value => @project_admin.name, :properties => [USER_PROPERTY])
    assert_notice_message("Project variable #{project_variable_name} was successfully created.")
    open_project_variable_for_edit(@project, project_variable_name)
    set_value(ProjectVariable::USER_DATA_TYPE, NOT_SET)
    assert_value_for_project_variable(@project, project_variable_name, NOT_SET)
    assert_properties_selected_for_project_variable(@project, USER_PROPERTY)
    click_save_project_variable
    open_project_variable_for_edit(@project, project_variable_name)
    assert_value_for_project_variable(@project, project_variable_name, NOT_SET)
    assert_properties_selected_for_project_variable(@project, USER_PROPERTY)
  end

  def test_can_set_deativated_team_member_as_value_for_user_property_plv
    logout
    login_as_admin_user
    toggle_activation_for(@project_member)
    project_variable_name = 'current owner'
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::USER_DATA_TYPE, :value => @project_member.name, :properties => [USER_PROPERTY])
    open_project_variable_for_edit(@project, project_variable_name)
    assert_value_for_project_variable(@project, project_variable_name, PROJECT_MEMBER_NAME_TRUNCATED)
    assert_properties_selected_for_project_variable(@project, USER_PROPERTY)
  end

  def test_can_deativate_team_member_that_is_value_for_user_property_plv
    logout
    login_as_admin_user
    project_variable_name = 'current owner'
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::USER_DATA_TYPE, :value => @project_member.name, :properties => [USER_PROPERTY])
    toggle_activation_for(@project_member)
    assert_successful_user_deactivation_message(@project_member)
    open_project_variable_for_edit(@project, project_variable_name)
    assert_value_for_project_variable(@project, project_variable_name, PROJECT_MEMBER_NAME_TRUNCATED)
    assert_properties_selected_for_project_variable(@project, USER_PROPERTY)
  end

  def test_can_select_hidden_properties_for_project_variables
    project_variable_name = 'due date'
    april_first = '01 Apr 2008'
    hide_property(@project, DATE_PROPERTY)
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::DATE_DATA_TYPE, :value => april_first, :properties => [DATE_PROPERTY])
    assert_notice_message("Project variable #{project_variable_name} was successfully created.")
    open_project_variable_for_edit(@project, project_variable_name)
    assert_value_for_project_variable(@project, project_variable_name, april_first)
    assert_properties_selected_for_project_variable(@project, DATE_PROPERTY)
  end

  def test_can_select_locked_properties_for_project_variables
    project_variable_name = 'current status'
    red = 'red'
    lock_property(@project, STATUS)
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::STRING_DATA_TYPE, :value => red, :properties => [STATUS])
    assert_notice_message("Project variable #{project_variable_name} was successfully created.")
    open_project_variable_for_edit(@project, project_variable_name)
    assert_value_for_project_variable(@project, project_variable_name, red)
    assert_properties_selected_for_project_variable(@project, STATUS)
  end

  def test_can_select_transition_only_properties_for_project_variables
    project_variable_name = 'resolution of the day'
    foo_bar = 'foo bar'
    make_property_transition_only_for(@project, FREE_TEXT_PROPERTY)
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::STRING_DATA_TYPE, :value => foo_bar, :properties => [FREE_TEXT_PROPERTY])
    assert_notice_message("Project variable #{project_variable_name} was successfully created.")
    open_project_variable_for_edit(@project, project_variable_name)
    assert_value_for_project_variable(@project, project_variable_name, foo_bar)
    assert_properties_selected_for_project_variable(@project, FREE_TEXT_PROPERTY)
  end

  def test_selecting_date_data_type_only_presents_date_properties_for_associations
    project_variable_name = 'for date data type'
    feb_25_2008 = '25 Feb 2008'
    open_project_variable_create_page_for(@project)
    type_project_variable_name(project_variable_name)
    select_data_type(ProjectVariable::DATE_DATA_TYPE)
    set_value(ProjectVariable::DATE_DATA_TYPE, feb_25_2008)
    select_properties_that_will_use_variable(@project, DATE_PROPERTY)
    assert_properties_not_present_for_association_to_project_variable(@project, STATUS, SIZE, USER_PROPERTY, FREE_TEXT_PROPERTY)
    click_create_project_variable
    assert_notice_message("Project variable #{project_variable_name} was successfully created.")
    open_project_variable_for_edit(@project, project_variable_name)
    assert_value_for_project_variable(@project, project_variable_name, feb_25_2008)
    assert_properties_selected_for_project_variable(@project, DATE_PROPERTY)
    assert_properties_not_present_for_association_to_project_variable(@project, STATUS, SIZE, USER_PROPERTY, FREE_TEXT_PROPERTY)
  end

  def test_selecting_user_data_type_only_presents_user_properties_for_association
    open_project_variable_create_page_for(@project)
    select_data_type(ProjectVariable::USER_DATA_TYPE)
    assert_properties_present_for_association_to_project_variable(@project, USER_PROPERTY)
    assert_properties_not_present_for_association_to_project_variable(@project, STATUS, SIZE, FORMULA_PROPERTY, DATE_PROPERTY, FREE_TEXT_PROPERTY)
  end

  def test_selecting_text_data_type_only_presents_managed_and_free_text_properties_for_association
    open_project_variable_create_page_for(@project)
    select_data_type(ProjectVariable::STRING_DATA_TYPE)
    assert_properties_present_for_association_to_project_variable(@project, STATUS, FREE_TEXT_PROPERTY)
    assert_properties_not_present_for_association_to_project_variable(@project, SIZE, FORMULA_PROPERTY, DATE_PROPERTY)
  end

  def test_selecting_numeric_data_type_only_presents_numeric_properties_for_association
    open_project_variable_create_page_for(@project)
    select_data_type(ProjectVariable::NUMERIC_DATA_TYPE)
    assert_properties_present_for_association_to_project_variable(@project, SIZE)
    assert_properties_not_present_for_association_to_project_variable(@project, STATUS, FREE_TEXT_PROPERTY, USER_PROPERTY, DATE_PROPERTY)
  end

  def test_setting_value_for_managed_text_property_creates_value_if_it_does_not_already_exist
    project_variable_name = 'for managed text'
    new_value = 'deferred'
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::STRING_DATA_TYPE, :value => new_value, :properties => [STATUS])
    assert_notice_message("Project variable #{project_variable_name} was successfully created.")
    navigate_to_property_management_page_for(@project)
    status_property_definition = Project.find_by_identifier(@project.identifier).find_property_definition_or_nil(STATUS)
    assert_property_does_have_value(status_property_definition, new_value)
  end

  def test_setting_value_for_managed_number_property_creates_value_if_it_does_not_already_exist
    project_variable_name = 'for managed number'
    new_value = '100'
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => new_value, :properties => [SIZE])
    assert_notice_message("Project variable #{project_variable_name} was successfully created.")
    navigate_to_property_management_page_for(@project)
    size_property_definition = Project.find_by_identifier(@project.identifier).find_property_definition_or_nil(SIZE)
    assert_property_does_have_value(size_property_definition, new_value)
  end

  def test_setting_value_for_project_variable_does_not_create_duplicate_values_for_associated_property
    project_variable_name = 'testing'
    existing_value_for_status_upcased = NEW.upcase
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::STRING_DATA_TYPE, :value => existing_value_for_status_upcased, :properties => [STATUS])
    assert_notice_message("Project variable #{project_variable_name} was successfully created.")
    navigate_to_property_management_page_for(@project)
    status_property_definition = Project.find_by_identifier(@project.identifier).find_property_definition_or_nil(STATUS)
    assert_property_does_have_value(status_property_definition, NEW)
    assert_property_does_not_have_value(status_property_definition, existing_value_for_status_upcased)
  end

  def test_deleting_value_for_property_that_is_used_by_project_variable_does_not_remove_association_to_that_property
    project_variable_name = 'stuff'
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::STRING_DATA_TYPE, :value => NEW, :properties => [STATUS, FREE_TEXT_PROPERTY])
    assert_notice_message("Project variable #{project_variable_name} was successfully created.")
    navigate_to_property_management_page_for(@project)
    status_property_definition = Project.find_by_identifier(@project.identifier).find_property_definition_or_nil(STATUS)
    delete_enumeration_value_for(@project, status_property_definition, NEW, :requires_confirmation => true)
    open_project_variable_for_edit(@project, project_variable_name)
    assert_value_for_project_variable(@project, project_variable_name, NEW)
    assert_properties_selected_for_project_variable(@project, FREE_TEXT_PROPERTY, STATUS)
  end

  def test_deleting_property_that_is_using_plv_removes_it_from_plv
    project_variable_name = 'whatever'
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::STRING_DATA_TYPE, :value => NEW, :properties => [STATUS, FREE_TEXT_PROPERTY])
    assert_notice_message("Project variable #{project_variable_name} was successfully created.")
    navigate_to_property_management_page_for(@project)
    delete_property_for(@project, STATUS)
    open_project_variable_for_edit(@project, project_variable_name)
    assert_value_for_project_variable(@project, project_variable_name, NEW)
    assert_properties_selected_for_project_variable(@project, FREE_TEXT_PROPERTY)
    assert_property_not_present_in_property_table_on_plv_edit_page(STATUS)
  end

  def test_renaming_property_associated_to_plv_renames_updates_property_name_on_plv_edit_page
    project_variable_name = 'whatever'
    project_variable_value = '01 04 2008'
    project_variable_value_in_project_date_format = '01 Apr 2008'
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::DATE_DATA_TYPE, :value => project_variable_value, :properties => [DATE_PROPERTY])
    new_property_name = 'finshed on'
    edit_property_definition_for(@project, DATE_PROPERTY, :new_property_name => new_property_name)
    open_project_variable_for_edit(@project, project_variable_name)
    assert_value_for_project_variable(@project, project_variable_name, project_variable_value_in_project_date_format)
    assert_properties_selected_for_project_variable(@project, new_property_name)
    assert_property_not_present_in_property_table_on_plv_edit_page(DATE_PROPERTY)
  end

  def test_plvs_cannot_be_set_via_excel_import
    date_property_plv_name = 'for date'
    text_property_plv_name = 'for text'
    user_property_plv_name = 'for user'
    numeric_property_plv_name = 'for numeric'

    assert_cannot_set_value_for_property_to_plv_via_excel_import(:plv_data_type => ProjectVariable::DATE_DATA_TYPE, :plv_name => date_property_plv_name, :value => 'for date', :property => DATE_PROPERTY, :error_message => "Row 1: #{DATE_PROPERTY}: (#{date_property_plv_name}) is an invalid date. Enter dates in dd mmm yyyy format or enter existing project variable which is available for this property.")
    assert_cannot_set_value_for_property_to_plv_via_excel_import(:plv_data_type => ProjectVariable::USER_DATA_TYPE, :plv_name => user_property_plv_name, :value => @project_member.name, :property => USER_PROPERTY,
      :error_message => "Row 1: Error with #{USER_PROPERTY} column. Project team does not include (#{user_property_plv_name}). User property values must be set to current team member logins.")
    assert_cannot_set_value_for_property_to_plv_via_excel_import(:plv_data_type => ProjectVariable::NUMERIC_DATA_TYPE, :plv_name => numeric_property_plv_name, :value => '99', :property => SIZE,
      :error_message => "Row 1: #{SIZE}: (#{numeric_property_plv_name}) is an invalid numeric value")
  end

end
