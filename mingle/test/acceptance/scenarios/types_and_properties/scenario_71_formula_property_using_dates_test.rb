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

# Tags: scenario, properties, formula
class Scenario71FormulaPropertyUsingDatesTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  CREATION_SUCCESSFUL_MESSAGE = 'Property was successfully created.'
  UPDATE_SUCCESSFUL_MESSAGE = 'Property was successfully updated.'
  FORMULA = 'formula'
  STORY = 'Story'
  DEFECT = 'Defect'

  SIZE = 'Size12345'
  STATUS = 'status'
  NEW = 'new'
  OPEN = 'open'
  BLANK = ''
  NOT_SET = '(not set)'
  START_DATE = 'start date'
  END_DATE = 'end date'
  ACTUAL_EFFORT = 'Actual Effort'
  LOAD_FACTOR = 'load factor'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @admin = users(:admin)
    @project_admin = users(:proj_admin)
    @project_member = users(:project_member)
    @project = create_project(:prefix => 'scenario_71', :admins => [@project_admin], :users => [@admin, @project_member])
    setup_property_definitions(STATUS => [NEW, OPEN])
    setup_numeric_property_definition(SIZE, [2, 4])
    setup_date_property_definition(START_DATE)
    setup_date_property_definition(END_DATE)
    login_as_proj_admin_user
    @card = create_card!(:name => 'for testing')
  end

  def test_should_be_able_to_subtract_two_dates_and_result_in_numeric_value
    setup_formula_property_definition(ACTUAL_EFFORT, "'#{END_DATE}' - '#{START_DATE}'")
    open_card(@project, @card.number)
    add_new_value_to_property_on_card_show(@project, START_DATE, '5 Jan 2008')
    add_new_value_to_property_on_card_show(@project, END_DATE, '6 Jan 2008')
    @browser.run_once_history_generation
    open_card(@project, @card.number)

    assert_properties_set_on_card_show(ACTUAL_EFFORT => '1')
    assert_history_for(:card, @card.number).version(2).shows(:set_properties => {START_DATE => '05 Jan 2008'})
    assert_history_for(:card, @card.number).version(3).shows(:set_properties => {END_DATE => '06 Jan 2008', ACTUAL_EFFORT => '1'})
  end

  def test_today_should_not_be_supported_as_date_value_for_formulas
    invalid_formula_with_today = [["today + 2", 'today'], ["(today) + 2", 'today'], ["TODAY + 2", 'TODAY']]
    invalid_formula_with_today.each{|formula, invalid_property| input_invalid_formula_and_assert_error_message(@project, formula, "The formula is not well formed. No such property: #{invalid_property}. Help")}
    # checking existing property named 'today' is supported
    setup_date_property_definition('today')
    create_property_definition_for(@project, 'today_prop_2', :type => FORMULA, :formula => "today + 2")
    assert_property_present_on_property_management_page('today_prop_2')
  end

  def test_two_date_property_cannot_have_addition_operator
    invalid_formula = "'#{START_DATE}' + '#{END_DATE}'"
    input_invalid_formula_and_assert_error_message(@project, invalid_formula, "The expression #{invalid_formula} is invalid because a date ('#{START_DATE}') cannot be added to a date ('#{END_DATE}'). The supported operation is subtraction. Help")
  end

  def test_formula_date_with_numeric_value_addition_or_subtraction_should_yeald_date
    date_formulas = ["'#{START_DATE}' + 2", "'#{START_DATE}' - 2"]
    date_formulas.each {|formula| setup_formula_property_definition(formula.strip_all, formula)}
    open_card(@project, @card.number)
    add_new_value_to_property_on_card_show(@project, START_DATE, '6 Jan 2008')
    assert_properties_set_on_card_show(date_formulas[0].strip_all => '08 Jan 2008')
  end

  def test_error_messages_while_working_with_dates_in_formulae
    formula_with_text_property = ["'#{START_DATE}' - #{STATUS}", "'#{STATUS}' + '#{START_DATE}'"]
    formula_with_unsupported_operators = [["'#{START_DATE}' * 2", 'multiplied'], ["'#{START_DATE}' / 2", 'divided']]
    formula_with_operator_that_could_be_property_name = [["'#{START_DATE}' % 2", '%']]  # since % is a valid property name, the parser thinks it's an identifier
    formula_with_invalid_operators = [["'#{START_DATE}' & 2", '& 2'], ["'#{START_DATE}' = #{SIZE}", "= Size1234.."]]
    formula_with_text_property.each {|formula| input_invalid_formula_and_assert_error_message(@project, formula, "Property #{STATUS} is not numeric. Help")}
    formula_with_unsupported_operators.each {|formula, operator| input_invalid_formula_and_assert_error_message(@project, formula, "The expression #{formula} is invalid because a date ('#{START_DATE}') cannot be #{operator} by a number (2). The supported operations are addition, subtraction. Help")}
    formula_with_operator_that_could_be_property_name.each { |formula, invalid_operator| input_invalid_formula_and_assert_error_message(@project, formula, "The formula is not well formed. Unexpected characters encountered: \"#{invalid_operator}\" (IDENTIFIER). Help") }
    formula_with_invalid_operators.each {|formula, invalid_operator| input_invalid_formula_and_assert_error_message(@project, formula, "The formula is not well formed. Unexpected characters encountered: #{invalid_operator}. Help")}
  end

  # bug3055 and 3043
  def test_formula_proeprty_with_dates_can_be_ordered_ascending_or_descending
    formula_property = 'Tentative date'
    card = []
    date_formula = "'#{START_DATE}' + 2"
    setup_formula_property_definition(formula_property, date_formula)
    (1..5).each {|i| card[i] = create_card!(:name => "card #{i}", START_DATE => "#{i} Jan 2008")}
    navigate_to_card_list_for(@project, [START_DATE, formula_property])
    sort_by(formula_property)
    assert_ordered(card[1].html_id, card[2].html_id, card[3].html_id, card[4].html_id, card[5].html_id, @card.html_id)
    sort_by(formula_property)
    assert_ordered(@card.html_id, card[5].html_id, card[4].html_id, card[3].html_id, card[2].html_id, card[1].html_id)
  end

  def test_formula_using_date_should_be_ignored_while_excel_import
    end_date_opt = 'optimal End date'
    setup_formula_property_definition(end_date_opt, "'#{END_DATE}' + 2")
    navigate_to_card_list_for(@project)
    header_row = ['number', END_DATE, end_date_opt]
    end_date = '22/4/76'
    card_data = [[2, end_date, '27/4/76']]
    preview(excel_copy_string(header_row, card_data))
    assert_ignore_selected_for_property_column(end_date_opt)
    assert_ignore_only_available_mapping_for_property_column(end_date_opt)
    assert_text_present("Cannot set value for formula property: #{end_date_opt}")
    import_from_preview
    @browser.run_once_history_generation
    open_card(@project, 2)
    assert_property_set_on_card_show(END_DATE, '22 Apr 1976')
    assert_property_set_on_card_show(end_date_opt, '24 Apr 1976')
    assert_history_for(:card, 2).version(1).does_not_show(:set_properties => {end_date_opt => '27 Apr 1976'})
    assert_history_for(:card, 2).version(1).shows(:set_properties => {end_date_opt => '24 Apr 1976'})
  end

  def test_formula_can_contain_hidden_date_properties_as_operands
    hide_property(@project, START_DATE)
    transition_name = 'set hidden size'
    formula = "'#{START_DATE}' + 2"
    create_property_definition_for(@project, 'start_date_plus_2', :type => 'formula', :formula => formula)
    assert_notice_message(CREATION_SUCCESSFUL_MESSAGE)
    transition_setting_hidden = create_transition_for(@project, transition_name, :set_properties => {START_DATE => '(user input - required)'})
    card = create_card!(:name => 'card for testing')
    open_card(@project, card.number)
    click_transition_link_on_card_with_input_required(transition_setting_hidden)
    add_value_to_date_property_lightbox_editor_on_transition_complete(START_DATE => '22 Jan 2005')
    click_on_complete_transition
    @browser.run_once_history_generation
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {START_DATE => '22 Jan 2005'})
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {:'start_date_plus_2' => '24 Jan 2005'})
    assert_properties_set_on_card_show(:'start_date_plus_2' => '24 Jan 2005')
  end

  def test_nested_formulas_gives_valid_error_messages_and_suggestions
    nested_formula_missing_parenthisis = "('#{END_DATE}' - '#{START_DATE}')/3)('#{END_DATE}' - '#{START_DATE}')"
    nested_formula_date_add = "(('#{END_DATE}' - '#{START_DATE}')/3) - '#{END_DATE}' - '#{START_DATE}'"
    nested_formula_date_multiply = "(('#{END_DATE}' - '#{START_DATE}')/3) + '#{END_DATE}' - '#{START_DATE}' * 100"
    create_property_definition_for(@project, 'formulae', :type => FORMULA, :formula => nested_formula_missing_parenthisis)
    if using_ie?
      assert_error_message_without_html_content("The formula is not well formed. Unexpected characters encountered: \")\" (R_PAREN). Help")
    else
      assert_error_message_without_html_content("The formula is not well formed. \nUnexpected characters encountered: \")\" (R_PAREN). Help")
    end
    create_property_definition_for(@project, 'formulae', :type => FORMULA, :formula => nested_formula_date_add)
    assert_error_message_without_html_content("The expression (('end date' - 'start date') / 3) - 'end date' is invalid because a date ('end date') cannot be subtracted from a number ((('end date' - 'start date') / 3)). The supported operation is addition. Help")

    create_property_definition_for(@project, 'formulae', :type => FORMULA, :formula => nested_formula_date_multiply)
    assert_error_message_without_html_content("The expression 'start date' * 100 is invalid because a date ('start date') cannot be multiplied by a number (100). The supported operations are addition, subtraction. Help")
  end

  # bug test 3057 and 3058
  def test_history_generation_with_formula_using_dates_while_changing_output_type_of_formula
    end_date_opt = 'optimal End date'
    formula = "'#{END_DATE}' + 2"
    new_formula = "'#{SIZE}' + 2"
    create_property_definition_for(@project, end_date_opt, :type => FORMULA, :formula => formula)
    open_card(@project, @card)
    assert_history_for(:card, @card.number).version(2).not_present
    card2 = create_card!(:name => 'new card', SIZE => '2', END_DATE => '22 Jan 05')
    edit_property_definition_for(@project, end_date_opt, :new_formula => new_formula)
    @browser.run_once_history_generation
    open_card(@project, card2)
    assert_history_for(:card, card2.number).version(2).shows(:changed => end_date_opt, :from => '24 Jan 2005', :to => '4')
  end

  # bug 3058. ( secnario mentioned on story 2590)
  def test_scenario_on_change_of_formula_with_resulting_in_date_and_change_in_numeric_value_updates_cards_and_history
    setup_numeric_property_definition(LOAD_FACTOR, [0.5, 1])
    effective_working_days = "'#{END_DATE}'-'#{START_DATE}'"
    effort =  "('#{END_DATE}'-'#{START_DATE}') + '#{LOAD_FACTOR}'"
    new_effort = "'#{START_DATE}' + ('#{END_DATE}'-'#{START_DATE}')"
    setup_formula_property_definition("effective working days", effective_working_days)
    setup_formula_property_definition(ACTUAL_EFFORT, effort)
    card1 = create_card!(:name => 'card1', START_DATE => '29 Dec 2007', END_DATE => '30 Dec 2007', LOAD_FACTOR => '0.5')
    card2 = create_card!(:name => 'card2', START_DATE => '29 Dec 2007', END_DATE => '30 Dec 2007')
    @browser.run_once_history_generation
    open_card(@project, card1.number)
    assert_history_for(:card, card1.number).version(1).shows(:set_properties => {'effective working days' => '1', ACTUAL_EFFORT => '1.5'})
    open_card(@project, card2.number)
    assert_history_for(:card, card2.number).version(1).shows(:set_properties => {'effective working days' => '1'})
    assert_property_not_set_on_card_show(ACTUAL_EFFORT)
    edit_property_definition_for(@project, ACTUAL_EFFORT, :new_formula => new_effort)
    @browser.run_once_history_generation
    open_card(@project, card2.number)
    assert_history_for(:card, card2.number).version(1).shows(:set_properties => {'effective working days' => '1'})
    set_properties_on_card_show(LOAD_FACTOR => '0.5')
    @browser.run_once_history_generation
    open_card(@project, card2)
    assert_property_set_on_card_show(ACTUAL_EFFORT, '30 Dec 2007')
    assert_history_for(:card, card2.number).version(2).shows(:set_properties => {ACTUAL_EFFORT => '30 Dec 2007'})
    assert_history_for(:card, card2.number).version(3).shows(:set_properties => {LOAD_FACTOR => '0.5'})
  end

  # bug 3031
  def test_formula_property_cannot_contain_another_formula_property
    setup_formula_property_definition(ACTUAL_EFFORT, "'#{END_DATE}' - '#{START_DATE}'")
    formula_with_a_formula = "'#{END_DATE}' - '#{ACTUAL_EFFORT}'"
    input_invalid_formula_and_assert_error_message(@project, formula_with_a_formula, "Property #{ACTUAL_EFFORT} is a formula property and cannot be used within another formula. Help")
  end

  # bug 3427
  def test_should_be_able_to_update_formula_property_type_association_and_formula_in_single_edit
    fixed_on = 'fixed on'
    logged_on = 'logged on'
    new_formula_for_type_defect = "'#{fixed_on}' - '#{logged_on}'"
    defect = 'Defect'
    setup_date_property_definition(fixed_on)
    setup_date_property_definition(logged_on)
    type_story = setup_card_type(@project, STORY, :properties => [START_DATE, END_DATE])
    type_defect = setup_card_type(@project, defect, :properties => [fixed_on, logged_on])
    story_card = create_card!(:name => 'story card', :card_type => STORY)
    defect_card = create_card!(:name => 'defect card', :card_type => defect)
    create_property_definition_for(@project, ACTUAL_EFFORT, :type => 'formula', :formula => "'#{END_DATE}' - '#{START_DATE}'", :types => [STORY])
    open_property_for_edit(@project, ACTUAL_EFFORT)
    uncheck_card_types_required_for_a_property(@project, :card_types => [STORY])
    check_the_card_types_required_for_a_property(@project, :card_types => [defect])
    type_formula(new_formula_for_type_defect)
    click_save_property
    @browser.assert_text_present("This update will remove card type #{STORY} from property #{ACTUAL_EFFORT}.")
    @browser.assert_text_present("Any cards that are currently of type #{STORY} will no longer have values for #{ACTUAL_EFFORT} after this update. These changes will be reflected in each card's history.")
    click_continue_update
    assert_notice_message("Property was successfully updated.")
    open_card(@project, story_card)
    assert_property_not_present_on_card_show(ACTUAL_EFFORT)
    open_card(@project, defect_card)
    assert_property_present_on_card_show(ACTUAL_EFFORT)
  end

  # bug 3372
  def test_bulk_editing_date_properties_that_are_components_of_date_formula_updates_the_value_of_formula_property_in_bulk_edit_panel
    setup_formula_property_definition(ACTUAL_EFFORT, "'#{END_DATE}' - '#{START_DATE}'")
    april_12 = '12 Apr 2008'
    april_10 = '10 Apr 2008'
    navigate_to_card_list_for(@project)
    select_all
    click_edit_properties_button
    add_new_value_to_property_on_bulk_edit(@project, END_DATE, april_12)
    add_new_value_to_property_on_bulk_edit(@project, START_DATE, april_10)
    assert_property_set_in_bulk_edit_panel(@project, ACTUAL_EFFORT, '2')
    open_card(@project, @card)
    assert_history_for(:card, @card.number).version(2).shows(:set_properties => {END_DATE => april_12})
    assert_history_for(:card, @card.number).version(3).shows(:set_properties => {START_DATE => april_10, ACTUAL_EFFORT => '2'})
  end

  # bug 3034
  def test_formula_can_contain_plus_and_minus_operators
    april_12 = '12 Apr 2008'
    april_10 = '10 Apr 2008'
    setup_formula_property_definition(ACTUAL_EFFORT, "'#{START_DATE}' + (-2)")
    start_date_in_single_quotes = "'#{START_DATE}'"
    card = create_card!(:name => 'testing formula property update')
    open_card(@project, card)
    add_new_value_to_property_on_card_show(@project, START_DATE, april_12)
    @browser.run_once_history_generation
    open_card(@project, card)
    assert_property_set_on_card_show(ACTUAL_EFFORT, april_10)
    assert_property_set_on_card_show(START_DATE, april_12)
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {START_DATE => april_12, ACTUAL_EFFORT => april_10})
  end

  # bug 3039
  def test_renaming_component_property_by_giving_it_quotes_correctly_updates_formula_property
    april_12 = '12 Apr 2008'
    april_10 = '10 Apr 2008'
    setup_formula_property_definition(ACTUAL_EFFORT, "'#{END_DATE}' - '#{START_DATE}'")
    start_date_in_single_quotes = "'#{START_DATE}'"
    card = create_card!(:name => 'testing formula property update', START_DATE => april_12, END_DATE => april_10)
    edit_property_definition_for(@project, START_DATE, :new_property_name => start_date_in_single_quotes)
    assert_notice_message(UPDATE_SUCCESSFUL_MESSAGE)
    open_property_for_edit(@project, ACTUAL_EFFORT)
    assert_formula_for_formula_property("'#{END_DATE}' - \"#{start_date_in_single_quotes}\"")
  end

  # bug 3039
  def test_renaming_component_property_by_giving_it_parens_correctly_updates_formula_property
    april_12 = '12 Apr 2008'
    april_10 = '10 Apr 2008'
    size2 = "#{SIZE}2"
    setup_numeric_property_definition(size2, [2, 4])
    setup_formula_property_definition(ACTUAL_EFFORT, "'#{START_DATE}' - (#{SIZE} - #{size2})")
    size2_in_parens = "(#{size2})"
    card = create_card!(:name => 'testing formula property update', START_DATE => april_12, END_DATE => april_10)
    edit_property_definition_for(@project, size2, :new_property_name => size2_in_parens)
    assert_notice_message(UPDATE_SUCCESSFUL_MESSAGE)
    open_property_for_edit(@project, ACTUAL_EFFORT)
    assert_formula_for_formula_property("'#{START_DATE}' - (#{SIZE} - '#{size2_in_parens}')")
  end

  # bug 3191
  def test_formula_property_is_immediately_updated_when_adding_association_to_card_type_and_component_properties_are_already_set_on_card
    april_12 = '12 Apr 2008'
    april_10 = '10 Apr 2008'
    type_story = setup_card_type(@project, STORY, :properties => [START_DATE, END_DATE])
    type_defect = setup_card_type(@project, DEFECT, :properties => [START_DATE, END_DATE])
    create_property_definition_for(@project, ACTUAL_EFFORT, :type => 'formula', :formula => "'#{START_DATE}' - '#{END_DATE}'", :types => [STORY])
    story_card = create_card!(:name => 'story a', :card_type => STORY, START_DATE => april_12, END_DATE => april_10)
    defect_card = create_card!(:name => 'bug b', :card_type => DEFECT, START_DATE => april_12, END_DATE => april_10)
    @browser.run_once_history_generation
    open_card(@project, story_card)
    assert_property_set_on_card_show(ACTUAL_EFFORT, '2')
    assert_history_for(:card, story_card.number).version(1).shows(:set_properties => {START_DATE => april_12, END_DATE => april_10, ACTUAL_EFFORT => '2'})
    open_card(@project, defect_card)
    assert_property_not_present_on_card(@project, defect_card, ACTUAL_EFFORT)
    assert_history_for(:card, defect_card.number).version(1).shows(:set_properties => {START_DATE => april_12, END_DATE => april_10})
    assert_history_for(:card, defect_card.number).version(1).does_not_show(:set_properties => {ACTUAL_EFFORT => '2'})
    open_property_for_edit(@project, ACTUAL_EFFORT)
    check_the_card_types_required_for_a_property(@project, :card_types => [DEFECT])
    click_save_property
    @browser.run_once_history_generation
    open_card(@project, defect_card)
    assert_property_set_on_card_show(ACTUAL_EFFORT, '2')
    assert_history_for(:card, defect_card.number).version(1).shows(:set_properties => {START_DATE => april_12, END_DATE => april_10})
    assert_history_for(:card, defect_card.number).version(2).shows(:set_properties => {ACTUAL_EFFORT => '2'})
    assert_history_for(:card, defect_card.number).version(3).not_present
    navigate_to_card_list_for(@project)
    add_column_for(@project, [ACTUAL_EFFORT])
    cards = HtmlTable.new(@browser, 'cards', ['number', 'name', ACTUAL_EFFORT], 1, 1)
    cards.assert_row_values(1, [defect_card.number, defect_card.name, '2'])
  end

  # bug 3709
  def test_value_for_formula_property_does_not_appear_in_card_list_when_card_type_is_not_assoicated_to_formula_properties_but_component_properties_are_already_set_on_card
    april_12 = '12 Apr 2008'
    april_10 = '10 Apr 2008'
    type_story = setup_card_type(@project, STORY, :properties => [START_DATE, END_DATE])
    type_defect = setup_card_type(@project, DEFECT, :properties => [START_DATE, END_DATE])
    create_property_definition_for(@project, ACTUAL_EFFORT, :type => 'formula', :formula => "'#{START_DATE}' - '#{END_DATE}'", :types => [STORY])
    story_card = create_card!(:name => 'story a', :card_type => STORY, START_DATE => april_12, END_DATE => april_10)
    defect_card = create_card!(:name => 'bug b', :card_type => DEFECT, START_DATE => april_12, END_DATE => april_10)
    navigate_to_card_list_for(@project)
    add_column_for(@project, [ACTUAL_EFFORT])
    cards = HtmlTable.new(@browser, 'cards', ['number', 'name', ACTUAL_EFFORT], 1, 1)
    cards.assert_row_values_for_card(1, defect_card)
  end

  # bug 3725
  def test_invalid_nested_formula_should_not_give_unnecessarily_technical_error_message
    invalid_nested_date_formula = "(('#{START_DATE}' - '#{START_DATE}') + (365)) + '#{START_DATE}' + ('#{START_DATE}') / ('#{START_DATE}')"
    friendly_error_message = "The expression ('#{START_DATE}') / ('#{START_DATE}') is invalid because a date (('#{START_DATE}')) cannot be divided by a date (('#{START_DATE}')). The supported operation is subtraction. Help"
    unfriendly_error_message = "The formula is not well formed. Cannot evaluate a CardPropertyValue formula without binding it to a card first."
    type_story = setup_card_type(@project, STORY, :properties => [START_DATE, END_DATE])
    create_property_definition_for(@project, ACTUAL_EFFORT, :type => 'formula', :formula => invalid_nested_date_formula, :types => [STORY])
    assert_error_message_without_html_content(friendly_error_message)
    assert_error_message_does_not_contain(unfriendly_error_message)
    assert_error_message_does_not_contain('binding')
  end

  private
  def input_invalid_formula_and_assert_error_message(project, formula, error)
    create_property_definition_for(project, "invalid formula", :type => FORMULA, :formula  => formula)
    assert_error_message_without_html_content(error)
  end
end
