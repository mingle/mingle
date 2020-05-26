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

module ProjectVariableAcceptanceSupport

  STATUS = 'status'
  NEW = 'new'
  OPEN = 'open'
  USER_PROPERTY = 'owner'
  DATE_PROPERTY = 'closedOn'
  FREE_TEXT_PROPERTY = 'resolution'
  SIZE = 'Size'
  FORMULA_PROPERTY = 'size time two'
  BLANK = ''
  NOT_SET = '(not set)'
  CARD = 'Card'
  PROJECT_MEMBER_NAME_TRUNCATED = "member@ema..."

  def assert_cannot_set_value_for_property_to_plv_via_excel_import(options)
    plv_data_type = options[:plv_data_type]
    plv_name = options[:plv_name]
    value = options[:value]
    property = options[:property]
    error_message = options[:error_message]
    create_project_variable(@project, :name => plv_name, :data_type => plv_data_type, :value => value, :properties => property)
    navigate_to_card_list_for(@project)
    header_row = ['number', "#{property}"]
    imported_card_number = 15
    card_data = [[imported_card_number, plv_display_name(plv_name)]]
    import(excel_copy_string(header_row, card_data))
    @browser.assert_text_present("Importing complete, 0 rows, 0 updated, 0 created, 1 error.")
    @browser.assert_text_present(error_message)
    open_card(@project, imported_card_number)
    assert_error_message("Card 15 does not exist.")
  end

  def assert_plv_is_not_availble_as_property_value_on_card(options)
    project_variable_name = options[:plv_name]
    plv_data_type = options[:plv_data_type]
    plv_value = options[:plv_value]
    property = options[:property]
    create_project_variable(@project, :name => project_variable_name, :data_type => plv_data_type, :value => plv_value, :properties => [property])
    assert_notice_message("Project variable #{project_variable_name} was successfully created.")
    card = create_card!(:name => 'foo')
    open_card(@project, card.number)
    assert_value_not_present_for(property, plv_display_name(project_variable_name))
  end

  def assert_cannot_give_date_property_invalid_value_during_plv_create(invalid_value)
    project_variable_name = 'for date property'
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::DATE_DATA_TYPE, :value => invalid_value, :properties => [DATE_PROPERTY])
    assert_error_message("Value #{invalid_value} is an invalid date. Enter dates in dd mmm yyyy format or enter existing project variable which is available for this property.")
  end

  def assert_cannot_create_value_that_both_begins_and_ends_with_parens(property, data_type, invalid_value)
    open_project_variable_create_page_for(@project)
    create_project_variable(@project, :name => 'plv', :data_type => data_type, :value => invalid_value, :properties => [property])
    assert_error_message_without_html_content("Value cannot both start with '(' and end with ')'") if data_type.downcase == 'text'
    assert_error_message_without_html_content("Value must be numeric") if data_type.downcase == 'numeric'
  end

  def assert_cannot_give_numeric_property_non_numeric_value_during_plv_create(invalid_value)
    project_variable_name = 'for date property'
    create_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => invalid_value, :properties => [SIZE])
    assert_error_message_without_html_content("Value #{invalid_value} is an invalid numeric value")
  end

end
