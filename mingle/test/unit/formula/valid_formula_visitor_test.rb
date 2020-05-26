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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class ValidFormulaVisitorTest < ActiveSupport::TestCase

  def setup
    first_project.activate
  end
  
  def teardown
    Project.current.deactivate rescue nil
  end
  
  def test_formula_should_be_invalid_if_adding_multiple_dates
    assert_invalid "'start date' + 'start date'", %{The expression #{"'start date' + 'start date'".bold} is invalid because a date (#{"'start date'".bold}) cannot be added to a date (#{"'start date'".bold}). The supported operation is subtraction.}
  end
  
  def test_formula_should_be_valid_if_adding_numbers
    assert_valid "4 + 3"
  end
  
  def test_all_operators_should_work_with_numeric_properties
    assert_valid "Release + Release"
    assert_valid "Release - Release"
    assert_valid "Release / Release"
    assert_valid "Release * Release"
    assert_valid "-Release"
  end
  
  def test_formula_should_be_invalid_if_subtracting_date_from_a_number
    assert_invalid "4 - 'start date'", %{The expression #{"4 - 'start date'".bold} is invalid because a date (#{"'start date'".bold}) cannot be subtracted from a number (#{'4'.bold}). The supported operation is addition.}
  end
  
  def test_formula_should_be_invalid_if_attempting_scalar_multiplication_of_date
    assert_invalid "4 * 'start date'", %{The expression #{"4 * 'start date'".bold} is invalid because a number (#{'4'.bold}) cannot be multiplied by a date (#{"'start date'".bold}). The supported operation is addition.}
    assert_invalid "'start date' * 4", %{The expression #{"'start date' * 4".bold} is invalid because a date (#{"'start date'".bold}) cannot be multiplied by a number (#{'4'.bold}). The supported operations are addition, subtraction.}
  end
  
  def test_formula_should_be_invalid_if_attempting_scalar_multiplication_of_invalid_expression
    assert_invalid "4 * (1 - 'start date')"
    assert_invalid "(1 - 'start date') * 4"
  end
  
  def test_formula_should_be_invalid_if_attempting_division_of_date_by_scalar
    assert_invalid "'start date' / 4", %{The expression #{"'start date' / 4".bold} is invalid because a date (#{"'start date'".bold}) cannot be divided by a number (#{'4'.bold}). The supported operations are addition, subtraction.}
    assert_invalid "4 / 'start date'", %{The expression #{"4 / 'start date'".bold} is invalid because a number (#{'4'.bold}) cannot be divided by a date (#{"'start date'".bold}). The supported operation is addition.}
  end
  
  def test_formula_should_be_invalid_if_use_created_on
    assert_invalid "'created on' + 4", "#{'Created on'.bold} is predefined property and is not supported in formula properties."
    assert_invalid "'modified on' + 4", "#{'Modified on'.bold} is predefined property and is not supported in formula properties."
  end
  
  def test_formula_should_be_invalid_if_attempting_division_of_invalid_expression_by_scalar
    assert_invalid "4 / (1 - 'start date')"
    assert_invalid "(1 - 'start date') / 4"
  end
  
  def test_should_be_able_to_subtract_number_from_date
    assert_valid "'start date' - 4"
  end
  
  def test_should_be_able_to_subtract_date_from_date
    assert_valid "'start date' - 'start date'"
  end
  
  def test_formula_should_be_valid_with_nested_date_subtraction
    assert_valid "('start date' - 1) - ('start date' - 3)"
  end
  
  def test_should_be_invalid_with_nested_date_subtracted_from_number_1
    assert_invalid "'start date' - (1 - 'start date')"
  end
  
  def test_should_be_invalid_with_nested_date_subtracted_from_number_2
    assert_invalid "(1 - 'start date') - 'start date'"
  end
  
  def test_should_not_be_able_to_negate_a_date
    assert_invalid "- 'start date'"
  end
  
  def test_should_not_be_able_to_negate_an_invalid_expression
    assert_invalid "-(1 - 'start date')"
  end
  
  def test_should_be_able_to_negate_a_number
    assert_valid "-4"
  end
  
  def test_formula_cannot_contain_text_properties
    assert_invalid "1 + Status"
  end
  
  def test_formula_cannot_contain_text_properties_message
    assert_error_message "1 + Status", "Property #{'Status'.bold} is not numeric."
  end
  
  def test_formula_can_contain_aggregate_properties
    with_three_level_tree_project do |project|
      assert_valid "1 + 'Sum of size'"
    end
  end
  
  def test_formula_cannot_contain_formula_properties_message
    with_new_project do |project|
      setup_formula_property_definition('two', '2')
      assert_error_message "1 + two", "Property #{'two'.bold} is a formula property and cannot be used within another formula."
    end
  end
  
  def test_formula_cannot_contain_other_formulas
    with_new_project do |project|
      setup_formula_property_definition('two', '2')
      assert_invalid "1 + two"
      assert_invalid "1 - two"
      assert_invalid "1 * two"
      assert_invalid "1 / two"
      assert_invalid "-(two)"
    end
  end
  
  def assert_valid(formula_string)
    formula = formula(formula_string)
    assert formula.valid?
    assert formula.errors.empty?
  end
  
  def assert_invalid(formula_string, *expected_error_messages)
    formula = formula(formula_string)
    assert !formula.valid?
    if expected_error_messages.empty?
      assert !formula.errors.empty?
    else
      assert_equal expected_error_messages.sort, formula.errors.sort
    end
  end
  
  def assert_error_message(formula_string, *expected_error_messages)
    assert_equal expected_error_messages.sort, formula(formula_string).errors.sort
  end
  
  def formula(string)
    FormulaParser.new.parse(string)
  end  
end
