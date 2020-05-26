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

# Tags: numeric-properties
class Scenario64NumericPropertiesUsageTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  SIZE = 'size'


  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project = create_project(:prefix => 'scenario_64', :users => [users(:longbob)], :admins => [users(:proj_admin)])
    setup_numeric_property_definition(SIZE, [1, 2, 3, 4])
    login_as_proj_admin_user
  end

  def test_search_value_for_managed_numeric_property_on_card_edit
    sample_card = create_card!(:name => 'sample card')
    open_card_for_edit(@project, sample_card.number)
    click_property_on_card_edit(SIZE)

    type_keyword_to_search_value_for_property_on_card_edit(SIZE, 'HELLO')
    assert_values_not_present_in_property_drop_down_on_card_edit(SIZE, ['(not set)', 1, 2, 3, 4])
    type_keyword_to_search_value_for_property_on_card_edit(SIZE, 'N')
    assert_values_present_in_property_drop_down_on_card_edit(SIZE, ['(not set)'])
    assert_values_not_present_in_property_drop_down_on_card_edit(SIZE, [1, 2, 3, 4])
    type_keyword_to_search_value_for_property_on_card_edit(SIZE, '1')
    assert_values_present_in_property_drop_down_on_card_edit(SIZE, [1])
    assert_values_not_present_in_property_drop_down_on_card_edit(SIZE, [2, 3, 4])

    select_value_in_drop_down_for_property_on_card_edit(SIZE, 1)
    assert_edit_property_set(SIZE, '1')
  end

  def test_search_value_for_managed_numeric_property_on_card_show
    sample_card = create_card!(:name => 'sample card')
    open_card(@project, sample_card.number)
    click_property_on_card_show(SIZE)
    assert_value_present_in_property_drop_down_on_card_show(SIZE, ['(not set)', 1, 2, 3, 4])

    type_keyword_to_search_value_for_property_on_card_show(SIZE, 'hello')
    assert_value_not_present_in_property_drop_down_on_card_show(SIZE,['(not set)', 1, 2, 3, 4])
    type_keyword_to_search_value_for_property_on_card_show(SIZE, '2')
    assert_value_present_in_property_drop_down_on_card_show(SIZE, [2])
    assert_value_not_present_in_property_drop_down_on_card_show(SIZE, [1, 3, 4])
    type_keyword_to_search_value_for_property_on_card_show(SIZE, 'N')
    assert_value_present_in_property_drop_down_on_card_show(SIZE, ['(not set)'])
    assert_value_not_present_in_property_drop_down_on_card_show(SIZE, [1, 2, 3, 4])

    select_value_in_drop_down_for_property_on_card_show(SIZE, '(not set)')
    assert_property_set_on_card_show(SIZE, '(not set)')
  end

  def test_setting_hidden_numeric_property_via_transition
    transition_name = 'setting hidden size'
    hide_property(@project, SIZE)
    transition_setting_hidden = create_transition_for(@project, transition_name, :type => 'Card', :set_properties => {SIZE => 4})
    card_for_transitioning = create_card!(:name => 'testing hidden numeric properties', 'Type' => 'Card')
    open_card(@project, card_for_transitioning.number)
    click_transition_link_on_card(transition_setting_hidden)
    @browser.run_once_history_generation
    open_card(@project, card_for_transitioning.number)
    assert_history_for(:card, card_for_transitioning.number).version(2).shows(:set_properties => {SIZE => 4})
  end

  def test_should_be_able_to_filter_cards_by_numeric_list_property
    setup_card_type(@project, 'Story', :properties => [SIZE])
    story_1 = create_card!(:name => 'Story 1', :card_type => 'Story', SIZE => '2.00')
    story_2 = create_card!(:name => 'Story 2', :card_type => 'Story', SIZE => '8')
    card_1 = create_card!(:name => 'Story 1', :card_type => 'Card', SIZE => '2.00')

    filter_story_size2 = "filters[]=[Type][is][Story]&filters[]=[#{SIZE}][is][2]"
    set_filter_by_url(@project, filter_story_size2)
    assert_cards_present(story_1)
  end

  def test_add_numeric_values_on_card_show
    sample_card = create_card!(:name => 'Sample card')
    open_card(@project, sample_card.number)
    valid_numeric_values = ['1', '4.5', '5.99', '6.00']
    valid_numeric_values.each do |value|
      add_new_value_to_property_on_card_show(@project, SIZE, value)
      assert_properties_set_on_card_show(SIZE => value)
    end
  end

  def test_add_numeric_values_on_card_edit
    setup_allow_any_number_property_definition('Iteration')
    sample_card = create_card!(:name => 'sample card')
    valid_numeric_values = ['1', '4.5', '5.99', '6.00']
    valid_numeric_values.each do |value|
      open_card_for_edit(@project, sample_card.number)
      add_new_value_to_property_on_card_edit(@project, 'Iteration', value)
      save_card
      assert_property_set_on_card_show('Iteration', value)
    end
  end

  def test_set_property_value_as_current_value_on_card_show
    sample_card = create_card!(:name => 'Sample card', SIZE => '4.5')
    same_values = ['4.50', '04.50', '04.5', '4.500']
    same_values.each do |user_input_value|
      open_card(@project, sample_card.number)
      add_new_value_to_property_on_card_show(@project, SIZE, user_input_value)
      assert_properties_set_on_card_show(SIZE => '4.5')
      @browser.run_once_history_generation
      assert_history_for(:card, sample_card.number).version(2).not_present
    end
  end

  def test_cannot_add_non_numeric_values_on_card_show
    sample_card = create_card!(:name => 'Sample card', SIZE => '0.0')
    open_card(@project, sample_card.number)

    add_new_value_to_property_on_card_show(@project, SIZE, '.01a')
    assert_error_message("#{SIZE}: .01a is an invalid numeric value")
    assert_property_set_on_card_show(SIZE, '0.0')
  end

  def test_cannot_add_non_numeric_values_on_card_edit
    setup_allow_any_number_property_definition('Iteration')
    sample_card = create_card!(:name => 'Sample card', 'Iteration' => '2.00')

    open_card_for_edit(@project, sample_card.number)
    add_new_value_to_property_on_card_edit(@project, 'Iteration', '%123')
    save_card_with_flash
    assert_error_message("Iteration: %123 is an invalid numeric value")
    assert_property_set_on_card_edit('Iteration', '2.00')
  end

  def test_can_not_add_non_numeric_value_for_property_on_property_management_page
    sample_card = create_card!(:name => 'Sample card', SIZE => '0')
    @browser.run_once_history_generation
    open_card(@project, sample_card.number)
    assert_history_for(:card, sample_card.number).version(1).present

    edit_enumeration_value_for(@project, SIZE, '0', 'foo')
    assert_error_message_without_html_content("Value foo is an invalid numeric value")
    @browser.run_once_history_generation

    open_card(@project, sample_card.number)
    assert_history_for(:card, sample_card.number).version(2).not_present
  end

  def test_can_set_zero_as_numeric_value_for_numeric_property_on_card_show
    sample_card = create_card!(:name => 'sample card')
    open_card(@project, sample_card.number)

    add_new_value_to_property_on_card_show(@project, SIZE, '0')
    assert_property_set_on_card_show(SIZE, '0')
  end

  def test_can_set_zero_as_numeric_value_for_numeric_property_on_card_edit
    setup_allow_any_number_property_definition('Iteration')
    sample_card = create_card!(:name => 'sample card')
    open_card_for_edit(@project, sample_card.number)

    add_new_value_to_property_on_card_edit(@project, 'Iteration', '0.00')
    save_card
    assert_property_set_on_card_show('Iteration', '0.00')
  end

  def test_import_from_excel_take_numeric_properties_as_managed_number_list_if_10_or_less_unique_numeric_values
    navigate_to_card_list_for(@project)
    header_row  = ['Number', 'Estimate']
    card_data_for_managed_number_list = [
      ['100', '1'], ['200', '2'], ['300', '3'], ['400', '4'], ['500', '5'], ['600', '6'], ['700', '7'], ['800', '8'], ['900', '9'], ['1000', '10'], ['1100', '7']
      ]
    preview(excel_copy_string(header_row, card_data_for_managed_number_list))
    assert_selected_property_column_in_import_preview('Estimate', CardImport::Mappings::NUMERIC_LIST_PROPERTY, "new #{CardImport::Mappings::NUMERIC_LIST_PROPERTY}")
    import_from_preview(:map => {'Estimate' => 'as new managed number list property'})

    navigate_to_property_management_page_for(@project)
    assert_property_present_on_property_management_page('Estimate')
    open_edit_enumeration_values_list_for(@project, 'Estimate')
    assert_enum_value_present_on_enum_management_page('1', '2', '3', '4', '5', '6', '7', '8', '9', '10')

    open_card(@project, 600)
    assert_properties_set_on_card_show('Estimate' => '6')
  end

  def test_excel_import_takes_column_as_any_number_for_more_than_10_unique_entries
    navigate_to_card_list_for(@project)
    header_row  = ['Number', 'Iteration']
    card_data_for_any_number =   [
      ['100', '1'], ['200', '2'], ['300', '3'], ['400', '4'], ['500', '5'], ['600', '6'], ['700', '7'], ['800', '8'], ['900', '9'], ['1000', '10'], ['1100', '11']
      ]
    preview(excel_copy_string(header_row, card_data_for_any_number))
    assert_selected_property_column_in_import_preview(header_row[1], CardImport::Mappings::ANY_NUMERIC_PROPERTY, "new #{CardImport::Mappings::ANY_NUMERIC_PROPERTY}")

    import_from_preview(:map => {'Iteration' => 'as new any number property'})
    assert_import_complete_with(:rows  => 11, :rows_created  => 11)
    open_card(@project, 100)
    assert_properties_set_on_card_show('Iteration' => '1')
    open_card(@project, 500)
    assert_properties_set_on_card_show('Iteration' => '5')
    open_card(@project, 1100)
    assert_properties_set_on_card_show('Iteration' => '11')
  end

  def test_exsisting_any_number_property_should_be_fetched_during_import_and_no_other_value_except_ignore_for_that_column
    setup_allow_any_number_property_definition('Iteration')
    navigate_to_card_list_for(@project)
    header_row  = ['number', 'Iteration']
    card_data = [['1', '3']]
    preview(excel_copy_string(header_row, card_data))

    assert_selected_property_column_in_import_preview(header_row[1], CardImport::Mappings::ANY_NUMERIC_PROPERTY)
    assert_value_ordered_in_selected_property_column_dropdown_in_import_preview('Iteration', ['(ignore)', 'as existing property'])
  end

  def test_exsisting_managed_number_property_should_be_fetched_during_import_and_no_other_value_except_ignore_for_that_column
    navigate_to_card_list_for(@project)
    header_row  = ['number', SIZE]
    card_data = [['1', '1']]
    preview(excel_copy_string(header_row, card_data))

    assert_selected_property_column_in_import_preview(SIZE, CardImport::Mappings::NUMERIC_LIST_PROPERTY)
    assert_value_ordered_in_selected_property_column_dropdown_in_import_preview(SIZE, ['(ignore)', 'as existing property'])
  end

  def test_should_throw_error_message_while_importing_invalid_numeric_value_on_existing_property_during_excel_import
    navigate_to_card_list_for(@project)
    header_row  = ['number', SIZE]
    card_data = [['1', '1'], ['2', 'xyy']]

    import(excel_copy_string(header_row, card_data))
    assert_error_message('Importing complete, 2 rows, 0 updated, 1 created, 1 error.')
    assert_error_message_without_html_content("Importing complete, 2 rows, 0 updated, 1 created, 1 error.
     Error detail:
     Row 2: size: xyy is an invalid numeric value")
  end

  def test_error_message_while_importing_invalid_numeric_value_on_new_any_number_property_during_excel_import
    navigate_to_card_list_for(@project)
    header_row = ['name', 'Iteration']
    card_data = [['card1', '3'], ['card2', 'xyz']]
    import(excel_copy_string(header_row, card_data), :map => {'Iteration' => 'as new any number property'})

    assert_error_message_without_html_content('Importing complete, 2 rows, 0 updated, 1 created, 1 error.
    Error detail:
    Row 2: Iteration: xyz is an invalid numeric value')
  end

  def test_error_message_while_importing_invalid_numeric_value_on_new_managed_number_property_during_excel_import
    navigate_to_card_list_for(@project)
    header_row = ['name', 'Estimate']
    card_data = [['card1', '3'], ['card2', 'xyz']]
    import(excel_copy_string(header_row, card_data), :map => {'Estimate' => 'as new managed number list property'})

    assert_error_message_without_html_content('Importing complete, 2 rows, 0 updated, 1 created, 1 error.
    Error detail:
    Row 2: Estimate: xyz is an invalid numeric value')
  end

  def test_average_query_for_numerics
    navigate_to_project_overview_page(@project)
    setup_card_type(@project, 'Story', :properties => [SIZE])
    create_card!(:name => 'story one', :card_type => 'Story', SIZE => '4')
    create_card!(:name => 'card one', SIZE => '16.01')
    create_card!(:name => 'card two', SIZE => '8.000')
    create_card!(:name => 'card three')

    edit_overview_page
    add_average_query_and_save_on(SIZE, "Type = Card", "#{SIZE} != NULL")
    assert_contents_on_page('12.01')
  end

  def test_value_query_for_numerics
    setup_card_type(@project, 'Story', :properties => [SIZE])
    create_card!(:name => 'story one', :card_type => 'Story', SIZE => '4')
    create_card!(:name => 'card one', SIZE => '16.01')
    create_card!(:name => 'card two', SIZE => '8.000')
    create_card!(:name => 'card three')

    navigate_to_project_overview_page(@project)
    edit_overview_page
    add_value_query_and_save_on("SUM(#{SIZE})", "Type=Card")
    assert_contents_on_page('24.01')
  end

  def test_table_query_for_numerics
    setup_card_type(@project, 'Story', :properties => [SIZE])
    create_card!(:name => 'story one', :card_type => 'Story', SIZE => '4')
    create_card!(:name => 'card one', SIZE => '16.01')
    create_card!(:name => 'card two', SIZE => '8.000')
    create_card!(:name => 'card three')

    navigate_to_project_overview_page(@project)
    edit_overview_page
    table = add_table_query_and_save_on(['Name', 'Number', SIZE], ["Type = Card", "#{SIZE} != NULL"])
    assert_table_row_data_for(table, :row_number => 1, :cell_values => ['card two', '3', '8.00'])
    assert_table_row_data_for(table, :row_number => 2, :cell_values => ['card one', '2', '16.01'])
  end

  # bug 2839
  def test_property_name_can_contain_operators_which_should_not_break_the_regular_property_funtionality
    property_name = "foo + 1"
    foo_prop = create_property_definition_for(@project, property_name, :type => 'any number')
    card = create_card!(:name => 'foo card')
    open_card(@project, card)
    add_new_value_to_property_on_card_show(@project, foo_prop.name, '834')
    assert_property_set_on_card_show(foo_prop.name, '834')
  end

  # bug 3539
  def test_managed_numeric_values_appear_in_smart_sorted_order_in_drop_downs
    points = setup_numeric_property_definition('points', [-1, 2, 20, 3])
    card = create_card!(:name => 'new card')
    open_card(@project, card)
    assert_values_ordered_in_card_show_property_drop_down(@project, points, [-1, 2, 3, 20])
  end

  #bug 2861, 2966
  def test_numeric_value_decimals_and_fraction_part_on_rows_in_table_on_wiki
    setup_managed_text_definition('Status', ['new', 'close', 'open'])
    create_card!(:name => 'one', SIZE => '16.01', 'Status' => 'new')
    create_card!(:name => 'two', SIZE => '16.00', 'Status' => 'open')
    create_card!(:name => 'three', SIZE => '8.000', 'Status' => 'closed')
    create_card!(:name => 'four', SIZE => '2', 'Status' => 'in progress')
    create_card!(:name => 'five', SIZE => '1.0', 'Status' => 'in progress')
    create_card!(:name => 'six', 'Status' => 'new')

    navigate_to_project_overview_page(@project)
    edit_overview_page
    table = add_pivot_table_query_and_save_for(SIZE, 'Status', :conditions => "Type = Card", :aggregation => "SUM(#{SIZE})", :empty_rows => 'false', :empty_columns => 'false', :totals => 'true')
    assert_table_column_headers_and_order(table, 'new', 'open', 'closed', 'in progress')
    assert_table_row_headers_and_order(table, '1', '2', '8.00', '16.00', '16.01', '(not set)', 'Totals')
    assert_table_row_data_for(table, :row_number => 7, :cell_values => ['16.01', '16', '8', '3'])
    assert_table_values(WikiPageId::TABLE_IDENTIFIER, 4, 1, '16')
    assert_table_values(WikiPageId::TABLE_IDENTIFIER, 5, 0, '16.01')
  end

  #bug 2861, 2966
  def test_numeric_value_decimals_and_fraction_part_on_columns_in_table_on_card
    setup_managed_text_definition('Status', ['new', 'close', 'open'])
    create_card!(:name => 'one', SIZE => '16.01', 'Status' => 'new')
    create_card!(:name => 'two', SIZE => '16.00', 'Status' => 'open')
    create_card!(:name => 'three', SIZE => '8.000', 'Status' => 'closed')
    create_card!(:name => 'four', SIZE => '2', 'Status' => 'in progress')
    create_card!(:name => 'five', SIZE => '1.0', 'Status' => 'in progress')
    create_card!(:name => 'six', 'Status' => 'new')

    open_card_for_edit(@project, 1)
    table = add_pivot_table_query_and_save_for('Status', SIZE, :conditions => "Type = CARD", :aggregation => "SUM(#{SIZE})", :empty_rows => 'false', :empty_columns => 'false', :totals => 'true')

    assert_table_column_headers_and_order(table, '1', '2', '8.00', '16.00', '16.01', '(not set)')
    assert_table_row_headers_and_order(table, 'new', 'open', 'closed', 'in progress', 'Totals')
    assert_table_values('card-description', 1, 4, '16.01')
    assert_table_values('card-description', 2, 3, '16')
    assert_table_row_data_for(table, :row_number => 5, :cell_values => ['1', '2', '8', '16', '16.01', '0'])
  end
end
