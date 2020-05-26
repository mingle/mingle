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
class Scenario09ExcelImport2Test < ActiveSupport::TestCase

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

  def test_first_alphanumeric_with_spaces_column_becomes_name_when_no_column_called_name
    cards = HtmlTable.new(@browser, 'cards', ['Number', 'Name', 'Status', 'Summary'], 1, 1)
    header_row = ['Number', 'Status', 'Requirement', 'Summary']
    card_data = [
      ['234', "#{@send_email_card.cp_status}", "#{@send_email_card.name}", "#{@send_email_card.description}"],
      ['233', "#{@crud_user_card.cp_status}", "#{@crud_user_card.name}", "#{@crud_user_card.description}"]
      ]
    import(excel_copy_string(header_row, card_data))
    add_column_for(@project, ['summary'])
    cards.assert_row_values(1, ['234', "#{@send_email_card.name}", "#{@send_email_card.cp_status}", "#{@send_email_card.description}"])
    cards.assert_row_values(2, ['233', "#{@crud_user_card.name}", "#{@crud_user_card.cp_status}", "#{@crud_user_card.description}"])
  end

  def test_column_with_empty_value_doesnt_get_tagged
    cards = HtmlTable.new(@browser, 'cards', ['Number', 'Name', 'Iteration'], 1, 1)
    header_row = ['Number', 'Name', 'Iteration']
    card_data = [
      ['76', "#{@send_email_card.name}", ''],
      ['#75', "#{@crud_user_card.name}", "#{@crud_user_card.cp_iteration}"]
    ]
    import(excel_copy_string(header_row, card_data))
    add_column_for(@project, ['iteration'])
    cards.assert_row_values(1, ['76', "#{@send_email_card.name}", '', ''])
    cards.assert_row_values(2, ['75', "#{@crud_user_card.name}", '', "#{@crud_user_card.cp_iteration}"])
  end

  def test_excel_import_without_column_headers_still_allows_user_to_import
    card_data = [['4', "Story 4", "CSS"], ["5", "Story 5", "Add new product", "status-new"], ["6", "Story 6", "Add new admin", "update"]]
    import(excel_copy_string([], card_data))
    assert_import_complete_with(:rows  => 2, :rows_created  => 2)
  end

  def test_recognize_dates_column_as_date_property
    cards = HtmlTable.new(@browser, 'cards', ['Number', 'Modified on (2.3.1)'], 1, 1)
    header_row = ['Number', 'Modified on (2.3.1)']
    card_data = [
      ['#4', '2/05/08'],
      ['#3', '2 march 79'],
      ['#2', '25 Dec 68'],
      ['#1', '30 Nov 69']
    ]
    import(excel_copy_string(header_row, card_data))
    add_column_for(@project, ['Modified on (2.3.1)'])
    cards.assert_row_values(4, ['1', 'Card 1', '', '30 Nov 1969'])
    cards.assert_row_values(3, ['2', 'Card 2', '', '25 Dec 2068'])
    cards.assert_row_values(2, ['3', 'Card 3', '', '02 Mar 1979'])
    cards.assert_row_values(1, ['4', 'Card 4', '', '02 May 2008'])
  end

  def test_should_not_be_able_to_import_invalid_date_format_on_new_date_property
    {'date1' => '23/25/2005', 'date2' => '2/29/07', 'date3' => '29:05:05', 'date4' => 'invalid'}.each do |column_name, invalid_date|
      import(excel_copy_string([column_name], [[invalid_date]]), {:map => {column_name => 'as new date property'}})
      assert_error_message("Row 1: #{column_name}: (<b>)?#{invalid_date}(</b>)? is an invalid date. Enter dates in (<b>)?dd mmm yyyy(</b>)? format or enter existing project variable which is available for this property.")
      click_all_tab
    end
  end

  def test_excel_import_takes_column_as_freeform_text_for_more_than_10_unique_entries
  header_row  = ['texxxxxt']
  card_data = [
    ['abc'], ['bcd'], ['cde'], ['def'], ['efg'], ['fgh'], ['ghi'], ['hij'], ['ijk'], ['jkl'], ['klm']
    ]
    preview(excel_copy_string(header_row, card_data))
    assert_selected_property_column_in_import_preview(header_row[0], CardImport::Mappings::ANY_TEXT_PROPERTY, "new #{CardImport::Mappings::ANY_TEXT_PROPERTY}")
  end

  def test_excel_import_takes_column_as_standard_proeprty_for_10_or_less_data_entries
  header_row  = ['texxxxxt']
  card_data = [
    ['abc'], ['bcd'], ['cde'], ['def'], ['efg'], ['fgh'], ['ghi'], ['hij'], ['ijk']
    ]
    preview(excel_copy_string(header_row, card_data))
    assert_selected_property_column_in_import_preview(header_row[0], CardImport::Mappings::TEXT_LIST_PROPERTY, "new #{CardImport::Mappings::TEXT_LIST_PROPERTY}")
  end

  def test_excel_import_takes_column_as_standard_proeprty_if_not_unique_records
   header_row  = ['texxxxxt']
   card_data = [
     ['abc'], ['bcd'], ['cde'], ['def'], ['efg'], ['fgh'], ['ghi'], ['hij'], ['ijk'], ['abc'], ['abc']
     ]
     preview(excel_copy_string(header_row, card_data))
     assert_selected_property_column_in_import_preview(header_row[0], CardImport::Mappings::TEXT_LIST_PROPERTY, "new #{CardImport::Mappings::TEXT_LIST_PROPERTY}")
  end

  def test_existing_text_property_should_be_fetched_during_import_and_no_other_properties_except_ignore_for_that_column
    address = 'Address'
    cards = HtmlTable.new(@browser, 'cards', ['Number', address], 1, 1)
    setup_text_property_definition(address)
    header_row  = [address]
    card_data = [
      ['abc no york st'],
      ['bcd carrington st'],
      ['bcd carrington st'],
      ['def'],
      ]
    preview(excel_copy_string(header_row, card_data))
    assert_selected_property_column_in_import_preview(header_row[0], CardImport::Mappings::ANY_TEXT_PROPERTY)
    assert_in_import_preview_does_not_contain_property_value(header_row[0], 'status')
    assert_in_import_preview_contain_property_value(header_row[0], 'ignore')
    import_from_preview()
    assert_import_complete_with(:rows  => 4, :rows_created  => 4)
    add_column_for(@project, [address])
    cards.assert_row_values(4, ['1', 'Card 1', '', 'abc no york st'])
    cards.assert_row_values(3, ['2', 'Card 2', '', 'bcd carrington st'])
    cards.assert_row_values(2, ['3', 'Card 3', '', 'bcd carrington st'])
    cards.assert_row_values(1, ['4', 'Card 4', '', 'def'])
  end

  def test_greater_than_255_chars_should_not_be_allowd_to_be_imported_as_property_otherthan_description_it_should_throw_error
    header_row = ['status']
    card_data_more_than255 = [['this text is greater than 255 char long should be only taken as description and thrown error when tried to import it for a property... this text is greater than 255 char long should be only taken as description and thrown error. check this out............dfgdgdfg ']]
    card_data_less_than555 = [['this text is greater than 255 char long should be only taken as description and thrown error when tried to import it for a property... this text is greater than 255 char long should be only taken as description and thrown error. check this out enter fdfgg']]
    preview(excel_copy_string(header_row, card_data_more_than255), :failed => true, :error_message => "Cards were not imported. All fields other than (<b>)?Card Description(</b>)? are limited to 255 characters. The following field is too long: Row 1 \\((<b>)?status(</b>)?\\)")

    click_all_tab
    preview(excel_copy_string(header_row, card_data_less_than555))
    assert_selected_property_column_in_import_preview('status', CardImport::Mappings::TEXT_LIST_PROPERTY)
  end

  # bug 312
  def test_only_very_first_numerical_column_used_for_number_when_no_column_called_number_exists
    cards = HtmlTable.new(@browser, 'cards', ['number', 'name', 'iteration', 'size'], 1, 1)
    header_row = ['name', 'iteration', 'size']
    card_data = [
      [@crud_user_card.name, @crud_user_card.cp_iteration, @crud_user_card.cp_size],
      [@new_product_card.name, @new_product_card.cp_iteration, @new_product_card.cp_size]
    ]
    import(excel_copy_string(header_row, card_data))

    add_column_for(@project, ['iteration', 'size'])
    cards.assert_row_values(1, ['2', "#{@new_product_card.name}", "", "#{@new_product_card.cp_iteration}", "#{@new_product_card.cp_size}"])
    cards.assert_row_values(2, ['1', "#{@crud_user_card.name}", "", "#{@crud_user_card.cp_iteration}", "#{@crud_user_card.cp_size}"])
  end

  # bug 316, 421 & 1518
  def test_mingle_provides_card_name_when_user_does_not_provide_one
    card_name_error_message = "Some cards being imported do not have a card name. If you continue, Mingle will provide a generic card name."

    priority = 'Priority'
    setup_property_definitions(priority => [])

    #testing when number is included in spreadsheet
    header_row_with_number = ['Number', 'Story', priority]
    card_data_with_number = [['32', 'email', 'urgent']]
    preview(excel_copy_string(header_row_with_number, card_data_with_number))
    assert_warning_message_matches(card_name_error_message) #bug 421
    import_from_preview
    assert_import_complete_with(:rows  => 1, :rows_created  => 1)
    @browser.assert_text_present "Card 32"

    #testing when number is not included in spreadsheet
    header_row_without_number = [priority]
    card_data_without_number = [["low"]]
    preview(excel_copy_string(header_row_without_number, card_data_without_number))
    assert_warning_message_matches(card_name_error_message) #bug 421
    import_from_preview
    assert_import_complete_with(:rows  => 1, :rows_created  => 1)
    @browser.assert_text_present "Card 33"
    @browser.assert_text_not_present 'Untitled'
  end

  # bug 4006
  def test_mingle_provides_card_name_and_type_when_user_does_not_even_provide_blank_spaces_or_hyphens_for_them
    warning_for_card_name = "Some cards being imported do not have a card name. If you continue, Mingle will provide a generic card name."
    warning_for_card_type = "Some cards being imported do not have a card type. If you continue, Mingle will provide the first card type which is Card in current project."
    header_row_with_number = ['Number', 'Name', 'Type']
    card_data_with_number = [['1', 'some name', 'Card'], ['2']]
    preview(excel_copy_string(header_row_with_number, card_data_with_number))
    assert_warning_message(warning_for_card_name+warning_for_card_type)
  end

  # bug 325, changed in #1426 which reverses #325 because the old restrictions do not apply
  def test_hyphens_are_allowed_in_header_values
    header_row = ['Number', 'Name', 'hyp-hen']
    card_data = [['#3', "#{@send_email_card.name}", "#{@send_email_card.cp_iteration}"]]
    import(excel_copy_string(header_row, card_data))
    assert_import_complete_with(:rows  => 1, :rows_created  => 1)

    cards = HtmlTable.new(@browser, 'cards', ['number', 'name'], 1, 1)
    add_column_for(@project, ['hyp-hen'])
    cards.assert_row_values(1, ['3', "#{@send_email_card.name}", '', "#{@send_email_card.cp_iteration}"])

    header_row = ['Number', 'Name', 'Iteration-']
    card_data = [['#5', "#{@crud_user_card.name}", "#{@crud_user_card.cp_iteration}"]]
    import(excel_copy_string(header_row, card_data))
    assert_import_complete_with(:rows  => 1, :rows_created  => 1)
    cards = HtmlTable.new(@browser, 'cards', ['number', 'name'], 1, 1)
    add_column_for(@project, ['Iteration-'])

    cards.assert_row_values(1, ['5', "#{@crud_user_card.name}", '', '', "#{@crud_user_card.cp_iteration}"])
    header_row = ['Number', 'Name', '-Iteration']
    card_data = [['#7', "#{@new_product_card.name}", "#{@new_product_card.cp_iteration}"]]
    import(excel_copy_string(header_row, card_data))
    assert_import_complete_with(:rows  => 1, :rows_created  => 1)
    cards = HtmlTable.new(@browser, 'cards', ['number', 'name'], 1, 1)
    add_column_for(@project, ['-Iteration'])
    cards.assert_row_values(1, ['7', "#{@new_product_card.name}", '', '', '', "#{@new_product_card.cp_iteration}"])
  end

  # bug 419
  def test_card_name_should_keep_when_choose_ignore_it_in_import_preview
    card_name = "new card for bug 419 test"
    description = 'this is for bug 419 test'
    create_new_card(@project, :name => card_name, :description => description, :status => 'new')

    header_row = ['Number', 'Name', 'Description', 'Status']
    card_data = [['1', card_name, description, 'done']]
    import(excel_copy_string(header_row, card_data), :map  => {'Name' => '(ignore)', 'Description' => '(ignore)'})

    @browser.open "/projects/#{@project.identifier}/cards/list?columns=status"
    cards = HtmlTable.new(@browser, 'cards', ['number', 'name', 'status'], 1, 1)
    cards.assert_row_values(1, ['1', card_name, 'done'])
  end

  # for bug 423
  def test_should_return_back_import_review_page_and_show_error_message_and_remember_the_user_selection_when_error_happen_during_importing
    card_name = "new card for bug 423 test"
    description = 'this is for bug 423 test'

    header_row = ['Number', 'Name', 'a_Description', 'Status']
    card_data = [['1', card_name, description, 'done']]
    import(excel_copy_string(header_row, card_data), :map => {'a_Description' => 'as card name', "Status" => "(ignore)"})

    @browser.assert_text_present 'Multiple columns are marked as card name.'

    @browser.assert_value 'a_description_import_as', 'name'
    @browser.assert_value 'status_import_as', 'ignore'
    @browser.assert_value 'name_import_as', 'name'
    @browser.assert_value 'number_import_as', 'number'
  end

  # bug 856
  def test_validation_for_blank_import
    navigate_to_card_list_for(@project)
    preview('', :failed => true, :error_message => 'Please reread import instructions and paste data below.')

    click_up_link
    preview('                                   ', :failed => true, :error_message => 'Please reread import instructions and paste data below.')
  end

end
