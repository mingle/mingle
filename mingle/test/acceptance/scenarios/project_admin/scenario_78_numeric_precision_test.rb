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

#Tags: numeric, property, project

class Scenario78NumericPrecisionTest < ActiveSupport::TestCase
  
  fixtures :users, :login_access

  PRIORITY = 'priority'
  STATUS = 'status'
  SIZE = 'size'
  ITERATION = 'iteration'
  OWNER = 'Zowner'

  STORY = 'Story'
  DEFECT = 'Defect'
  TASK = 'Task'
  CARD = 'Card'

  NOTSET = '(not set)'
  ANY = '(any)'
  TYPE = 'Type'

  MANAGED_TEXT_PROPERTY = 'managed_text_list'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_admin_user = users(:longbob)
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_78', :users => [@non_admin_user], :admins => [@project_admin_user, users(:admin)])
    setup_property_definitions(PRIORITY => ['high', 'low'], STATUS => ['new',  'close', 'open'])
    @size_property = setup_numeric_property_definition(SIZE, [0.99, 1, 2, 3.0])
    @size_times_2 = setup_formula_property_definition("size * 2", "#{SIZE} * 2.000")
    setup_card_type(@project, STORY, :properties => [PRIORITY, SIZE])
    setup_card_type(@project, DEFECT, :properties => [PRIORITY, STATUS, SIZE])
    login_as_admin_user
    @size2 = create_property_definition_for(@project, ITERATION, :type => 'any number')
    @card_1 = create_card!(:number => 88, :name => 'sample card_1', :card_type => STORY, PRIORITY => 'high', SIZE => '2')
    @card_2 = create_card!(:number => 89, :name => 'sample card_2', :card_type => STORY, PRIORITY => 'high', SIZE => '1')
  end
  
  def test_project_level_numeric_precision_can_be_set_by_admin_user
    set_numeric_precision_to(@project, 5)
    assert_notice_message('Project was successfully updated.')
    navigate_to_project_admin_for(@project)
    assert_precision_set_to(5)
    create_enumeration_value_for(@project, @size_property, '7.55555')
    assert_enum_value_present_on_enum_management_page('7.55555')
  end
  
  def test_project_member_cannot_edit_numeric_precision_value
    login_as(@non_admin_user.login, 'longtest')
    open_admin_edit_page_for(@project)
    assert_cannot_access_resource_error_message_present
  end
  
  #also for bug #6166
  def test_changing_to_lower_or_higher_precision_rounds_the_numeric_value_and_no_longer_remembers_the_earlier_precision
    managed_text_property = create_managed_text_list_property(MANAGED_TEXT_PROPERTY, ['7.55555', '7.56'])
    set_numeric_precision_to(@project, 5)
    create_enumeration_value_for(@project, @size_property, '7.55555')
    create_enumeration_value_for(@project, @size_property, '7.56')
    assert_enum_value_present_on_enum_management_page('7.55555', '7.56')
    set_numeric_precision_to(@project, 2)
    open_edit_enumeration_values_list_for(@project, @size_property)
    assert_enum_value_present_on_enum_management_page('7.56')
    assert_enum_value_not_present_on_enum_management_page('7.55', '7.55555')

    navigate_to_property_management_page_for(@project)
    mananged_text_property_definition = Project.find_by_identifier(@project.identifier).find_property_definition_or_nil(MANAGED_TEXT_PROPERTY)

    assert_property_does_have_value(mananged_text_property_definition, '7.55555')
    assert_property_does_have_value(mananged_text_property_definition, '7.56')
    
    set_numeric_precision_to(@project, 5)
    open_edit_enumeration_values_list_for(@project, @size_property)
    assert_enum_value_present_on_enum_management_page('7.56')
    assert_enum_value_not_present_on_enum_management_page('7.55', '7.55555')
  end
  
  def test_precisions_maintained_on_card_show_and_does_not_duplicate_enum_values_for_managed_numeric_list
    create_enumeration_value_for(@project, @size_property, '4.00')
    open_card(@project, @card_1)
    add_new_value_to_property_on_card_show(@project, SIZE, '4')
    assert_properties_set_on_card_show(SIZE => '4.00')

    add_new_value_to_property_on_card_show(@project, SIZE, '3.00')
    assert_properties_set_on_card_show(SIZE => '3.0')

    add_new_value_to_property_on_card_show(@project, SIZE, '1.00')
    assert_properties_set_on_card_show(SIZE => '1')
  end
  
  def test_precisions_maintained_on_card_edit_and_does_not_duplicate_enum_values_for_managed_numeric_list
    create_enumeration_value_for(@project, @size_property, '4.00')
    open_card_for_edit(@project, @card_1)
    add_new_value_to_property_on_card_edit(@project, SIZE, '4')
    assert_properties_set_on_card_edit(SIZE => '4.00')
    open_card_for_edit(@project, @card_1)
    add_new_value_to_property_on_card_edit(@project, SIZE, '3.00')
    assert_properties_set_on_card_edit(SIZE => '3.0')
    open_card_for_edit(@project, @card_1)
    add_new_value_to_property_on_card_edit(@project, SIZE, '1.00')
    assert_properties_set_on_card_edit(SIZE => '1')
  end
  
  def test_precisions_maintained_on_bulk_edit_and_does_not_duplicate_enum_values_for_managed_numeric_list
    create_enumeration_value_for(@project, @size_property, '4.00')
    set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]")
    select_all
    click_edit_properties_button
    add_new_value_to_property_on_bulk_edit(@project, SIZE, '4')
    assert_properties_set_in_bulk_edit_panel(@project, SIZE => '4.00')

    add_new_value_to_property_on_bulk_edit(@project, SIZE, '3.00')
    assert_properties_set_in_bulk_edit_panel(@project, SIZE => '3.0')

    add_new_value_to_property_on_bulk_edit(@project, SIZE, '1.00')
    assert_properties_set_in_bulk_edit_panel(@project, SIZE => '1')
  end
  
  def test_precisions_maintained_on_card_defaults_and_does_not_duplicate_enum_values_for_managed_numeric_list
    create_enumeration_value_for(@project, @size_property, '4.00')
    open_edit_defaults_page_for(@project, STORY)
    set_property_defaults_via_inline_value_add(@project, SIZE, '4')
    assert_properties_set_on_card_defaults(@project, SIZE => '4.00')
    
    open_edit_defaults_page_for(@project, STORY)
    
    set_property_defaults_via_inline_value_add(@project, SIZE, '3.00')
    assert_properties_set_on_card_defaults(@project, SIZE => '3.0')

    open_edit_defaults_page_for(@project, STORY)
    
    set_property_defaults_via_inline_value_add(@project, SIZE, '1.00')
    assert_properties_set_on_card_defaults(@project, SIZE => '1')
  end
  
  def test_invalid_integer_or_above_limit_entry_of_precision_throw_error
    set_numeric_precision_to(@project, '11')
    assert_error_message('Precision must be an integer between 0 and 10')
    set_numeric_precision_to(@project, 'abc')
    assert_error_message('Precision must be an integer between 0 and 10')
  end
  
  def test_formula_properties_chop_off_leading_zeros_in_precision
    story1 = create_card!(:name => "story1", @size_property => '2')
    open_card(@project, story1)
    assert_properties_set_on_card_show(@size_times_2 => '4')
    add_new_value_to_property_on_card_show(@project, SIZE, '7.00')
    assert_properties_set_on_card_show(@size_times_2 => '14')
    add_new_value_to_property_on_card_show(@project, SIZE, '5.0')
    assert_properties_set_on_card_show(@size_times_2 => '10')
  end
  
  def test_any_number_variations_in_zero_precisions_in_property_equated_to_one_entity_for_charts
    generate_sample_cards
    open_overview_page_for_edit @project
    pivot_table_one = add_pivot_table_query_and_save_for(ITERATION, SIZE, :conditions => "Type = CARD", :empty_rows => 'false', :empty_columns => 'false', :totals => 'true')
    
    assert_table_column_headers_and_order(pivot_table_one, '1', '2', '8.00', '16', '(not set)')
    assert_table_row_headers_and_order(pivot_table_one, '1.00', '2.00', 'Totals')
    assert_table_row_data_for(pivot_table_one, :row_number => 1, :cell_values => ['','','1', '1', '1'])
    assert_table_row_data_for(pivot_table_one, :row_number => 3, :cell_values => ['1','1','1', '2', '1'])
  end
  
  def test_any_number_variations_in_zero_precisions_in_property_equated_to_one_entity_for_charts_at_rows
    generate_sample_cards
    open_overview_page_for_edit @project
    pivot_table_one = add_pivot_table_query_and_save_for(SIZE, ITERATION, :conditions => "Type = CARD", :empty_rows => 'false', :empty_columns => 'false', :totals => 'true')
    assert_table_column_headers_and_order(pivot_table_one, '1.00', '2.00')
    assert_table_row_headers_and_order(pivot_table_one, '1', '2', '8.00', '16', '(not set)', 'Totals')
    assert_table_row_data_for(pivot_table_one, :row_number => 1, :cell_values => ['', '1'])
    assert_table_row_data_for(pivot_table_one, :row_number => 4, :cell_values => ['1', '1'])
    assert_table_row_data_for(pivot_table_one, :row_number => 6, :cell_values => ['3', '3']) # Bug 3357 uncomment after fix.
  end
  #bug 3346
  def test_adding_precision_values_to_numeric_list_should_maintain_proper_order
    value1 = create_enumeration_value_for(@project, @size_property, '5.54')
    value2 = create_enumeration_value_for(@project, @size_property, '5.6')
    assert_enum_values_in_order(value1, value2)
  end
  
  # bug 3359
  def test_table_query_shows_individual_any_numeric_values_as_keyed_in
    header_row = ['name', 'Type', ITERATION]
    card_data = [
      ['card1', 'Card', '5.5555'],
      ['card2', 'Card', '5.00000'],
      ['card3', 'card', '5.55']
      ]
    click_all_tab
    import(excel_copy_string(header_row, card_data))
    assert_import_complete_with(:rows => 3,:rows_created => 3) 
    edit_overview_page
    table_query = add_table_query_and_save_on(['Name', ITERATION], ["Type=Card"] )
    assert_table_column_headers_and_order(table_query, 'Name', ITERATION)
    assert_table_row_data_for(table_query, :row_number => 1, :cell_values => ['card3', '5.55'])
    assert_table_row_data_for(table_query, :row_number => 2, :cell_values => ['card2', '5.00'])
    assert_table_row_data_for(table_query, :row_number => 3, :cell_values => ['card1', '5.56'])
  end
  
  # Bug 3357
  def test_pivote_table_calculate_totals_correctly_for_any_number_properties_on_columns
    generate_sample_cards
    open_overview_page_for_edit @project
    pivot_table_one = add_pivot_table_query_and_save_for(SIZE, ITERATION, :conditions => "Type = CARD", :aggregation => "SUM(size)", :empty_rows => 'false', :empty_columns => 'false', :totals => 'true')
    assert_table_column_headers_and_order(pivot_table_one, '1.00', '2.00')
    assert_table_row_headers_and_order(pivot_table_one, '1', '2', '8.00', '16', '(not set)', 'Totals')
    assert_table_row_data_for(pivot_table_one, :row_number => 3, :cell_values => ['8', ''])
    assert_table_row_data_for(pivot_table_one, :row_number => 4, :cell_values => ['16', '16'])
    assert_table_row_data_for(pivot_table_one, :row_number => 6, :cell_values => ['24', '19'])
  end
  
  def generate_sample_cards
    click_all_tab
    header_row = ['Number', 'Name', 'Type', ITERATION,  SIZE, STATUS]
    card_data = [
      ['6', 'six', 'Card',  '1', '', 'new'],
      ['5', 'five', 'Card', '1.0', '16.00', 'open'],
      ['4', 'four', 'Card', '1.00', '8.000', 'closed'],
      ['3', 'three', 'Card',  '2', '1.0', 'in progress'],
      ['2', 'two', 'Card',  '2.0', '2', 'in progress'],
      ['1', 'one', 'Card',  '2.00', '16', 'new']
    ]  
    import(excel_copy_string(header_row, card_data))
    assert_import_complete_with(:rows  => 6, :rows_created  => 6)
  end
  
  
  # def set_numeric_precision_to(project, precision)
  #     location = @browser.get_location
  #     navigate_to_project_admin_for(project) unless location =~ /#{project.identifier}\/admin\/edit/
  #     click_show_advanced_options_link
  #     @browser.type('project_precision', precision.to_s)
  #     click_save_link
  #   end
    
  # def assert_precision_set_to(precision)
  #    @browser.assert_value('project_precision', precision.to_s)
  #  end

end
