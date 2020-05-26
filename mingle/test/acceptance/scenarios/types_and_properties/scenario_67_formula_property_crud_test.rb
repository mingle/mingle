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
class Scenario67FormulaPropertyCrudTest < ActiveSupport::TestCase
  
  fixtures :users, :login_access
  
   CREATION_SUCCESSFUL_MESSAGE = 'Property was successfully created.'
  DEFECT = 'defect'
  
  SIZE = 'Size'
  STATUS = 'status'
  NEW = 'new'
  OPEN = 'open'
  PRIORITY = 'priority'
  HIGH = 'high'
  LOW = 'low'
  USER_PROPERTY = 'owner'
  DATE_PROPERTY = 'closedOn'
  FREE_TEXT_PROPERTY = 'resolution'
  VALID_DATE_VALUE = '(today)'
  BLANK = '   '
  NOT_SET = '(not set)'
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @admin = users(:admin)
    @project_admin = users(:proj_admin)
    @project_member = users(:project_member)
    @project = create_project(:prefix => 'scenario_67', :admins => [@project_admin], :users => [@admin, @project_member])
    setup_property_definitions(STATUS => [NEW, OPEN], PRIORITY => [HIGH, LOW])
    setup_user_definition(USER_PROPERTY)
    setup_text_property_definition(FREE_TEXT_PROPERTY)
    setup_date_property_definition(DATE_PROPERTY)
    login_as_proj_admin_user
  end
  
  #bug 10348
  def test_should_be_able_to_rename_property_used_in_formula
    setup_numeric_property_definition(SIZE, [2, 4])
    size_plus_two = 'size plus two'
    setup_formula_property_definition(size_plus_two, '"   size " + 2')    
    edit_property_definition_for(@project, SIZE, :new_property_name => "pre estimate")
    assert_notice_message("Property was successfully updated.")
    
    open_property_for_edit(@project, size_plus_two)
    # the doulbe quotas are changed to single quotas, this is not ideal but already been like this for long time. decide to accept for now.
    assert_formula_for_formula_property("'pre estimate' + 2")
    
    create_card!(:name => "sample card")
    navigate_to_card_list_for(@project)    
    add_column_for(@project, [size_plus_two])
    assert_column_present_for(size_plus_two)
  end
  
  def test_cannot_create_formula_property_that_uses_another_formula_property_as_operand
    setup_numeric_property_definition(SIZE, [2, 4])
    size_times_two = 'size times two'
    setup_formula_property_definition(size_times_two, "#{SIZE} * 2")
    create_property_definition_for(@project, 'formula plus two', :type => 'formula', :formula => "'#{size_times_two}' + 2")
    assert_error_message("Property #{size_times_two} is a formula property and cannot be used within another formula.")
  end
  
  def test_cannot_delete_property_that_is_currently_an_operand_in_existing_formula_property
    size_times_two = 'size time two'
    setup_numeric_property_definition(SIZE, [2, 4])
    setup_formula_property_definition(size_times_two, "#{SIZE} * 2")
    navigate_to_property_management_page_for(@project)
    delete_property_for(@project, SIZE, :stop_at_confirmation => true)
    @browser.assert_text_present("used as a component property of #{size_times_two}")
  end

  def test_can_delete_operand_property_after_its_removed_as_formula_operand
    real_effort_formula_property = 'real effort'
    load_factor = 'load factor'
    formula_using_size = "(#{SIZE} + 2) * '#{load_factor}'"
    formula_not_using_size = "2 * '#{load_factor}'"
    setup_numeric_property_definition(SIZE, [2, 4])
    setup_numeric_property_definition(load_factor, [1, 2, 3])
    setup_formula_property_definition(real_effort_formula_property, formula_using_size)
    
    open_property_for_edit(@project, real_effort_formula_property)
    type_formula(formula_not_using_size)
    click_save_property
    navigate_to_property_management_page_for(@project)
    delete_property_for(@project, SIZE)
    assert_notice_message("Property #{SIZE} has been deleted.")
    assert_property_not_present_on_property_management_page(SIZE)
  end

  def test_renaming_property_that_is_formula_property_operand_also_updates_formula
    times_two_formula_property = 'times two'
    new_name_for_size_property = 'POINTS'
    original_formaula = "#{SIZE} * 2"
    expected_formula_after_operand_property_rename = "#{new_name_for_size_property} * 2"
    setup_numeric_property_definition(SIZE, [2, 4])
    setup_formula_property_definition(times_two_formula_property, original_formaula)
    navigate_to_property_management_page_for(@project)
    edit_property_definition_for(@project, SIZE, :new_property_name => new_name_for_size_property)
    open_property_for_edit(@project, times_two_formula_property)
    assert_formula_for_formula_property(expected_formula_after_operand_property_rename)
    card = create_card!(:name => 'for testing')
    open_card(@project, card.number)
    set_properties_on_card_show(new_name_for_size_property => 2)
    assert_properties_set_on_card_show(times_two_formula_property => '4')
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {new_name_for_size_property => '2'})
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {times_two_formula_property => '4'})
  end
  
  def test_cannot_create_multiple_formula_properties_with_the_same_name
    formula_property_name = 'times two'
    same_name_with_extra_spaces = 'times    two'
    formula = '3 * 2'
    create_property_definition_for(@project, formula_property_name, :type => 'formula', :formula => formula)
    create_property_definition_for(@project, formula_property_name.upcase, :type => 'formula', :formula => formula)
    assert_error_message('Name has already been taken')
    assert_error_message_does_not_contain('Column name has already been taken')
    @browser.assert_checked('definition_type_formula')
    create_property_definition_for(@project, same_name_with_extra_spaces, :type => 'formula', :formula => formula)
    assert_error_message('Name has already been taken')
    assert_error_message_does_not_contain('Column name has already been taken')
  end
  
  def test_can_create_multiple_formula_properties_with_the_same_formula
    formula_one_name = 'formula one'
    formula_two_name = 'formula two'
    formula = '4/5'
    create_property_definition_for(@project, formula_one_name, :type => 'formula', :formula => formula)
    assert_notice_message(CREATION_SUCCESSFUL_MESSAGE)
    create_property_definition_for(@project, formula_two_name, :type => 'formula', :formula => formula)
    assert_notice_message(CREATION_SUCCESSFUL_MESSAGE)
    assert_property_present_on_property_management_page(formula_one_name)
    assert_property_present_on_property_management_page(formula_two_name)
  end
  
  def test_cannot_make_formula_properties_transition_only
    formula_property = 'size time two'
    setup_numeric_property_definition(SIZE, [2, 4])
    setup_formula_property_definition(formula_property, "#{SIZE} * 2")
    navigate_to_property_management_page_for(@project)
    assert_transition_only_check_box_not_present_for(@project, formula_property)
  end

  def test_cannot_lock_formula_properties
    formula_property = 'size time two'
    setup_numeric_property_definition(SIZE, [2, 4])
    setup_formula_property_definition(formula_property, "#{SIZE} * 2")
    navigate_to_property_management_page_for(@project)
    assert_lock_check_box_not_present_for(@project, formula_property)
  end
  
  def test_formula_property_cannot_be_created_with_blank_formula_field
    name_for_invalid_formula_property = 'bad formula'
    create_property_definition_for(@project, name_for_invalid_formula_property, :type => 'formula', :formula => BLANK)
    assert_error_message("Formula cannot be blank.")
    assert_on_property_create_page_for(@project)
    navigate_to_property_management_page_for(@project)
    assert_property_not_present_on_property_management_page(name_for_invalid_formula_property)
  end
  
  def test_formula_property_cannot_be_updated_with_blank_formula_field
    size_times_two = 'size time two'
    setup_numeric_property_definition(SIZE, [2, 4])
    setup_formula_property_definition(size_times_two, "#{SIZE} * 2")
    open_property_for_edit(@project, size_times_two)
    type_formula(BLANK)
    click_save_property
    assert_error_message("Formula cannot be blank.")
  end
  
  def test_formula_property_can_not_use_managed_text_properties_as_operands
    name_for_invalid_formula_property = 'bad formula'
    formula_with_managed_text_property = "7 * #{STATUS}"
    create_property_definition_for(@project, name_for_invalid_formula_property, :type => 'formula', :formula => formula_with_managed_text_property)
    assert_error_message("Property #{STATUS} is not numeric.")
    assert_on_property_create_page_for(@project)
    navigate_to_property_management_page_for(@project)
    assert_property_not_present_on_property_management_page(name_for_invalid_formula_property)
  end
  
  def test_formula_property_can_not_use_free_text_properties_as_operands
    name_for_invalid_formula_property = 'bad formula'
    formula_with_free_text_property = "7 / #{FREE_TEXT_PROPERTY}"
    card = create_card!(:name => 'has free text')
    open_card(@project, card.number)
    add_new_value_to_property_on_card_show(@project, FREE_TEXT_PROPERTY, 6)
    add_new_value_to_property_on_card_show(@project, FREE_TEXT_PROPERTY, 4)
    create_property_definition_for(@project, name_for_invalid_formula_property, :type => 'formula', :formula => formula_with_free_text_property)
    assert_error_message("Property #{FREE_TEXT_PROPERTY} is not numeric.")
    assert_on_property_create_page_for(@project)
    navigate_to_property_management_page_for(@project)
    assert_property_not_present_on_property_management_page(name_for_invalid_formula_property)
  end
  
  def test_formula_property_cannot_use_user_properties_as_operands
    name_for_invalid_formula_property = 'bad formula value'
    formula_with_user_property = "#{USER_PROPERTY} + 15"
    create_property_definition_for(@project, name_for_invalid_formula_property, :type => 'formula', :formula => formula_with_user_property)
    assert_error_message("Property #{USER_PROPERTY} is not numeric.")
    assert_on_property_create_page_for(@project)
    navigate_to_property_management_page_for(@project)
    assert_property_not_present_on_property_management_page(name_for_invalid_formula_property)
  end
  
  # bug 2836
  def test_formula_can_contain_hidden_properties_as_operands
    size_plus_one = 'size plus one'
    setup_numeric_property_definition(SIZE, [2, 4])
    hide_property(@project, SIZE)
    transition_name = 'setting hidden size'
    create_property_definition_for(@project, size_plus_one, :type => 'formula', :formula => 'size + 1')
    assert_notice_message(CREATION_SUCCESSFUL_MESSAGE)
    transition_setting_hidden = create_transition_for(@project, transition_name, :set_properties => {SIZE => 4})
    card = create_card!(:name => 'card for testing')
    open_card(@project, card.number)
    click_transition_link_on_card(transition_setting_hidden)
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {SIZE => '4'})
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {size_plus_one => '5'})
    assert_properties_set_on_card_show(size_plus_one => '5')
  end
  
  def test_cannot_create_card_type_associated_to_formula_property_without_also_associating_operand_property
    size_times_two = 'size time two'
    setup_numeric_property_definition(SIZE, [2, 4])
    setup_formula_property_definition(size_times_two, "#{SIZE} * 2")
    create_card_type_for_project(@project, DEFECT, :properties => [size_times_two])
    assert_error_message("The component property #{SIZE} should be available to all card types that formula property #{size_times_two} is available to")
    navigate_to_card_type_management_for(@project)
    assert_card_type_not_present_on_card_type_management_page(DEFECT)
  end
  
  # bug 2838
  def test_when_numeric_property_has_spaces_it_requires_quoting_to_be_used_as_an_operand_in_a_formula
    numeric_property_name_with_spaces_and_parens = 'foo (bar)'
    formula_property_name = 'super formula'
    setup_numeric_property_definition(numeric_property_name_with_spaces_and_parens, [2, 4])
    invalid_formula_without_quoting = "#{numeric_property_name_with_spaces_and_parens} / 2"
    valid_formula_with_quotting = "'#{numeric_property_name_with_spaces_and_parens}' / 2"
    open_new_property_create_page_for(@project)
    @browser.click('definition_type_formula')
    type_property_name(formula_property_name)
    type_formula(invalid_formula_without_quoting)
    click_create_property
    # assert_error_message('The formula is not well formed. Unexpected characters encountered: "(" (L_PAREN).')
    @browser.assert_text_present('The formula is not well formed.')
    type_formula(valid_formula_with_quotting)
    click_create_property
    assert_notice_message(CREATION_SUCCESSFUL_MESSAGE)
    card = create_card!(:name => 'for testing')
    open_card(@project, card.number)
    set_properties_on_card_show(numeric_property_name_with_spaces_and_parens => 4)
    assert_properties_set_on_card_show(formula_property_name => '2')
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {numeric_property_name_with_spaces_and_parens => '4'})
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {formula_property_name => '2'})
  end
  
  # bug 2832
  def test_property_operand_in_formula_must_be_associated_to_same_card_types_as_formula_property_itself_during_creation
    size_times_two = 'size time two'
    setup_numeric_property_definition(SIZE, [2, 4])
    setup_card_type(@project, DEFECT, :properties => [])
    open_new_property_create_page_for(@project)
    type_property_name(size_times_two)
    check_the_card_types_required_for_a_property(@project, :card_types => [DEFECT])
    @browser.click('definition_type_formula')
    type_formula("#{SIZE} * 2")
    click_create_property
    assert_error_message("The component property should be available to all card types that formula property is available to.")
    navigate_to_property_management_page_for(@project)
    assert_property_not_present_on_property_management_page(DEFECT)
  end

  
  # bug 3182
  def test_removing_card_type_from_property_that_is_operand_of_formula_property_should_be_blocked
    size_times_two = 'size time two'
    setup_numeric_property_definition(SIZE, [2, 4])
    setup_formula_property_definition(size_times_two, "#{SIZE} * 2")
    setup_card_type(@project, DEFECT, :properties => [SIZE, size_times_two])
    open_property_for_edit(@project, SIZE)
    uncheck_card_types_required_for_a_property(@project, :card_types => [DEFECT])
    click_save_property 
    @browser.assert_text_present("Property #{SIZE} cannot be updated:")
    @browser.assert_text_present("#{SIZE} is used as a component property of #{size_times_two}.")
    open_property_for_edit(@project, size_times_two)
    assert_card_types_checked_or_unchecked_in_create_new_property_page(@project, :card_types_checked => [DEFECT])
    open_edit_card_type_page(@project, DEFECT)
    assert_properties_selected_for_card_type(@project, SIZE, size_times_two)
  end
  
  # bug 3001
  def test_can_create_formula_property_without_associating_it_to_any_card_types_when_no_operand_properties_are_used
    formula_property_name = 'minus three'
    formula = '-3'
    open_new_property_create_page_for(@project)
    @browser.click('definition_type_formula')
    type_property_name(formula_property_name)
    type_formula(formula)
    click_none_for_card_types
    click_create_property
    assert_notice_message(CREATION_SUCCESSFUL_MESSAGE)
    assert_property_present_on_property_management_page(formula_property_name)
    open_property_for_edit(@project, formula_property_name)
    assert_card_types_checked_or_unchecked_in_create_new_property_page(@project, :card_types_unchecked => ['Card'])
  end
  
  # bug 3186
  def test_can_add_valid_card_types_to_existing_formula_property
    size_times_two = 'size time two'
    setup_numeric_property_definition(SIZE, [2, 4])
    setup_formula_property_definition(size_times_two, "#{SIZE} * 2")
    setup_card_type(@project, DEFECT, :properties => [SIZE, size_times_two])
    
    open_property_for_edit(@project, size_times_two)
    uncheck_card_types_required_for_a_property(@project, :card_types => [DEFECT])
    click_save_property 
    click_continue_to_update
    
    open_property_for_edit(@project, SIZE)
    uncheck_card_types_required_for_a_property(@project, :card_types => [DEFECT])
    click_save_property 
    click_continue_to_update
    
    open_property_for_edit(@project, SIZE)
    check_the_card_types_required_for_a_property(@project, :card_types => [DEFECT])
    click_save_property
    open_property_for_edit(@project, size_times_two)
    check_the_card_types_required_for_a_property(@project, :card_types => [DEFECT])
    click_save_property
    assert_notice_message("Property was successfully updated")
    open_property_for_edit(@project, size_times_two)
    assert_card_types_checked_or_unchecked_in_create_new_property_page(@project, :card_types_checked => [DEFECT])
    open_edit_card_type_page(@project, DEFECT)
    assert_properties_selected_for_card_type(@project, SIZE, size_times_two)
  end
  
  def test_cannot_create_formula_property_with_invalid_text_operators
    invalid_operators = ['AND', 'OR', 'PLUS']
    setup_numeric_property_definition(SIZE, [2, 4])
    name_for_invalid_formula_property = 'super formula'
    invalid_operators.each do |invalid_operator|
      formula_with_invalid_operator = "1 #{invalid_operator} #{SIZE}"
      open_new_property_create_page_for(@project)
      @browser.click('definition_type_formula')
      type_property_name(name_for_invalid_formula_property)
      type_formula(formula_with_invalid_operator)
      click_create_property
      @browser.assert_text_present("The formula is not well formed.")
      navigate_to_property_management_page_for(@project)
      assert_property_not_present_on_property_management_page(name_for_invalid_formula_property)
    end
  end
  
  def test_cannot_create_formula_property_with_invalid_operators
   invalid_operators = ['%', '&', '!', '^']
    setup_numeric_property_definition(SIZE, [2, 4])
    name_for_invalid_formula_property = 'super formula'
    invalid_operators.each do |invalid_operator|
      formula_with_invalid_operator = "1 #{invalid_operator} #{SIZE}"
      open_new_property_create_page_for(@project)
      @browser.click('definition_type_formula')
      type_property_name(name_for_invalid_formula_property)
      type_formula(formula_with_invalid_operator)
      click_create_property
      @browser.assert_text_present("The formula is not well formed.")
      navigate_to_property_management_page_for(@project)
      assert_property_not_present_on_property_management_page(name_for_invalid_formula_property)
    end
  end

  # Bug 3726
  def test_division_in_formula_does_not_cause_error_500
    setup_numeric_property_definition(SIZE, [])
    formula_property = 'indivisible'
    setup_formula_property_definition(formula_property, "(5 + #{SIZE}) / (#{SIZE} - 5)")
    assert_error_message_not_present
    edit_property_definition_for(@project, formula_property, :new_formula => formula = "(5 / #{SIZE}) / (#{SIZE} / 5)")
    assert_error_message_not_present
    open_property_for_edit(@project, formula_property)
    assert_formula_for_formula_property(formula)
  end
  
  # Bug 4600
  def test_on_renaming_operand_with_special_char_or_having_operators_with_property_name_does_not_blow_up_mingle
    name_with_bang = 'formula!'
    name_with_operator = 'si+ze'
    setup_numeric_property_definition(SIZE, [])
    formula = setup_formula_property_definition("formula_property", "#{SIZE} - 5")

    navigate_to_property_management_page_for(@project)
    edit_property_definition_for(@project, SIZE, :new_property_name => name_with_bang)
    assert_notice_message('Property was successfully updated.')
    open_property_for_edit(@project, formula)
    assert_formula_for_formula_property("'#{name_with_bang}' - 5")
    
    new_size_property = edit_property_definition_for(@project, name_with_bang, :new_property_name => name_with_operator)
    assert_notice_message('Property was successfully updated.')
    open_property_for_edit(@project, formula)
    assert_formula_for_formula_property("'#{name_with_operator}' - 5")    
    navigate_to_property_management_page_for(@project)
    assert_properties_exist(new_size_property, formula)
  end
  
  # Bug 4620
  def test_on_renaming_property_name_to_number_updates_formula_with_quotes_to_take_is_as_property_not_constant
    new_name = '123'
    setup_numeric_property_definition(SIZE, [])
    formula = setup_formula_property_definition("formula_property", "#{SIZE} - 5")

    navigate_to_property_management_page_for(@project)
    edit_property_definition_for(@project, SIZE, :new_property_name => new_name)
    assert_notice_message('Property was successfully updated.')
    open_property_for_edit(@project, formula)
    assert_formula_for_formula_property("'#{new_name}' - 5")  
  end
  
  # 4527
  def test_renaming_numeric_property_used_in_formula_updates_the_formula_correctly_when_it_has_mathematical_operator
    size1 = 'card/size1'
    size2 = 'card\size2'
    formula = "#{size2} + '#{size1}'"
    size1_property = setup_numeric_property_definition(size1, [1, 2, 3])
    size2_property = setup_numeric_property_definition(size2, [])
    formula_property = create_property_definition_for(@project, "formula property", :type => 'formula', :formula => formula)
    
    edit_property_definition_for(@project, size2, :new_property_name => 'card/size2')
    assert_notice_message('Property was successfully updated.')
    
    open_property_for_edit(@project, formula_property.name)
    assert_formula_for_formula_property("'card/size2' + '#{size1}'")
  end
  
  # bug 4621
  def test_proeprty_name_with_a_quote_and_a_double_quote_does_not_blowup_app
    numeric_property_name_with_mix_quote = "siz\'es"
    numeric_property_name_with_mix_quote_with_doublig_quots = "siz\'\'es"
    formula_with_wrapped_in_double_quots ="\"siz\'es\" * 20"
    formula_with_wrapped_in_single_quots ="\'siz\'\'es\' * 20"
    formula_with_no_wrapped_quots = "siz\'\'es * 20"

    formulas_in_array = [formula_with_no_wrapped_quots, formula_with_wrapped_in_single_quots, formula_with_wrapped_in_double_quots]
    
    property_with_mix_quotes = setup_numeric_property_definition(numeric_property_name_with_mix_quote, [])

    formulas_in_array.each_with_index do |formula, index|
      @formula_property = create_property_definition_for(@project, "formula with quotes #{index}", :type => 'formula', :formula => formula)
      assert_notice_message("Property was successfully created.")
    end
    edit_property_definition_for(@project, property_with_mix_quotes.name, :new_property_name => "s'izes")
    assert_notice_message('Property was successfully updated.')
    
    (0..2).each do |index|
      open_property_for_edit(@project, "formula with quotes #{index}")
      assert_formula_for_formula_property("\"s\'izes\" * 20")
    end
  end
  
end
