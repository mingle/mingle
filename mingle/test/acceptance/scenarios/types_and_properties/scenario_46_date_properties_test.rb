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

# Tags: properties, cards, date-property
class Scenario46DatePropertiesTest < ActiveSupport::TestCase

  fixtures :users, :login_access

 CREATION_SUCCESSFUL_MESSAGE = 'Property was successfully created.'
 NAME_ALREADY_TAKEN_MESSAGE = 'Name has already been taken'
  VALID_VALUES_FOR_DATE_PROPERTY = [['01-05-07','01 May 2007'],['07/01/68','07 Jan 2068'],['1 august 69', '01 Aug 1969'],['29 FEB 2004', '29 Feb 2004']]
  DATE_PROPERTY = 'any date property'
  DATE_TYPE = 'date'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @admin = users(:admin)
    @team_member_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_46', :users => [@admin, @team_member_user])
    login_as_admin_user
    @project.activate
    @card = create_card!(:name => 'new card')
  end

  def test_property_can_be_created_with_date_type
    date_property = create_property_definition_for(@project, DATE_PROPERTY, :type => DATE_TYPE)
    assert_notice_message(CREATION_SUCCESSFUL_MESSAGE)
    assert_property_exists(date_property)
  end

  def test_date_property_should_not_have_lock_unlock_links_and_no_link_for_this_property
    create_property_definition_for(@project, DATE_PROPERTY, :type => DATE_TYPE)
    assert_lock_check_box_not_present_for(@project, DATE_PROPERTY)
    assert_card_property_link_not_present(@project, DATE_PROPERTY)
  end

  def test_cannot_create_date_property_with_name_with_greater_than_forty_characters
    forty_character_name = 'this is exactly forty characters long hi'
    greater_than_forty_character_name = 'food very long what high nice stop fool stuff'
    property_with_valid_name_length = create_property_definition_for(@project, forty_character_name, :type => DATE_TYPE)
    assert_notice_message(CREATION_SUCCESSFUL_MESSAGE)
    create_property_definition_for(@project, greater_than_forty_character_name, :type => DATE_TYPE)
    assert_property_does_not_exist(greater_than_forty_character_name)
    assert_property_exists(property_with_valid_name_length)
  end

  def test_should_not_be_able_to_create_duplicate_date_property
    create_property_definition_for(@project, DATE_PROPERTY, :type => DATE_TYPE)
    assert_notice_message(CREATION_SUCCESSFUL_MESSAGE)
    create_property_definition_for(@project, DATE_PROPERTY, :type => DATE_TYPE)
    assert_error_message(NAME_ALREADY_TAKEN_MESSAGE)
  end

  def test_different_valid_values_for_date_property_in_card_show_mode
    create_property_definition_for(@project, DATE_PROPERTY, :type => DATE_TYPE)
    assert_notice_message(CREATION_SUCCESSFUL_MESSAGE)
    open_card(@project, @card.number)
    VALID_VALUES_FOR_DATE_PROPERTY.each do |date_value, expected|
      add_new_value_to_property_on_card_show(@project, DATE_PROPERTY, date_value)
      assert_properties_set_on_card_show(DATE_PROPERTY => expected)
    end
  end

  def test_different_valid_values_for_date_property_in_card_edit_mode
    create_property_definition_for(@project, DATE_PROPERTY, :type => DATE_TYPE)
    assert_notice_message(CREATION_SUCCESSFUL_MESSAGE)
    open_card(@project, @card.number)
    VALID_VALUES_FOR_DATE_PROPERTY.each do |date_value, expected|
      click_edit_link_on_card
      add_new_value_to_property_on_card_edit(@project, DATE_PROPERTY, date_value)
      save_card
      assert_properties_set_on_card_show(DATE_PROPERTY => expected)
    end
  end

  def test_history_get_generated_for_date_property_been_added_or_edited
    property_def = create_property_definition_for(@project, DATE_PROPERTY, :type => DATE_TYPE)
    @browser.run_once_history_generation
    open_card(@project, @card.number)
    assert_history_for(:card, @card.number).version(1).present

    open_card(@project, @card.number)
    add_new_value_to_property_on_card_show(@project, DATE_PROPERTY, '22 Apr 1976')
    @browser.run_once_history_generation
    open_card(@project, @card.number)
    assert_history_for(:card, @card.number).version(2).shows(:set_properties => { DATE_PROPERTY => '22 Apr 1976' })

    add_new_value_to_property_on_card_show(@project, DATE_PROPERTY, '24 Apr 1977')
    @browser.run_once_history_generation
    open_card(@project, @card.number)
    assert_history_for(:card, @card.number).version(3).shows(:changed => DATE_PROPERTY, :from => '22 Apr 1976', :to => '24 Apr 1977')
  end

  def test_on_transition_will_have_today_as_a_property_value_to_set_on_property
    create_property_definition_for(@project, DATE_PROPERTY, :type => DATE_TYPE)
    navigate_to_transition_management_for(@project)
    @project.reload
    transition1 = create_transition_for(@project, 'AnyToToday', :set_properties => {DATE_PROPERTY => '(today)'})
    assert_transition_present_for(@project, transition1)
    open_card(@project, @card.number)
    assert_transition_present_on_card(transition1)
    click_transition_link_on_card(transition1)
    assert_date_property_set_to_todays_date(@project, DATE_PROPERTY)
  end

  def test_on_transition_will_have_today_as_a_property_value_to_set_as_prerequisite
    create_property_definition_for(@project, DATE_PROPERTY, :type => DATE_TYPE)
    navigate_to_transition_management_for(@project)
    transition1 = create_transition_for(@project, 'TodayToAny', :required_properties => {DATE_PROPERTY => '(today)'}, :set_properties => {DATE_PROPERTY => '(not set)'})
    assert_transition_present_for(@project, transition1)
    open_card(@project, @card.number)
    add_new_value_to_property_on_card_show(@project, DATE_PROPERTY, "(today)")
    assert_transition_present_on_card(transition1)
    click_transition_link_on_card(transition1)
    assert_properties_set_on_card_show(DATE_PROPERTY => '(not set)')
  end

  def test_deleting_date_property_deletes_it_on_cards_and_transitions_get_deleted
    temp_date = '22 Apr 1976'
    date_property = create_property_definition_for(@project, DATE_PROPERTY, :type => DATE_TYPE)
    open_card(@project, @card.number)
    add_new_value_to_property_on_card_show(@project, DATE_PROPERTY, temp_date)
    assert_properties_set_on_card_show(DATE_PROPERTY => temp_date)
    navigate_to_transition_management_for(@project)
    transition = create_transition_for(@project, 'anyToToday', :set_properties => {DATE_PROPERTY => '(today)'})
    assert_transition_present_for(@project, transition)
    navigate_to_property_management_page_for(@project)

    delete_property_for(@project, DATE_PROPERTY)
    assert_notice_message("Property #{DATE_PROPERTY} has been deleted.")
    assert_transition_not_present_for(@project, transition)
    open_card(@project, @card.number)
    assert_property_not_present_on_card_show(date_property)
  end

  def test_different_valid_values_for_date_property_in_card_bulk_edit_mode
    date_property_name = 'created_on_(2.3.1)'
    cards = HtmlTable.new(@browser, 'cards', ['Number', date_property_name], 1, 1)
    property_def = create_property_definition_for(@project, date_property_name, :type => 'date')
    assert_notice_message(CREATION_SUCCESSFUL_MESSAGE)
    create_cards(@project, 2)
    navigate_to_card_list_by_clicking(@project)
    select_all
    click_edit_properties_button
    add_value_to_date_property_using_inline_editor_on_bulk_edit(date_property_name, '22 Jan 68')
    assert_property_set_in_bulk_edit_panel(@project, date_property_name, '22 Jan 2068')
    add_column_for(@project, [date_property_name])
    cards.assert_row_values(3, ['1', 'new card', '22 Jan 2068'])
    cards.assert_row_values(2, ['2', 'card 1', '22 Jan 2068'])
    cards.assert_row_values(1, ['3', 'card 2', '22 Jan 2068'])
  end

  #bug 2263
  # something is fishy with this test when using ruby 1.8.6 -- 'first Feb 01' is not an
  # invalid date in 1.8.6., but even when removing that 'invalid' date the test still hangs ....
  def test_different_invalid_values_for_date_property_in_card_view_mode
    property_def = create_property_definition_for(@project, 'created_on_(2.3.1)', :type => 'date')
    assert_notice_message(CREATION_SUCCESSFUL_MESSAGE)
    card = create_card!(:name => 'some story')
    open_card(@project, card.number)
    add_new_value_to_property_on_card_show(@project, property_def, 'abcd')
    assert_error_message("abcd is an invalid date. Enter dates in (<b>)?dd mmm yyyy(</b>)? format or enter existing project variable which is available for this property.")
    add_new_value_to_property_on_card_show(@project, property_def, '')
  end
  
  # bug 2882
  def test_via_excel_import_can_set_value_of_date_property_to_today
    fake_now(1980, 04, 01)
    today_with_parens = '(today)'
    today_without_parens = 'today'
    todays_date_in_project_date_format = '01 Apr 1980'
    setup_date_property_definition(DATE_PROPERTY)
    navigate_to_card_list_for(@project)
    header_row = ['number', "#{DATE_PROPERTY}"]
    imported_card_number_that_used_parens = 15
    imported_card_number_that_did_not_use_parens = 17
    card_data = [
      [imported_card_number_that_used_parens, today_with_parens],
      [imported_card_number_that_did_not_use_parens, today_without_parens]
    ]
    preview(excel_copy_string(header_row, card_data))
    @browser.assert_text_not_present 'Error: (today)'
    @browser.assert_text_not_present 'Error: today'

    import_from_preview
    
    @browser.run_once_history_generation
    open_card(@project, imported_card_number_that_used_parens)
    assert_properties_set_on_card_show(DATE_PROPERTY => todays_date_in_project_date_format)
    assert_history_for(:card, imported_card_number_that_used_parens).version(1).shows(:set_properties => {DATE_PROPERTY => todays_date_in_project_date_format})
    
    open_card(@project, imported_card_number_that_did_not_use_parens)
    assert_properties_set_on_card_show(DATE_PROPERTY => todays_date_in_project_date_format)
    assert_history_for(:card, imported_card_number_that_did_not_use_parens).version(1).shows(:set_properties => {DATE_PROPERTY => todays_date_in_project_date_format})
  ensure
    @browser.reset_fake
  end
  
  # bug 2961
  def test_enum_value_creation_via_inline_editor_trims_leading_and_trailing_whitespace
    valid_date_value = '12 Apr 1943'
    valid_date_value_with_leading_and_trailing_whitespace = "       #{valid_date_value}     "
    setup_date_property_definition(DATE_PROPERTY)
    open_card(@project, @card.number)
    add_new_value_to_property_on_card_show(@project, DATE_PROPERTY, valid_date_value_with_leading_and_trailing_whitespace)
    assert_error_message_not_present
    @browser.assert_text_not_present("#{DATE_PROPERTY}: #{valid_date_value} is an invalid date. Enter dates in 'dd mmm yyyy' format or enter existing project variable which is available for this property.")
    
    @browser.run_once_history_generation
    open_card(@project, @card.number)
    assert_history_for(:card, @card.number).version(2).shows(:set_properties => {DATE_PROPERTY => valid_date_value})
    
    # jem -> need to find out how to check that the value in the db does not have the whitespace
    # project_from_db = Project.find_by_identifier(@project.identifier)
    #     property_definition = project_from_db.find_property_definition_or_nil(DATE_PROPERTY)
    #     @card.reload
    #     date_value_from_db = property_definition.value(@card)
    #     
    #     value_from_db = EnumerationValue.find(:first,
    #       :conditions => ["property_definition_id = ? and value = ?", property_definition.id, date_value_from_db])
    #     assert_equal(valid_date_value, date_value_from_db)
  end
end
