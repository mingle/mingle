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
class Scenario09ExcelImport1Test < ActiveSupport::TestCase

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

  #bug 8619
  def test_import_card_data_should_give_a_friendly_error_when_newlines_are_in_property_names
    new_project = create_project(:prefix => 'scenario_09_3', :admins => [users(:admin), users(:proj_admin)])
    login_as_admin_user
    navigate_to_card_list_for(new_project)
    header_row = ['name', 'type', "\"new\nproperty\"", "otherproperty"]
    card_data = [['cardname', 'Card', 'pval1', "pval2"]]
    # 'Unable to create property new\nproperty. It contains a newline or carriage return character.'
    preview(excel_copy_string(header_row, card_data), :error_message => "Unable to create property new(\\\\r)?\\\\nproperty. It contains a newline or carriage return character.", :failed => true)
  end

  #bug 5003
  def test_project_admin_can_create_new_card_type_via_importing_from_excel
    #new_project = create_project(:prefix => 'scenario_09_2', :admins => [users(:proj_admin)])
    new_project = create_project(:prefix => 'scenario_09_3', :admins => [users(:admin), users(:proj_admin)])
    login_as_admin_user
    navigate_to_card_list_for(new_project)
    header_row = ['number', 'name', 'type']
    card_data = [['1', 'card1', 'card1'], ['2', 'card2', 'card2']]
    import(excel_copy_string(header_row, card_data))
    login_as_proj_admin_user
    navigate_to_card_list_for(new_project)
    header_row_1 = ['number', 'name', 'type']
    card_data_1 = [['3', 'story1', 'story'], ['4', 'defect1', 'defect']]
    import(excel_copy_string(header_row_1, card_data_1))
    navigate_to_card_list_for(new_project)
    navigate_to_card_type_management_for(new_project)
    assert_card_type_present(new_project, 'story')
  end

  # bug #4858
  def test_new_card_types_available_in_interactive_filters_after_excel_import
    new_project = create_project(:prefix => 'scenario_09_2', :admins => [users(:proj_admin)])
    login_as_admin_user
    navigate_to_card_list_for(new_project)
    header_row = ['number', 'name', 'type']
    card_data = [['1', 'card1', 'card1'], ['2', 'card2', 'card2']]
    import(excel_copy_string(header_row, card_data))
    assert_filter_value_present_on(0, :property_values => ['card1', 'card2'])
    set_the_filter_value_option(0, 'card1')
    card1 = new_project.cards.find_by_name('card1')
    card2 = new_project.cards.find_by_name('card2')
    assert_card_present_in_list(card1)
    assert_cards_not_present_in_list(card2)
  end

  def test_excel_import_sets_property_to_not_set_when_cell_for_that_property_is_blank
    card_with_property_set = create_card!(:name => 'card to be updated', :release => '4')
    header_row = ['number', 'name', 'RELEASE']
    card_data = [[card_with_property_set.number, 'new name', '']]
    import(excel_copy_string(header_row, card_data))
    open_card(@project, card_with_property_set.number)
    assert_properties_set_on_card_show(:release => '(not set)')
  end

  def test_during_update_property_value_of_existing_card_is_kept_if_property_column_is_not_present
    card_with_property_set = create_card!(:name => 'card to be updated', :release => '8', :status => 'deferred')
    header_row = ['number', 'name']
    card_data = [[card_with_property_set.number, 'new name for status release']]
    import(excel_copy_string(header_row, card_data))
    open_card(@project, card_with_property_set.number)
    assert_properties_set_on_card_show(:release => '8', :status => 'deferred')
  end

  def test_card_with_unclosed_HTML_tag_as_name_could_be_imported
    header_row = ['name']
    card_data = [['<style>']]
    import(excel_copy_string(header_row, card_data))
    card = @project.cards.find_by_name('<style>')
    assert_card_present_in_list(card)
  end

  def test_during_update_name_is_not_changed_if_name_column_is_not_present_or_name_cell_is_blank
    first_card = create_card!(:name => 'first card', :status => 'open')
    header_row_without_name_column = ['NUMBER', 'status']
    card_data = [[first_card.number, 'deferred']]
    import(excel_copy_string(header_row_without_name_column, card_data))
    open_card(@project, first_card.number)
    assert_properties_set_on_card_show(:status => 'deferred')
    assert_card_name_in_show(first_card.name)

    navigate_to_card_list_for(@project)
    header_row_with_name_column = ['number', 'NAME', 'release']
    card_data = [
      [first_card.number, '', '5'],
      ['37', 'newest card']
    ]
    import(excel_copy_string(header_row_with_name_column, card_data))
    open_card(@project, first_card.number)
    assert_properties_set_on_card_show(:status => 'deferred', :release => '5')
    assert_card_name_in_show(first_card.name)
    open_card(@project, 37)
    assert_properties_not_set_on_card_show('release')
    assert_card_name_in_show('newest card')
  end

  def test_can_import_with_macros_in_description
    header_row = ['Number', 'Name', 'Description']
    card_data = [[1, "with macro", "<p>project name is: {{ project }}</p> <p>&#123;&#123; I'm not a macro so should not blow up &#125;&#125;</p> {{ table query: select number, name where number > 0 }}"]]
    import(excel_copy_string(header_row, card_data))
    open_card(@project, 1)
    description_from_browser_with_tags_stripped = @browser.get_inner_html("card-description")

    assert description_from_browser_with_tags_stripped.include?(@project.identifier)
    assert description_from_browser_with_tags_stripped.include?("{{ I'm not a macro so should not blow up }}")
    assert description_from_browser_with_tags_stripped.normalize_whitespace.include?("Number Name 1 with macro") # table macro output
  end

  def test_description_is_not_changed_if_description_column_is_not_present_or_description_cell_is_blank
    first_card = create_card!(:name => 'the stuff', :description => 'very intersting and important stuff')
    header_row_without_description_column = ['NUMBER', 'status']
    card_data = [[first_card.number, 'done']]
    import(excel_copy_string(header_row_without_description_column, card_data))
    open_card(@project, first_card.number)
    assert_properties_set_on_card_show(:status => 'done')
    assert_card_description_in_show(first_card.description)
  end

  def test_updating_card_via_excel_import_correctly_updates_card_history
    card = create_card!(:name => 'card one', :status => 'new', :tags => 'foo bar')
    header_row = ['number', 'status', 'release', 'tags']
    card_data = [[card.number, '', '14', 'uxp, scope']]
    import(excel_copy_string(header_row, card_data)) # v2
    @browser.run_once_history_generation
    open_card(@project, card.number)
    assert_history_for(:card, card.number).version(2).shows(:tags_removed => ['foo bar'], :tagged_with => %w(uxp scope),
      :set_properties => {:release => '14'}, :unset_properties => {:status => 'new'})

    new_name = 'new name for card one'
    header_row = ['name', 'Description', 'Number']
    card_data = [[new_name, 'some requirements', card.number]]
    navigate_to_card_list_for(@project)
    import(excel_copy_string(header_row, card_data)) # v3
    @browser.run_once_history_generation
    open_card(@project, card.number)
    assert_history_for(:card, card.number).version(3).shows(:changed => 'Description', :changed => 'Name', :from => card.name, :to => new_name)
  end

  def test_can_create_and_update_cards_from_tab_delimited_input_with_checklist_items
    new_description_for_existing_card = 'Updated this is the first card.'
    new_card_description = 'This is a new card.'
    card_number = create_new_card(@project, :name => 'super card')
    header_row = ['Number', 'Name', 'Description','Incomplete Checklist Items','Completed Checklist Items']
    card_data = [
      [card_number, 'Updated super card', new_description_for_existing_card, '', ''],
      ['7', 'Spanking new card', new_card_description,'new_incomplete_item','new_completed_item']
    ]
    import(excel_copy_string(header_row, card_data))
    assert_import_complete_with(:rows  =>  2,:rows_updated  =>  1, :rows_created  =>  1)
    click_card_on_list(card_number)
    assert_card_description_in_show(new_description_for_existing_card)
    click_all_tab
    click_card_on_list(7)
    assert_card_description_in_show(new_card_description)
    assert_checklist_items_on_card_show(['new_incomplete_item'], ['new_completed_item'])
  end

  def test_card_number_created_when_no_column_called_number_exists
    cards = HtmlTable.new(@browser, 'cards', ['number', 'name'], 1, 1)
    header_row = ['name']
    card_data = [[@new_product_card.name], [@crud_user_card.name]]
    import(excel_copy_string(header_row, card_data))
    cards.assert_row_values(1, ['2', "#{@crud_user_card.name}"])
    cards.assert_row_values(2, ['1', "#{@new_product_card.name}"])
  end

  def test_column_called_number_only_can_have_numerical_values
    header_row = ['Number', 'Name', 'Tags']
    card_data = [
      ['%^45w', 'Enters account name and password', 'initial'],
      ['2', @crud_user_card.name, 'initial']
    ]
    preview(excel_copy_string(header_row, card_data), :failed => true, :error_message =>  "Cards were not imported. (<b>)?%\\^45w(</b>)? is not a valid card number")
  end

  def test_should_escape_html_in_property_name_in_invalid_property_value_error_message
    setup_allow_any_text_property_definition("<h1>anytext</h1>")
    setup_managed_text_definition("<h1>managed</h1>", ["open", "closed"])

    header_row = ['Name', '<h1>managed</h1>', '<h1>anytext</h1>']
    card_data = [
      ['Enters account name and password', '(lookslikeplvbutisnotone)', '(anotherthingthatlookslikeplv)'],
    ]
    import(excel_copy_string(header_row, card_data))
    assert_error_message(/Row 1: Validation failed:.* &lt;h1&gt;managed&lt;\/h1&gt;: <(b|B)>\(lookslikeplvbutisnotone\)<\/(b|B)> is an invalid value. Value cannot both start with '\(' and end with '\)' unless it is an existing project variable which is available for this property./, :raw_html => true)
    assert_error_message(/Row 1: Validation failed:.* &lt;h1&gt;anytext&lt;\/h1&gt;: <(b|B)>\(anotherthingthatlookslikeplv\)<\/(b|B)> is an invalid value. Value cannot both start with '\(' and end with '\)' unless it is an existing project variable which is available for this property./, :raw_html => true)
  end

  # bug 2702
  def test_importing_with_less_column_headers_than_data_columns_should_ignore_column_without_header
    card_five_number = '5'
    card_five_description = 'Add new product'
    header_row = ['Number', 'Name', 'Description', BLANK]
    card_data = [
      [5, 'Story 5', card_five_description, 'new'],
      [6, 'Story 6', 'Add new admin', 'update']
    ]
    import(excel_copy_string(header_row, card_data))
    assert_import_complete_with(:rows  => 2, :rows_created  => 2)
    open_card(@project, 5)
    assert_card_description_in_show(card_five_description)
  end

  # bug 2702
  def test_importing_without_a_header_row_uses_first_row_as_header
    header_row = ['4', 'Story 4', BLANK]
    card_data = [
      ['five', 'Story 5', 'Add new product'],
      ['six', 'Story 6', 'Add new admin']
    ]
    import(excel_copy_string(header_row, card_data))
    assert_import_complete_with(:rows  => 2, :rows_created  => 2)
    add_column_for(@project, ['4'])
    cards = HtmlTable.new(@browser, 'cards', ['Number', 'Name', 'status', '4'], 1, 1)
    cards.assert_row_values(1, [2, 'Story 6', '', 'six'])
    cards.assert_row_values(2, [1, 'Story 5', '', 'five'])
    open_card(@project, 1)
  end

  def test_hash_number_can_be_interpreted_as_number_column_when_its_first_column
    cards = HtmlTable.new(@browser, 'cards', ['Number', 'Name', 'Iteration'], 1, 1)
    header_row = ['Key', 'Name', 'Iteration']
    card_data = [
      ['#3', "#{@send_email_card.name}", "#{@send_email_card.cp_iteration}"],
      ['#65', "#{@crud_user_card.name}", "#{@crud_user_card.cp_iteration}"]
    ]
    import(excel_copy_string(header_row, card_data))
    add_column_for(@project, ['iteration'])
    cards.assert_row_values(1, ['65', "#{@crud_user_card.name}", '', "#{@crud_user_card.cp_iteration}"])
    cards.assert_row_values(2, ['3', "#{@send_email_card.name}", '', "#{@send_email_card.cp_iteration}"])
  end

end
