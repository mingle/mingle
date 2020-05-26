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

# Tags: properties, cards, freetext-property, #2469, #2474
class Scenario48FreeformTextPropertiesTest < ActiveSupport::TestCase

  fixtures :users, :login_access
  FREETEXT_PROPERTY = 'address'
  FREETEXT_TYPE = 'any text'

  CREATION_SUCCESSFUL_MESSAGE = 'Property was successfully created.'
  NAME_ALREADY_TAKEN_MESSAGE = 'Name has already been taken'
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @admin = users(:admin)
    @team_member_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_46', :users => [@admin, @team_member_user])
    login_as_admin_user
    @card = create_card!(:name => 'new card')
  end

  def test_freeform_text_property_can_be_created_with_date_type
    freetext_property = create_property_definition_for(@project, FREETEXT_PROPERTY, :type => FREETEXT_TYPE)
    assert_notice_message(CREATION_SUCCESSFUL_MESSAGE)
    assert_property_exists(freetext_property)
  end

  def test_freeform_text_property_should_not_have_lock_unlock_links_and_no_link_for_this_property
    create_property_definition_for(@project, FREETEXT_PROPERTY, :type => FREETEXT_TYPE)
    assert_lock_check_box_not_present_for(@project, FREETEXT_PROPERTY)
    assert_card_property_link_not_present(@project, FREETEXT_PROPERTY)
  end

  def test_cannot_create_freeform_text_property_with_name_with_greater_than_forty_characters
    forty_character_name = 'this is exactly forty characters long hi'
    greater_than_forty_character_name = 'food very long what high nice stop fool stuff'
    property_with_valid_name_length = create_property_definition_for(@project, forty_character_name, :type => FREETEXT_TYPE)
    assert_notice_message(CREATION_SUCCESSFUL_MESSAGE)
    create_property_definition_for(@project, greater_than_forty_character_name, :type => FREETEXT_TYPE)
    assert_property_does_not_exist(greater_than_forty_character_name)
    assert_property_exists(property_with_valid_name_length)
  end

  def test_should_not_be_able_to_create_duplicate_freeform_text_property
    create_property_definition_for(@project, FREETEXT_PROPERTY, :type => FREETEXT_TYPE)
    assert_notice_message(CREATION_SUCCESSFUL_MESSAGE)
    create_property_definition_for(@project, FREETEXT_PROPERTY, :type => FREETEXT_TYPE)
    assert_error_message(NAME_ALREADY_TAKEN_MESSAGE)
  end

  def test_history_get_generated_for_freeform_text_property_been_added_or_edited
    property_def = create_property_definition_for(@project, FREETEXT_PROPERTY, :type => FREETEXT_TYPE)
    @browser.run_once_history_generation
    open_card(@project, @card.number)
    assert_history_for(:card, @card.number).version(1).present
    open_card(@project, @card.number)
    add_new_value_to_property_on_card_show(@project, FREETEXT_PROPERTY, '22 abc kent st')
    @browser.run_once_history_generation
    open_card(@project, @card.number)
    assert_history_for(:card, @card.number).version(2).shows(:set_properties => {FREETEXT_PROPERTY => '22 abc kent st' })
    add_new_value_to_property_on_card_show(@project, FREETEXT_PROPERTY, '24 abc kent st')
    @browser.run_once_history_generation
    open_card(@project, @card.number)
    assert_history_for(:card, @card.number).version(3).shows(:changed => FREETEXT_PROPERTY, :from => '22 abc kent st', :to => '24 abc kent st')
    assert_history_for(:card, @card.number).version(4).not_present
  end

  def test_deleting_text_property_deletes_it_on_cards_and_transitions_get_deleted
    freetext_value = '22 abc kent st'
    freetext_property = create_property_definition_for(@project, FREETEXT_PROPERTY, :type => FREETEXT_TYPE)
    open_card(@project, @card.number)
    add_new_value_to_property_on_card_show(@project, FREETEXT_PROPERTY, freetext_value)
    assert_properties_set_on_card_show(FREETEXT_PROPERTY => freetext_value)
    navigate_to_transition_management_for(@project)
    transition = create_transition_for(@project, 'trans1', :set_properties => {FREETEXT_PROPERTY => '(not set)'})
    assert_transition_present_for(@project, transition)
    navigate_to_property_management_page_for(@project)

    delete_property_for(@project, FREETEXT_PROPERTY)
    assert_notice_message("Property #{FREETEXT_PROPERTY} has been deleted.")
    assert_transition_not_present_for(@project, transition)
    open_card(@project, @card.number)
    assert_property_not_present_on_card_show(freetext_property)
  end

  def test_grid_view_does_not_showup_freeform_text_properties
    property_def = create_property_definition_for(@project, FREETEXT_PROPERTY, :type  => FREETEXT_TYPE)
    open_card(@project, @card.number)
    add_new_value_to_property_on_card_show(@project, property_def.name, 'abc')
    navigate_to_grid_view_for(@project)
    @browser.click(group_by_columns_drop_link_id)
    @browser.assert_element_not_present(group_by_columns_option_id(FREETEXT_TYPE))
    assert_property_not_present_in_color_by(FREETEXT_TYPE)
  end

  def test_cards_can_be_bulk_edited
    cards = HtmlTable.new(@browser, 'cards', ['Number', FREETEXT_PROPERTY], 1, 1)
    property_def = create_property_definition_for(@project, FREETEXT_PROPERTY, :type => FREETEXT_TYPE)
    assert_notice_message(CREATION_SUCCESSFUL_MESSAGE)
    create_cards(@project, 2)
    navigate_to_card_list_by_clicking(@project)
    select_all
    click_edit_properties_button
    add_value_to_free_text_property_using_inline_editor_on_bulk_edit(FREETEXT_PROPERTY, 'nice one')
    assert_property_set_in_bulk_edit_panel(@project, FREETEXT_PROPERTY, 'nice one')
    add_column_for(@project, [FREETEXT_PROPERTY])
    cards.assert_row_values(3, ['1', 'new card', 'nice one'])
    cards.assert_row_values(2, ['2', 'card 1', 'nice one'])
    cards.assert_row_values(1, ['3', 'card 2', 'nice one'])
  end

  # bug 2469
  def test_freeform_text_property_not_available_in_filters
    property_def = create_property_definition_for(@project, FREETEXT_PROPERTY, :type  => FREETEXT_TYPE)
    assert_notice_message(CREATION_SUCCESSFUL_MESSAGE)
    create_card!(:name => 'new card2', :card_type  => 'Card', FREETEXT_PROPERTY  =>  'abc abc')
    click_all_tab
    set_the_filter_value_option(0, 'Card')
    add_new_filter
    assert_filter_property_not_present_on(1, :properties => [FREETEXT_PROPERTY])
  end

  #bug 2474
  def test_free_text_property_value_containing_apostophe_and_backslash_does_not_break_editor
    value_with_apostrophe = "jen's"
    value_with_back_slash = "whatever\\"
    ordinary_value = 'some text'
    setup_text_property_definition(FREETEXT_PROPERTY)
    card = create_card!(:name => 'has free text')
    open_card(@project, card.number)
    add_new_value_to_property_on_card_show(@project, FREETEXT_PROPERTY, value_with_apostrophe)
    add_new_value_to_property_on_card_show(@project, FREETEXT_PROPERTY, ordinary_value)
    add_new_value_to_property_on_card_show(@project, FREETEXT_PROPERTY, value_with_back_slash)
    add_new_value_to_property_on_card_show(@project, FREETEXT_PROPERTY, ordinary_value)
    
    open_card(@project, card.number)
    
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {FREETEXT_PROPERTY => value_with_apostrophe})
    assert_history_for(:card, card.number).version(3).shows(:changed => FREETEXT_PROPERTY, :from => value_with_apostrophe, :to => ordinary_value)
    assert_history_for(:card, card.number).version(4).shows(:changed => FREETEXT_PROPERTY, :from => ordinary_value, :to => value_with_back_slash)
    assert_history_for(:card, card.number).version(5).shows(:changed => FREETEXT_PROPERTY, :from => value_with_back_slash, :to => ordinary_value)
  end

  #bug 2390
  def test_versions_does_not_get_duplicated_on_free_form_text_properties
    resolution = 'resolution'
    value_for_resolution = 'this is fun'
    setup_text_property_definition(resolution)
    card = create_card!(:name => 'simple card with free text property')
    open_card(@project, card.number)
    add_new_value_to_property_on_card_show(@project, resolution, value_for_resolution)
    @browser.run_once_history_generation
    open_card(@project, card.number)
    
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {resolution => value_for_resolution})
    assert_history_for(:card, card.number).version(3).not_present
  end
  
  #3627
  def test_cannot_create_value_that_begins_and_ends_with_parens_via_excel_import_for_freetext
    free_text_property = 'resolution'
    setup_text_property_definition(free_text_property)
    value_that_begins_and_ends_with_parens = '(foo)'
    card_number = 24
    header_row = ['number', free_text_property]
    card_data = [[card_number, value_that_begins_and_ends_with_parens]]
    navigate_to_card_list_for(@project)
    import(excel_copy_string(header_row, card_data))
    @browser.assert_text_present("Validation failed: #{free_text_property}: #{value_that_begins_and_ends_with_parens} is an invalid value. Value cannot both start with '(' and end with ')'")
    open_card(@project, card_number)
    assert_error_message("Card 24 does not exist.")
  end
  
  #3627
  def test_cannot_create_value_that_begins_and_ends_with_parens_via_excel_import_for_freetext_hidden_property
    free_text_property = 'resolution'
    setup_text_property_definition(free_text_property)
    value_that_begins_and_ends_with_parens = '(foo)'
    hide_property(@project, free_text_property)
    card_number = 24
    header_row = ['number', free_text_property]
    card_data = [[card_number, value_that_begins_and_ends_with_parens]]
    navigate_to_card_list_for(@project)
    import(excel_copy_string(header_row, card_data))
    @browser.assert_text_present("Validation failed: #{free_text_property}: #{value_that_begins_and_ends_with_parens} is an invalid value. Value cannot both start with '(' and end with ')'")
    open_card(@project, card_number)
    assert_error_message("Card 24 does not exist.")
  end
end
