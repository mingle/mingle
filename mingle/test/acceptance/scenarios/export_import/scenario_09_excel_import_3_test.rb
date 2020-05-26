# -*- coding: utf-8 -*-

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

# Tags: excel_import
class Scenario09ExcelImport3Test < ActiveSupport::TestCase

  BLANK = ''
  EXISTING_DATE = 'Existing Date'

  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)

    @new_product_card = OpenStruct.new(:name => 'enter new product', :description => 'enter stuff', :cp_iteration => '14', :cp_size => '6', :cp_status => 'new')
    @crud_user_card = OpenStruct.new(:name => 'create user', :description => 'new user', :cp_iteration => '23', :cp_size => '4', :cp_status => 'open')
    @send_email_card = OpenStruct.new(:name => 'send email', :description => 'crud email', :cp_iteration => '5', :cp_size => '8', :cp_status => 'deferred')

    @browser = selenium_session
    @project = create_project(:prefix => 'scenario_09', :admins => [users(:proj_admin)])
    setup_property_definitions :status => ['new', 'open', 'done', 'deferred'], :release => [14, 4, 8]
    setup_date_property_definition EXISTING_DATE
    login_as_proj_admin_user
    navigate_to_card_list_showing_iteration_and_status_for(@project)
  end

  # bug 924
  def test_ignoring_excel_import_does_not_create_new_property_or_enum_value
    name = 'story one'
    property_status = 'status'
    property_priority = 'priority'
    enum_value = 'new'
    @project.reload.activate
    setup_property_definitions(:priority => [])
    priority_property_def =  Project.find_by_identifier(@project.identifier).find_property_definition_or_nil(property_priority)

    header_row = ['name', "#{property_status}", "#{property_priority}"]
    card_data = [[name], [enum_value], [enum_value]]
    preview(excel_copy_string(header_row, card_data))
    import_from_preview :map => { property_status => '(ignore)', property_priority => '(ignore)' }
    navigate_to_property_management_page_for(@project)
    assert_property_does_not_exist(property_status)
    assert_property_does_not_have_value(priority_property_def, enum_value)
  end

  # bug 1017
  def test_cannot_import_card_with_very_high_number
    too_high_number = Project::MAX_NUMBER + 1
    card_name = 'testing 1017'
    header_row = ['Number', 'Name']
    card_data = [[too_high_number, card_name]]
    preview(excel_copy_string(header_row, card_data), :failed => true, :error_message => "#{too_high_number} is too large to be used as a card number.")
    assert_no_cards_imported
  end

  # bug 1018
  def test_cannot_import_card_with_very_float_number
    invalid_card_number = '1.54'
    card_name = 'testing 1018'
    header_row = ['Number', 'Name']
    card_data = [[invalid_card_number, card_name]]
    preview(excel_copy_string(header_row, card_data), :failed => true, :error_message  => "Cards were not imported. (<b>)?#{invalid_card_number}(</b>)? is not a valid card number.")
    assert_no_cards_imported
  end

  # bug 1075
  def test_importing_properties_with_commas_does_not_break_card_edit
    card_number = 55
    property = 'client'
    enum_value_with_comma = 'company, city'
    new_name = 'new name'
    new_description = 'some description'

    header_row = ['number', 'name', property]
    card_data = [[card_number, 'new foo', enum_value_with_comma]]
    import(excel_copy_string(header_row, card_data))
    open_card(@project, card_number)
    edit_card(:name => new_name, :description => new_description)
    assert_properties_set_on_card_show(property => enum_value_with_comma)
    assert_card_name_in_show(new_name)
    assert_card_description_in_show(new_description)
  end

  # bug 1421
  def test_creating_user_properties_that_only_differ_by_special_characters_do_not_break_db
    property_with_space = 'foo bar'
    property_with_underscore = 'foo_bar'
    property_with_hyphen = 'foo-bar'
    card_number = '37'

    header_row = ['number', 'name', property_with_space, property_with_underscore, property_with_hyphen]
    card_data = [[card_number, 'testing property names', 'space', 'underscore', 'hyphen']]
    import(excel_copy_string(header_row, card_data))

    @browser.assert_element_not_present('error')
    @browser.assert_text_not_present('Column name has already been taken')

    open_card(@project, card_number)
    assert_properties_set_on_card_show(property_with_space => 'space', property_with_underscore => 'underscore', property_with_hyphen => 'hyphen')
  end

  # bug 1422
  def test_properties_that_differ_in_case_or_spacing_show_error_during_excel_import
    property_foo_all_lower = 'foo'
    property_foo_all_caps = 'FOO'
    header_row_case_difference = ['number', property_foo_all_lower, property_foo_all_caps]
    card_data = [['2', 'lower', 'caps']]
    preview(excel_copy_string(header_row_case_difference, card_data), :failed => true, :error_message => "Column headings have duplicate values, Mingle cannot import any cards.")
    property_foobar_with_one_space = 'foo bar'
    property_foobar_with_multiple_spaces = 'foo    bar'
    navigate_to_card_list_for(@project)
    header_row_different_spacing = ['number', property_foobar_with_one_space, property_foobar_with_multiple_spaces]
    card_data = [['2', 'one', 'multiple']]
    preview(excel_copy_string(header_row_different_spacing, card_data), :failed => true, :error_message => "Column headings have duplicate values, Mingle cannot import any cards.")
  end

  # bug 1431
  def test_import_does_not_create_blank_enum_values
    priority = 'Priority'
    blank = ''
    hyphen = ' - '
    setup_property_definitions(priority => [])
    header_row = ['name', priority]
    card_data = [
        ["card three", "low"],
        ["card four", blank],
        ["card five", hyphen],
        ["card six", "urgent"]
    ]
    preview(excel_copy_string(header_row, card_data))
    @browser.with_ajax_wait do
      @browser.click 'link=Next to complete import'
    end
    navigate_to_property_management_page_for(@project)
    priority_property_def = Project.find_by_identifier(@project.identifier).find_property_definition_or_nil(priority)
    assert_property_does_not_have_value(priority_property_def, blank)
    assert_property_does_not_have_value(priority_property_def, hyphen)
  end

  # bug 1533, 8251
  def test_property_name_too_long_or_is_reserved_word_shows_error_message
    header_row = ['name', 'food very long what high nice stop fool stuff']
    card_data = [ ['card one', 'foo'],
                  ['card two', 'bar'] ]
    preview(excel_copy_string(header_row, card_data), :failed => true, :error_message => "Property Name is too long")

    ['Project', 'modified on', 'created on', 'Project card rank'].each do |property|
      type_in_tab_separated_import excel_copy_string(['Name', property], [ ['card one', 'value'] ])
      submit_to_preview(:failed => true, :error_message => "Property Name #{property} is a reserved property name")
    end
  end

  def test_property_name_that_equals_to_40_characters
    forty_characters_name = 'aaaa bbbb cccc dddd eeee ffff eeee ggggg'
    header_row = ['name', forty_characters_name]
    card_data = [
      ['card one', 'foo'],
      ['card two', 'bar']
    ]
    preview(excel_copy_string(header_row, card_data))
    @browser.assert_text_not_present("Unable to create property")
  end

  #bug 1654
  def test_for_bug_1654
    first_card = create_card!(:name => 'the stuff', :description => 'very intersting and important stuff')
    header_row_without_description_column = ['NUMBER', 'status']
    card_data = [[first_card.number, 'done']]
    import(excel_copy_string(header_row_without_description_column, card_data))
    open_card(@project, first_card.number)
    assert_properties_set_on_card_show(:status => 'done')
    assert_card_description_in_show(first_card.description)

    navigate_to_card_list_for(@project)
    header_row_with_description_column = ['number', 'Description']
    card_data = [
      [first_card.number, ''],
      ['21', 'TBD in the future']
    ]
    import(excel_copy_string(header_row_with_description_column, card_data))
    open_card(@project, first_card.number)
    assert_card_description_in_show(first_card.description)
    open_card(@project, 21)
    assert_card_description_in_show('TBD in the future')
  end

  #bug 1679
  def test_can_handle_both_empty_and_populated_cells_in_number_column
    first_card = create_card!(:name => 'big story')

    name_for_card_without_number = 'some new stuff'
    header_row_without_tags_column = ['NUMBER', 'name', 'status']
    card_data = [
      [first_card.number, BLANK, 'open'],
      [BLANK, name_for_card_without_number,  'new'],
      ['235', 'card for story 235',  'new']
    ]
    import(excel_copy_string(header_row_without_tags_column, card_data))
    open_card(@project, 236)
    assert_card_name_in_show(name_for_card_without_number)
  end

  # bug 2380, and associated revert in which we decided that we would move all
  # property validations to after preview, and import as many cards as possible
  # and not stop a big import because of these kinds of validations
  def test_all_the_rows_getting_imported_except_the_error_once
    any_date_property = 'any date property'
    header_row = [any_date_property]
    card_data = [
      ['2/05/08'],
      ['error date'],
      ['25 Dec 68'],
    ]
    import(excel_copy_string(header_row, card_data), {:map => {any_date_property => 'as new date property'}})
    assert_error_message("Row 2: any date property: (<b>)?error date(</b>)? is an invalid date. Enter dates in (<b>)?dd mmm yyyy(<b>)? format or enter existing project variable which is available for this property.")
  end

  # bug 2319, changed to reflect the change to way we handle errors according to bug 2380
  def test_date_property_imported_will_get_the_first_card_type_by_default_if_not_specified_in_excel
    header_row = ['modified on (2.3.1)']
    card_data_valid = [['3/4/5']]
    import(excel_copy_string(header_row, card_data_valid))
    assert_notice_message("Importing complete, 1 row, 0 updated, 1 created, 0 errors.")
    navigate_to_property_management_page_for(@project)
    open_property_for_edit(@project,header_row[0])
    assert_card_types_checked_or_unchecked_in_create_new_property_page(@project, :card_types_checked  => ['Card'])
  end

  def assert_no_cards_imported
    click_all_tab
    assert_info_message("There are no cards for #{@project.name}")
  end

  # bug #2311
  def test_user_should_be_able_to_change_the_property_type_selected_by_import_if_there_are_no_exsisting_property_of_same_name
    header_row = ['status']
    card_data_valid = [['03 Aug 2007'],
    ['25 may 06'],
    ['jan 26 2009']
    ]
    preview(excel_copy_string(header_row, card_data_valid))
    assert_in_import_preview_contain_property_value(header_row[0], "as #{CardImport::Mappings::TEXT_LIST_PROPERTY}")
    assert_in_import_preview_contain_property_value(header_row[0], 'as type')
    assert_in_import_preview_contain_property_value(header_row[0], 'as tag')
  end

  #bug 2191, 1878
  def test_special_charecters_should_not_be_taken_as_properties_and_defaults_to_description
    header_row = ['sta#tus', 'prio&rity', 'discription]','[leads', 'status=new' ]
    card_data_valid = [['abc', 'sdfds#@', '4343FDF', 'wrgwrgwg', '$#fdfdf'],
    ['abc', 'sdfds#@', '4343FDF', 'wrgwrgwg', '$#fdfdf'],
    ['abc', 'sdfds#@', '4343FDF', 'wrgwrgwg', '$#fdfdf']
    ]
    preview(excel_copy_string(header_row, card_data_valid))
    assert_in_import_preview_contain_property_value(header_row[0], 'as description')
    assert_in_import_preview_contain_property_value(header_row[0], 'ignore')
    assert_in_import_preview_does_not_contain_property_value(header_row[0], "as #{CardImport::Mappings::TEXT_LIST_PROPERTY}")

    assert_in_import_preview_contain_property_value(header_row[1], 'as description')
    assert_in_import_preview_contain_property_value(header_row[1], 'ignore')
    assert_in_import_preview_does_not_contain_property_value(header_row[1], "as #{CardImport::Mappings::TEXT_LIST_PROPERTY}")

    assert_in_import_preview_contain_property_value(header_row[2], 'as description')
    assert_in_import_preview_contain_property_value(header_row[2], 'ignore')
    assert_in_import_preview_does_not_contain_property_value(header_row[2], "as #{CardImport::Mappings::TEXT_LIST_PROPERTY}")

    assert_in_import_preview_contain_property_value(header_row[3], 'as description')
    assert_in_import_preview_contain_property_value(header_row[3], 'ignore')
    assert_in_import_preview_does_not_contain_property_value(header_row[3], "as #{CardImport::Mappings::TEXT_LIST_PROPERTY}")

    assert_in_import_preview_contain_property_value(header_row[4], 'as description')
    assert_in_import_preview_contain_property_value(header_row[4], 'ignore')
    assert_in_import_preview_does_not_contain_property_value(header_row[4], "as #{CardImport::Mappings::TEXT_LIST_PROPERTY}")
  end

  # bug 2190
  def test_multibite_charecters_which_are_more_than_255_char_are_taken_as_description_by_default
    header_row = ['directions']
    card_data_valid = [['这是不公平的，因为它太长文本及其255焦长希望如此 这是不公平的，因为它太长文本及其255焦长希望如此 这是不公平的，因为它太长文本及其255焦长希望如此这是不公平的，因为它太长文本及其255焦长希望如此这是不公平的，因为它太长文本及其255焦长希望如此']]
    preview(excel_copy_string(header_row, card_data_valid))
    assert_selected_property_column_in_import_preview('directions', 'description', 'card description')
  end

  # bug 2720
  def test_clicking_back_link_on_preview_page_retains_user_entered_data_in_tab_separated_import_text_area
    card_name = 'testing stuff'
    preview(card_name)
    click_back_link
    @browser.ruby_wait_for("page after back link") do
      @browser.is_element_present(ExcelExportImportPageId::TAB_SEPERATED_IMPORT_ID)
    end
    assert_value_in_import_text_area("#{card_name}")
  end

  # Bug 3054.
  def test_valid_dates_should_not_display_error
    header_row = ['name', EXISTING_DATE]
    card_data = [
      ['valid date', '11/01/05']
    ]
    preview_table = preview(excel_copy_string(header_row, card_data))
    preview_table.assert_row_values(1, ['valid date', '11 Jan 2005'])
  end

end
