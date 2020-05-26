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

# Tags: scenario, properties, enum_values, enum-property
class Scenario13EnumerationValueCrudTest < ActiveSupport::TestCase


  fixtures :users, :login_access

  FEATURE = 'feature'
  STATUS = 'status'
  NEW = 'new'
  IN_PROGRESS = 'in progress'
  CLOSED = 'closed'

  VALUE_ALREADY_TAKEN_MESSAGE = 'Value has already been taken'
  VALUE_CAN_NOT_START_WITH_PARENTHESIS =  "Value cannot both start with '(' and end with ')' unless it is an existing project variable which is available for this property."

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin = users(:proj_admin)
    @admin = users(:admin)
    @team_member = users(:longbob)
    @project = create_project(:prefix => 'scenario_13', :users => [@admin, @team_member], :admins => [@project_admin])
    @project.activate
    setup_property_definitions(STATUS => [NEW, IN_PROGRESS, CLOSED], FEATURE => [])
    login_as_proj_admin_user
    @card = create_card!(:name => 'new card')
  end

  def test_cannot_create_enum_value_without_name
    feature_property_definition = Project.find_by_identifier(@project.identifier).find_property_definition_or_nil(FEATURE)
    create_enumeration_value_for(@project, FEATURE, '')
    assert_error_message("Value can't be blank")
    assert_error_message_does_not_contain("Column name is invalid")
    @browser.click_and_wait('link=Up')
    @browser.assert_element_matches("prop_def_row_#{feature_property_definition.id}", /0 values/)
  end

  def test_cannot_create_duplicate_enum_values_for_the_same_property
    enum_name = "foo's"
    create_enumeration_value_for(@project, FEATURE, enum_name)
    create_enumeration_value_for(@project, FEATURE, enum_name)
    assert_error_message(VALUE_ALREADY_TAKEN_MESSAGE)
  end

  def test_cannot_create_value_that_begins_and_ends_with_parens
    value_that_begins_and_ends_with_parens = '(foo)'
    create_enumeration_value_for(@project, FEATURE, value_that_begins_and_ends_with_parens)
    assert_error_message_without_html_content("Value cannot both start with '(' and end with ')'")
  end

  def test_cannot_create_value_that_begins_and_ends_with_parens_for_hidden_property
    value_that_begins_and_ends_with_parens = '(foo)'
    hide_property(@project, FEATURE)
    create_enumeration_value_for(@project, FEATURE, value_that_begins_and_ends_with_parens)
    assert_error_message_without_html_content("Value cannot both start with '(' and end with ')'")
  end

  def test_cannot_update_existing_value_to_one_that_begins_and_ends_with_parens
    value_that_begins_and_ends_with_parens = '(foo)'
    card = create_card!(:name => 'for testing', STATUS => NEW)
    open_edit_enumeration_values_list_for(@project, STATUS)
    edit_enumeration_value_from_edit_page(@project, STATUS, NEW, value_that_begins_and_ends_with_parens)
    assert_error_message_without_html_content("Value cannot both start with '(' and end with ')'")
    open_card(@project, card)
    assert_value_not_present_for(STATUS, value_that_begins_and_ends_with_parens)
    assert_property_set_on_card_show(STATUS, NEW)
  end

  def test_cannot_update_existing_value_to_one_that_begins_and_ends_with_parens_for_hidden_property
    value_that_begins_and_ends_with_parens = '(foo)'
    card = create_card!(:name => 'for testing', STATUS => NEW)
    hide_property(@project, STATUS)
    open_edit_enumeration_values_list_for(@project, STATUS)
    edit_enumeration_value_from_edit_page(@project, STATUS, NEW, value_that_begins_and_ends_with_parens)
    assert_error_message_without_html_content("Value cannot both start with '(' and end with ')'")
    show_hidden_property(@project, STATUS)
    open_card(@project, card)
    assert_value_not_present_for(STATUS, value_that_begins_and_ends_with_parens)
    assert_property_set_on_card_show(STATUS, NEW)
  end

  def test_cannot_create_value_that_begins_and_ends_with_parens_via_excel_import_for_enum
    value_that_begins_and_ends_with_parens = '(foo)'
    card_number = 24
    header_row = ['number', STATUS]
    card_data = [[card_number, value_that_begins_and_ends_with_parens]]
    navigate_to_card_list_for(@project)
    import(excel_copy_string(header_row, card_data))
    @browser.assert_text_present("Validation failed: #{STATUS}: #{value_that_begins_and_ends_with_parens} is an invalid value. " + VALUE_CAN_NOT_START_WITH_PARENTHESIS)
    open_card(@project, card_number)
    assert_error_message("Card 24 does not exist.")
    open_edit_enumeration_values_list_for(@project, STATUS)
    assert_enum_value_not_present_on_enum_management_page(value_that_begins_and_ends_with_parens)
  end

  def test_cannot_update_existing_value_to_one_that_begins_and_ends_with_parens_excel_import
    value_that_begins_and_ends_with_parens = '(foo)'
    card = create_card!(:name => 'for testing', STATUS => NEW)
    value_that_begins_and_ends_with_parens = '(foo)'
    header_row = ['number', STATUS]
    card_data = [[card.number, value_that_begins_and_ends_with_parens]]
    navigate_to_card_list_for(@project)
    import(excel_copy_string(header_row, card_data))
    @browser.assert_text_present("Validation failed: #{STATUS}: #{value_that_begins_and_ends_with_parens} is an invalid value. " + VALUE_CAN_NOT_START_WITH_PARENTHESIS)
    open_card(@project, card)
    assert_value_not_present_for(STATUS, value_that_begins_and_ends_with_parens)
    assert_property_set_on_card_show(STATUS, NEW)
  end

  def test_enum_value_creation_trims_leading_and_trailing_whitespace
    enum_value_name = 'import & export'
    create_enumeration_value_for(@project, FEATURE, "       #{enum_value_name}     ")
    property_definition = Project.find_by_identifier(@project.identifier).find_property_definition_or_nil(FEATURE)
    enum_value_from_db = EnumerationValue.find(:first,
      :conditions => ["property_definition_id = ? and value = ?", property_definition.id, enum_value_name])

    assert_equal(enum_value_name, enum_value_from_db.value)

    create_enumeration_value_for(@project, FEATURE, " #{enum_value_name}           ")
    assert_error_message(VALUE_ALREADY_TAKEN_MESSAGE)

    # verify that additional valid enum values can be created
    enum_value_foo = create_enumeration_value_for(@project, FEATURE, 'foo')
    navigate_to_property_management_page_for(@project)
    assert_property_does_have_value(property_definition, enum_value_from_db.name)
    assert_property_does_have_value(property_definition, enum_value_foo.name)
  end

  def test_enum_value_creation_via_inline_editor_trims_leading_and_trailing_whitespace
    enum_value_name = 'import & export'
    new_value_with_leading_and_trailing_whitespace = "       #{enum_value_name}     "
    open_card(@project, @card.number)
    add_new_value_to_property_on_card_show(@project, FEATURE, new_value_with_leading_and_trailing_whitespace)
    assert_history_for(:card, @card.number).version(2).shows(:set_properties => {:feature => enum_value_name})

    property_definition = Project.find_by_identifier(@project.identifier).find_property_definition_or_nil(FEATURE)
    enum_value_from_db = EnumerationValue.find(:first,
      :conditions => ["property_definition_id = ? and value = ?", property_definition.id, enum_value_name])
    assert_equal(enum_value_name, enum_value_from_db.value)
  end

  def test_all_team_members_can_add_new_enum_values_via_inline_editor
    proj_admins_enum_value = 't & e'
    admins_enum_value = "wiki, pages"
    team_members_enum_value = "stuff?"

    open_card(@project, @card.number)
    add_new_value_to_property_on_card_show(@project, FEATURE, proj_admins_enum_value)
    assert_history_for(:card, @card.number).version(2).shows(:set_properties => {:feature => proj_admins_enum_value})

    navigate_to_card_list_for(@project)
    select_all
    click_edit_properties_button
    add_value_to_property_using_inline_editor_on_bulk_edit(FEATURE, admins_enum_value)
    open_card(@project, @card.number)
    assert_history_for(:card, @card.number).version(3).shows(:changed => FEATURE, :from => proj_admins_enum_value, :to => admins_enum_value)
    logout

    login_as_team_member
    open_card_for_edit(@project, @card.number)
    add_new_value_to_property_on_card_edit(@project, FEATURE, team_members_enum_value)
    save_card
    assert_history_for(:card, @card.number).version(4).shows(:changed => FEATURE, :from => admins_enum_value, :to => team_members_enum_value)

    navigate_to_property_management_page_for(@project)
    feature_property_definition = Project.find_by_identifier(@project.identifier).find_property_definition_or_nil(FEATURE)
    assert_property_does_have_value(feature_property_definition, proj_admins_enum_value)
    assert_property_does_have_value(feature_property_definition, admins_enum_value)
    assert_property_does_have_value(feature_property_definition, team_members_enum_value)
  end

  def test_can_create_new_value_for_standard_property_that_is_not_locked
    new_value = 'right now'
    second_new_value = 'immediate'
    third_new_value = 'done'
    open_card(@project, @card.number)
    add_new_value_to_property_on_card_show(@project, STATUS, new_value)
    assert_history_for(:card, @card.number).version(2).shows(:set_properties => {:status => new_value})

    navigate_to_card_list_for(@project)
    select_all
    click_edit_properties_button
    add_value_to_property_using_inline_editor_on_bulk_edit(STATUS, second_new_value)
    open_card(@project, @card.number)
    assert_history_for(:card, @card.number).version(3).shows(:changed => STATUS, :from => new_value, :to => second_new_value)

    open_card_for_edit(@project, @card.number)
    add_new_value_to_property_on_card_edit(@project, STATUS, third_new_value)
    save_card
    assert_history_for(:card, @card.number).version(4).shows(:changed => STATUS, :from => second_new_value, :to => third_new_value)

    navigate_to_property_management_page_for(@project)
    status_property_definition = Project.find_by_identifier(@project.identifier).find_property_definition_or_nil(STATUS)
    assert_property_does_have_value(status_property_definition, new_value)
    assert_property_does_have_value(status_property_definition, second_new_value)
    assert_property_does_have_value(status_property_definition, third_new_value)
  end

  def test_cannot_add_duplicate_value_via_inline_editor
    duplicate_value_upcased = IN_PROGRESS.upcase

    open_card(@project, @card.number)
    add_new_value_to_property_on_card_show(@project, STATUS, duplicate_value_upcased)
    assert_history_for(:card, @card.number).version(2).shows(:set_properties => {:status => IN_PROGRESS})

    navigate_to_card_list_for(@project)
    select_all
    click_edit_properties_button
    add_value_to_property_using_inline_editor_on_bulk_edit(STATUS, duplicate_value_upcased, false)
    open_card(@project, @card.number)
    assert_history_for(:card, @card.number).version(3).not_present

    open_card_for_edit(@project, @card.number)
    add_new_value_to_property_on_card_edit(@project, STATUS, duplicate_value_upcased)
    save_card
    assert_history_for(:card, @card.number).version(3).not_present

    navigate_to_property_management_page_for(@project)
    status_property_definition = Project.find_by_identifier(@project.identifier).find_property_definition_or_nil(STATUS)
    assert_property_does_not_have_value(status_property_definition, duplicate_value_upcased)
  end

  def test_cannot_delete_enum_values_that_are_set_on_cards_or_transitions_and_can_delete_ones_that_are_not_used
    status_property_definition = Project.find_by_identifier(@project.identifier).find_property_definition_or_nil(STATUS)

    card_set_to_new = create_card!(:name => 'new card', :status => NEW)
    transition_setting_to_closed = create_transition_for(@project, 'close', :set_properties => {:status => CLOSED})
    navigate_to_property_management_page_for(@project)
    @browser.click_and_wait("id=enumeration-values-#{status_property_definition.id}")
    assert_delete_not_present_for_enum_value(STATUS, NEW)
    assert_delete_not_present_for_enum_value(STATUS, CLOSED)

    delete_enum_value(STATUS, IN_PROGRESS)
    navigate_to_property_management_page_for(@project)
    assert_property_does_not_have_value(status_property_definition, IN_PROGRESS)
  end

  # bug 1186
  def test_cannot_create_two_enums_for_same_property_with_different_case
    existing_enum = 'Foo'
    @project.activate
    setup_property_definitions(:bar => [existing_enum])

    navigate_to_card_list_by_clicking(@project)
    property_definition = @project.find_property_definition('Bar')

    create_enumeration_value_for(@project, property_definition, existing_enum.upcase)
    assert_error_message(VALUE_ALREADY_TAKEN_MESSAGE)

    create_enumeration_value_for(@project, property_definition, existing_enum.downcase)
    assert_error_message(VALUE_ALREADY_TAKEN_MESSAGE)
  end

  #3619
  def test_cannot_create_value_that_begins_and_ends_with_parens_via_inline_value_editor
    value_that_begins_and_ends_with_parens = '(foo)'
    card = create_card!(:name => 'for testing')
    open_card(@project, card)
    add_new_value_to_property_on_card_show(@project, STATUS, value_that_begins_and_ends_with_parens)
    @browser.wait_for_element_present('error')
    assert_error_message_without_html_content("#{STATUS}: #{value_that_begins_and_ends_with_parens} is an invalid value. " + VALUE_CAN_NOT_START_WITH_PARENTHESIS)
    open_edit_enumeration_values_list_for(@project, STATUS)
    assert_enum_value_not_present_on_enum_management_page(value_that_begins_and_ends_with_parens)
    open_card(@project, card)
    assert_history_for(:card, @card.number).version(2).not_present
    assert_property_not_set_on_card_show(STATUS)
  end

  #3619
  def test_cannot_create_value_that_begins_and_ends_with_parens_via_bulk_editor
    value_that_begins_and_ends_with_parens = '(foo)'
    card = create_card!(:name => 'for testing')
    open_card(@project, card)
    navigate_to_card_list_for(@project)
    check_cards_in_list_view(card)
    click_edit_properties_button
    add_new_value_to_property_on_bulk_edit(@project, STATUS, value_that_begins_and_ends_with_parens)
    assert_error_message_without_html_content("#{STATUS}: #{value_that_begins_and_ends_with_parens} is an invalid value. " + VALUE_CAN_NOT_START_WITH_PARENTHESIS)
    open_edit_enumeration_values_list_for(@project, STATUS)
    assert_enum_value_not_present_on_enum_management_page(value_that_begins_and_ends_with_parens)
    open_card(@project, card)
    assert_history_for(:card, @card.number).version(2).not_present
    assert_property_not_set_on_card_show(STATUS)
  end

  #3620
  def test_cannot_create_value_that_begins_and_ends_with_parens_via_excel_import_for_enum_hidden_property
    value_that_begins_and_ends_with_parens = '(foo)'
    hide_property(@project, STATUS)
    card_number = 24
    header_row = ['number', STATUS]
    card_data = [[card_number, value_that_begins_and_ends_with_parens]]
    navigate_to_card_list_for(@project)
    import(excel_copy_string(header_row, card_data))
    @browser.assert_text_present("Validation failed: #{STATUS}: #{value_that_begins_and_ends_with_parens} is an invalid value. " + VALUE_CAN_NOT_START_WITH_PARENTHESIS)
    open_card(@project, card_number)
    assert_error_message("Card 24 does not exist.")
    open_edit_enumeration_values_list_for(@project, STATUS)
    assert_enum_value_not_present_on_enum_management_page(value_that_begins_and_ends_with_parens)
  end

  #3620
  def test_cannot_update_existing_value_to_one_that_begins_and_ends_with_parens_excel_import_for_hidden_property
    value_that_begins_and_ends_with_parens = '(foo)'
    hide_property(@project, STATUS)
    card = create_card!(:name => 'for testing', STATUS => NEW)
    value_that_begins_and_ends_with_parens = '(foo)'
    card_number = 24
    header_row = ['number', STATUS]
    card_data = [[card.number, value_that_begins_and_ends_with_parens]]
    navigate_to_card_list_for(@project)
    import(excel_copy_string(header_row, card_data))
    @browser.assert_text_present("Validation failed: #{STATUS}: #{value_that_begins_and_ends_with_parens} is an invalid value. " + VALUE_CAN_NOT_START_WITH_PARENTHESIS)

    show_hidden_property(@project, STATUS)
    open_card(@project, card)
    assert_value_not_present_for(STATUS, value_that_begins_and_ends_with_parens)
    assert_property_set_on_card_show(STATUS, NEW)
  end

  # bug 3734
  def test_new_value_added_to_property_via_inline_editor_on_card_is_immediately_available_in_filter
    new_value = 'new value'
    card = create_card!(:name => 'for testing')
    open_card(@project, card)
    add_new_value_to_property_on_card_show(@project, FEATURE, new_value)
    assert_property_set_on_card_show(FEATURE, new_value)
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {FEATURE => new_value})
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :type => 'Card', FEATURE => new_value)
    assert_properties_present_on_card_list_filter(FEATURE => new_value)
  end

  # Bug 7747
  def test_value_should_be_escaped_in_the_drop_list
    setup_property_definitions(FEATURE => ["apple", "<h3>I</h3>"])
    card = create_card!(:name => 'I am card')

    open_card_for_edit(@project, card.number)
    click_property_on_card_edit(FEATURE)
    assert_values_present_in_property_drop_down_on_card_edit(FEATURE,["apple", "<h3>I</h3>"])
  end

  def test_delete_value_should_warn_user_related_consequences
    setup_property_definitions("feature" => ["apple", "pear"])
    create_personal_favorite_using_mql_condition(@project, "feature = apple", "my open cards")
    delete_enum_value("feature", "apple")
    @browser.assert_text_present("Any personal favorites that use this value will be deleted")
  end

  private
  def login_as_team_member
    login_as("#{@team_member.login}", 'longtest')
  end

  def assert_delete_not_present_for_enum_value(property_name, enum_value_name)
    enum_value = Project.find_by_identifier(@project.identifier).find_enumeration_value(property_name, enum_value_name)
    @browser.assert_element_not_present("delete-value-#{enum_value.id}")
  end

end
