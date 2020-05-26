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
class Scenario72ProjectVariableCrud3Test < ActiveSupport::TestCase

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

  def test_can_delete_project_variables
    project_variable_name = 'future release'
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '100', :properties => [SIZE])
    assert_notice_message("Project variable #{project_variable_name} was successfully created.")
    delete_project_variable(@project, project_variable_name)
    click_continue_to_delete
    assert_notice_message("Project variable #{project_variable_name} was successfully deleted")
  end

  def test_can_delete_plv_that_is_used_in_transition
    project_variable_name = 'future release'
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '100', :properties => [SIZE])
    transition_setting_plv = create_transition_for(@project, 'setting plv', :set_properties => {SIZE => plv_display_name(project_variable_name)})
    transition_requiring_plv = create_transition_for(@project, 'requiring plv', :required_properties => {SIZE => plv_display_name(project_variable_name)}, :set_properties => {SIZE => NOT_SET})
    navigate_to_project_variable_management_page_for(@project)
    delete_project_variable(@project, project_variable_name)
    @browser.assert_text_present("We recommend that you review the following things that will be affected by deleting a project variable #{project_variable_name}")
    @browser.assert_text_present("The following 2 transitions will be deleted: #{transition_requiring_plv.name} and #{transition_setting_plv.name}")
    click_continue_to_delete
    assert_notice_message("Project variable #{project_variable_name} was successfully deleted")
  end

  def test_renaming_project_variable_changes_name_where_used_in_transitions
    project_variable_name = 'future release'
    new_name_for_plv = 'FOO'
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '100', :properties => [SIZE])
    transition_setting_plv = create_transition_for(@project, 'setting plv', :set_properties => {SIZE => plv_display_name(project_variable_name)})
    open_project_variable_for_edit(@project, project_variable_name)
    type_project_variable_name(new_name_for_plv)
    click_save_project_variable
    open_transition_for_edit(@project, transition_setting_plv)
    assert_sets_property(SIZE => plv_display_name(new_name_for_plv))
    assert_transition_present_for(@project, transition_setting_plv)
    @browser.assert_text_present(plv_display_name(new_name_for_plv))
    @browser.assert_text_not_present(plv_display_name(project_variable_name))
  end

  def test_removing_property_association_to_project_variable_deletes_related_transition_setting_plv
    project_variable_name = 'future release'
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '100', :properties => [SIZE])
    transition_setting_plv = create_transition_for(@project, 'setting plv', :set_properties => {SIZE => plv_display_name(project_variable_name)})
    open_project_variable_for_edit(@project, project_variable_name)
    uncheck_properties_that_will_use_variable(@project, SIZE)
    click_save_project_variable
    @browser.assert_text_present("The following 1 transition will be deleted: #{transition_setting_plv.name}")
    click_continue_to_update
    assert_notice_message("Project variable #{project_variable_name} was successfully updated.")
    assert_transition_not_present_for(@project, transition_setting_plv)
  end

  def test_removing_property_association_to_project_variable_deletes_related_transition_requiring_plv
    project_variable_name = 'future release'
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '100', :properties => [SIZE])
    transition_requiring_plv = create_transition_for(@project, 'setting plv', :required_properties => {SIZE => plv_display_name(project_variable_name)}, :set_properties => {SIZE => NOT_SET})
    open_project_variable_for_edit(@project, project_variable_name)
    uncheck_properties_that_will_use_variable(@project, SIZE)
    click_save_project_variable
    @browser.assert_text_present("The following 1 transition will be deleted: #{transition_requiring_plv.name}")
    click_continue_to_update
    assert_notice_message("Project variable #{project_variable_name} was successfully updated.")
    assert_transition_not_present_for(@project, transition_requiring_plv)
  end

  def test_changing_data_type_of_existing_project_variable_deletes_transition_setting_plv
    project_variable_name = 'stuff'
    card = create_card!(:name => 'for testing')
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::STRING_DATA_TYPE, :value => NEW, :properties => [STATUS, FREE_TEXT_PROPERTY])
    transition_setting_plv = create_transition_for(@project, 'setting plv', :set_properties => {STATUS => plv_display_name(project_variable_name)})
    open_project_variable_for_edit(@project, project_variable_name)
    select_data_type(ProjectVariable::USER_DATA_TYPE)
    select_properties_that_will_use_variable(@project, USER_PROPERTY)
    click_save_project_variable
    @browser.assert_text_present("The following 1 transition will be deleted: #{transition_setting_plv.name}")
    click_continue_to_update
    assert_notice_message("Project variable #{project_variable_name} was successfully updated.")
    assert_transition_not_present_for(@project, transition_setting_plv)
    open_transition_create_page(@project)
    assert_set_property_does_not_have_value(@project, STATUS, "(#{project_variable_name})")
    assert_set_property_does_have_value(@project, USER_PROPERTY, "(#{project_variable_name})")
  end

  def test_different_invalid_values_for_date_property_in_card_view_mode
    invalid_values_for_date_property = ['one two three']
    if RUBY_PLATFORM =~ /java/

     #todo: new jruby upgrade seems break date parsing,  should also be invalid
     #invalid_values_for_date_property += ['31st Feb 2007', 'first Feb 29']
    end
    invalid_values_for_date_property.each{|invalid_value| assert_cannot_give_date_property_invalid_value_during_plv_create(invalid_value)}
  end

  def test_should_not_be_able_to_add_non_numeric_values_on_card_show
    non_numeric_values = ['d@32', '#1', '.01a', '%123', '1xyz', '1496K']
    non_numeric_values.each{|value| assert_cannot_give_numeric_property_non_numeric_value_during_plv_create(value)}
  end

  # bug 3249
  def test_display_value_on_plv_create_page_escapes_html
    name_with_html_tags = "foo <b>BAR</b>"
    same_name_without_html_tags = "foo BAR"
    open_project_variable_create_page_for(@project)
    type_project_variable_name(name_with_html_tags)
    @browser.assert_element_matches('appeared_project_variable_name', /(#{name_with_html_tags})/)
    @browser.assert_element_does_not_match('appeared_project_variable_name', /(#{same_name_without_html_tags})/)
  end

  def test_cannot_create_property_value_that_both_begins_and_ends_with_parens
    value_that_begins_and_ends_with_parens = '(foo)'
    unmanaged_numeric_property = setup_numeric_text_property_definition('Size unmanaged')
    assert_cannot_create_value_that_both_begins_and_ends_with_parens(STATUS, ProjectVariable::STRING_DATA_TYPE, value_that_begins_and_ends_with_parens)
    assert_cannot_create_value_that_both_begins_and_ends_with_parens(FREE_TEXT_PROPERTY, ProjectVariable::STRING_DATA_TYPE, value_that_begins_and_ends_with_parens)
    assert_cannot_create_value_that_both_begins_and_ends_with_parens(SIZE, ProjectVariable::NUMERIC_DATA_TYPE, '(1)')
    assert_cannot_create_value_that_both_begins_and_ends_with_parens(unmanaged_numeric_property, ProjectVariable::NUMERIC_DATA_TYPE, '(1)')
    hide_property(@project, STATUS)
    hide_property(@project, FREE_TEXT_PROPERTY)
    hide_property(@project, SIZE)
    hide_property(@project, unmanaged_numeric_property)
    assert_cannot_create_value_that_both_begins_and_ends_with_parens(STATUS, ProjectVariable::STRING_DATA_TYPE, value_that_begins_and_ends_with_parens)
    assert_cannot_create_value_that_both_begins_and_ends_with_parens(FREE_TEXT_PROPERTY, ProjectVariable::STRING_DATA_TYPE, value_that_begins_and_ends_with_parens)
    assert_cannot_create_value_that_both_begins_and_ends_with_parens(SIZE, ProjectVariable::NUMERIC_DATA_TYPE, '(1)')
    assert_cannot_create_value_that_both_begins_and_ends_with_parens(unmanaged_numeric_property, ProjectVariable::NUMERIC_DATA_TYPE, '(1)')
  end

  # bug 3264
  def test_user_plv_value_dropdown_maintains_correct_order_after_dropping_and_readding_user_to_team
    user_jen = create_user!(:name => 'jen')
    user_foo = create_user!(:name => 'foo')
    # user_bar = create_user!(:name => 'bar') # Reduced one team member as license support only 5 users right now. (it makes it read only on adding six users to the team)
    login_as(@admin.login)
    add_several_users_to_team_for(@project, user_jen, user_foo)

    open_project_variable_create_page_for(@project)
    select_data_type(ProjectVariable::USER_DATA_TYPE)
    assert_users_in_user_value_dropdown_are_ordered('admin@email.com', 'foo', 'jen', 'member@email.com', 'proj_admin@email.com')

    remove_from_team_for(@project, user_foo)
    add_full_member_to_team_for(@project, user_foo)

    open_project_variable_create_page_for(@project)
    select_data_type(ProjectVariable::USER_DATA_TYPE)
    assert_users_in_user_value_dropdown_are_ordered('admin@email.com', 'foo', 'jen', 'member@email.com', 'proj_admin@email.com')
  end

  # bug 3261
  def test_card_selection_lightbox_can_contain_a_message_stating_no_cards_of_type_exist_in_the_project
    type_qwjibu = setup_card_type(@project, 'qwjibu')   # we need a card type with no cards
    type_card = @project.card_types.find_by_name(CARD)
    some_tree = setup_tree(@project, 'some tree', :types => [type_qwjibu, type_card], :relationship_names => ['qwjibu'])

    open_project_variable_create_page_for(@project)
    select_data_type(ProjectVariable::CARD_DATA_TYPE)
    select_card_type(@project, type_qwjibu)
    open_value_selection_box_for_card_type
    assert_no_cards_available_for_type_message(@project, type_qwjibu.name)
  end

  # bug 4165
  def test_renaming_enum_property_value_that_is_value_for_one_plv_renames_the_value_for_the_plv
    project_variable_name = 'foo'
    new_name_for_value = 'neux'
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::STRING_DATA_TYPE, :value => NEW, :properties => [STATUS])
    edit_enumeration_value_for(@project, STATUS, NEW, new_name_for_value)
    assert_error_message_not_present
    @browser.assert_text_not_present('Value has already been taken\'')
    open_project_variable_for_edit(@project, project_variable_name)
    assert_value_for_project_variable(@project, project_variable_name, new_name_for_value)
    assert_properties_selected_for_project_variable(@project, STATUS)
  end

  # bug 4234
  def test_inform_consequences_of_deleteing_a_property_which_is_used_in_plv
    project_variable_name = 'testing'
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::STRING_DATA_TYPE, :value => NEW, :properties => [STATUS])
    navigate_to_property_management_page_for(@project)
    delete_property_for(@project, STATUS, :stop_at_confirmation => true)
    @browser.assert_text_present("Used by 1 ProjectVariable: #{project_variable_name}. This will be disassociated.")
  end

  # bug 3794
  def test_editing_plv_type_when_it_is_used_in_a_favorite_view_has_correct_info_message
    project_variable_name = 'current iteration'
    view_name = 'favorite view'
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::STRING_DATA_TYPE, :properties => [STATUS])
    create_card!(:name => CARD, :description => 'description')
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, STATUS => "(#{project_variable_name})")
    create_card_list_view_for(@project, view_name)
    open_project_variable_for_edit(@project, project_variable_name)
    select_data_type(ProjectVariable::NUMERIC_DATA_TYPE)
    click_save_project_variable
    @browser.assert_text_present("The following 1 team favorite will be deleted: #{view_name}.")
    @browser.assert_text_not_present("The following 1 saved view will be deleted: #{view_name}")
  end

  # bug 3794
  def test_deleting_plv_type_when_it_is_used_in_a_favorite_view_has_correct_info_message
    project_variable_name = 'current iteration'
    view_name = 'favorite view'
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::STRING_DATA_TYPE, :properties => [STATUS])
    create_card!(:name => CARD, :description => 'description')
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, STATUS => "(#{project_variable_name})")
    create_card_list_view_for(@project, view_name)
    navigate_to_project_variable_management_page_for(@project)
    delete_project_variable(@project, project_variable_name)
    @browser.assert_text_present("The following 1 team favorite will be deleted: #{view_name}.")
    @browser.assert_text_not_present("The following 1 saved view will be deleted: #{view_name}")
  end

  # bug 4194
  def test_disassociating_properties_from_project_variable_where_they_are_both_filters_on_saved_view_provides_warning_message_with_no_duplicates
    status2 = 'status2'
    setup_property_definitions(status2 => [NEW, OPEN])
    project_variable_name = 'Current status'
    high = 'OPEN'
    view_name = 'A lovely view'
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::STRING_DATA_TYPE , :value => high, :properties => [STATUS, status2])
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, STATUS => "(#{project_variable_name})", status2 => "(#{project_variable_name})")
    create_card_list_view_for(@project, view_name)
    open_project_variable_for_edit(@project, project_variable_name)
    uncheck_properties_that_will_use_variable(@project, STATUS, status2)
    click_save_project_variable
    assert_info_box_light_message("The following 1 team favorite will be deleted: #{view_name}.")
    @browser.assert_text_not_present("The following 2 saved views will be deleted: #{view_name} and #{view_name}.")
  end

end
