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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class FormulaTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree, SqlHelper

  def setup
    login_as_member
    @project = first_project
    @project.activate
    @card = @project.cards.first
    Clock.fake_now(:year => 2001, :month => 9, :day => 8)
  end

  def teardown
    Clock.reset_fake
  end

  def test_can_add_two_formulas
    simple_addition = Formula::Addition.new(Formula::Primitive.create(3), Formula::Primitive.create(4))
    assert_equal 7, simple_addition.value

    complex_addition = Formula::Addition.new(simple_addition, simple_addition)
    assert_equal 14, complex_addition.value
  end

  def test_can_add_a_date_and_a_scalar
    simple_addition = Formula::Addition.new(Formula::Primitive.create(Clock.today), Formula::Primitive.create(4))
    assert_equal Date.new(2001, 9, 12).strftime, simple_addition.value.strftime

    reverse_addition = Formula::Addition.new(Formula::Primitive.create(4), Formula::Primitive.create(Clock.today))
    assert_equal Date.new(2001, 9, 12), reverse_addition.value
  end

  def test_unary_minus
    assert_equal -1, FormulaParser.new.parse('-1').value
    assert_equal -12, FormulaParser.new.parse('3 * -4').value
    assert_equal -12, FormulaParser.new.parse('4*-3').value
    assert_equal 12, FormulaParser.new.parse('-4*-3').value
    assert_equal -12, FormulaParser.new.parse('-4*3').value
  end

  def test_can_subtract_two_formulas
    simple_subtraction = Formula::Subtraction.new(Formula::Primitive.create(3), Formula::Primitive.create(4))
    assert_equal -1, simple_subtraction.value

    complex_subtraction = Formula::Subtraction.new(simple_subtraction, simple_subtraction)
    assert_equal 0, complex_subtraction.value
  end

  def test_can_subtract_scalars_from_dates_but_not_the_other_way_around
    simple_subtraction = Formula::Subtraction.new(Formula::Primitive.create(Clock.today), Formula::Primitive.create(4))
    assert_equal Date.new(2001, 9, 4), simple_subtraction.value

    assert_raise Formula::UnsupportedOperationException do
      Formula::Subtraction.new(Formula::Primitive.create(4), Formula::Primitive.create(Clock.today)).value.strftime
    end

    # I can't prove that this can happen (a Date not wrapped in a Primitive object), but it's worth covering
    assert_raise Formula::UnsupportedOperationException do
      Formula::Subtraction.new(Formula::Primitive.create(4), Date.new).value.strftime
    end
  end

  def test_can_multiply_and_divide_two_formulas
    simple_multiplication = Formula::Multiplication.new(Formula::Primitive.create(3), Formula::Primitive.create(4))
    assert_equal 12, simple_multiplication.value

    complex_multiplication = Formula::Multiplication.new(simple_multiplication, simple_multiplication)
    assert_equal 144, complex_multiplication.value

    simple_division = Formula::Division.new(Formula::Primitive.create(3), Formula::Primitive.create(4))
    assert_equal 0.75, simple_division.value

    complex_division = Formula::Division.new(simple_division, simple_division)
    assert_equal 1, complex_division.value
  end

  def test_can_use_card_property_values_in_formula_evaluation
    release = @project.find_property_definition('release')
    release.update_card(@card, '2')
    @card.save!

    card_property_value = Formula.new(Formula::CardPropertyValue.new('release'))
    assert_equal 2, card_property_value.value(@card)

    release.update_card(@card, '1')
    @card.save!
    assert_equal 1, card_property_value.value(@card)
  end

  def test_can_use_card_property_values_in_math
    release = @project.find_property_definition('release')
    release.update_card(@card, '2')
    @card.save!

    card_property_value = Formula::CardPropertyValue.new('release')
    simple_multiplication = Formula.new(Formula::Multiplication.new(Formula::Primitive.create(3), card_property_value))

    assert_equal 6, simple_multiplication.value(@card)
  end

  def test_can_evaluate_expressions_that_have_intermediate_steps_that_evaluate_to_integers
    release = @project.find_property_definition('release')
    release.update_card(@card, '2')
    @card.save!

    card_property_value = Formula::CardPropertyValue.new('release')
    assert_equal 27, FormulaParser.new.parse('3 * 3 * 3').value(@card)

    assert_equal 12, FormulaParser.new.parse('3 * (release + release / 2 + 1)').value(@card)
    assert_equal 3, FormulaParser.new.parse('release + release / 2').value(@card)

    assert_equal 12, FormulaParser.new.parse('3 * (release + release/2 * release)').value(@card)
  end

  def test_can_multiply_fixnums_and_primitives
    assert_equal 6, 2 * Formula::Primitive.create(3)
    assert_equal 6, Formula::Primitive.create(3) * 2
  end

  def test_should_return_sql_form_of_formula
    thrice_release = FormulaParser.new.parse('3 * release')
    for_postgresql do
      assert_equal %{CAST(CAST(3 AS DECIMAL(#{connection.max_precision}, 10)) * CAST(#{Card.quoted_table_name}."cp_release" AS DECIMAL(#{connection.max_precision}, 10)) AS DECIMAL(#{connection.max_precision}, 2))}, thrice_release.to_sql
    end
    for_oracle do
      assert_equal "TO_CHAR(CAST(3 AS DECIMAL(38, 10)) * CAST(#{Card.quoted_table_name}.cp_release AS DECIMAL(38, 10)), 'FM999999999999999999999999999999999990.00')", thrice_release.to_sql
    end
  end

  def test_should_return_sql_form_of_formula_with_properties_substituted_for_numbers
    with_new_project do |project|
      num1 = setup_numeric_property_definition('num1', [1, 2])
      num2 = setup_numeric_property_definition('num2', [1, 2])
      date = setup_date_property_definition('date')

      for_postgresql do
        assert_equal %{CAST(CAST(#{Card.quoted_table_name}."cp_num1" AS DECIMAL(#{connection.max_precision}, 10)) + CAST(55 AS DECIMAL(#{connection.max_precision}, 10)) AS DECIMAL(#{connection.max_precision}, 2))}, FormulaParser.new.parse('num1 + num2').to_sql(Card.table_name, false, { num2 => 55 })
        assert_equal %{CAST(CAST(#{Card.quoted_table_name}."cp_num1" AS DECIMAL(#{connection.max_precision}, 10)) + CAST(NULL AS DECIMAL(#{connection.max_precision}, 10)) AS DECIMAL(#{connection.max_precision}, 2))}, FormulaParser.new.parse('num1 + num2').to_sql(Card.table_name, false, { num2 => nil })
        assert_equal "(CAST((date '2008-04-12' + CAST(CAST(5 AS NUMERIC) AS INTEGER)) AS DATE))", FormulaParser.new.parse('date + 5').to_sql(Card.table_name, false, { date => '12 Apr 2008' })
        assert_equal %{CAST((CASE WHEN (CAST(55 AS DECIMAL(#{connection.max_precision}, 10)) = 0) THEN NULL ELSE (CAST(55 AS DECIMAL(#{connection.max_precision}, 10)) * CAST(#{Card.quoted_table_name}."cp_num2" AS DECIMAL(#{connection.max_precision}, 10)) / CAST(55 AS DECIMAL(#{connection.max_precision}, 10))) END) AS DECIMAL(#{connection.max_precision}, 2))}, FormulaParser.new.parse('num1 * num2 / num1').to_sql(Card.table_name, false, num1 => 55)
      end
    end
  end

  def test_should_parse_numbers_with_decimal_points
    ["12", "12.0", ".012", "0.12", ".0", "11."].each do |i|
      FormulaParser.new.parse(i).value(nil)
    end

    ["0..1", ".", ""].each do |i|
      begin
        FormulaParser.new.parse(i)
        fail
      rescue Exception
        assert true
      end
    end
  end

  def test_should_produce_nulls_correctly_when_using_urary_minus
    release = @project.find_property_definition('release')
    release.update_card(@card, nil)
    @card.save!

    minus_three = Formula::Negation.new(Formula::Primitive.create(3))
    bracket_null = Formula.new(Formula::Null.new)
    assert_nil FormulaParser.new.parse('-3 * (release)').value(@card).to_s
  end

  def test_should_parse_different_kinds_of_brackets
    assert_equal '(3 * 4)', FormulaParser.new.parse('(3 * 4)').to_s[1..-2]
    assert_equal '{3 * 4}', FormulaParser.new.parse('{3 * 4}').to_s[1..-2]
    assert_equal '[3 * 4]', FormulaParser.new.parse('[3 * 4]').to_s[1..-2]
  end

  def test_can_use_date_property_values_in_math
    start_date = @project.find_property_definition('start date')
    start_date.update_card(@card, '24 March 2007')
    @card.save!

    card_property_value = Formula::CardPropertyValue.new('start date')
    addition = Formula.new(Formula::Addition.new(card_property_value, Formula::Primitive.create(3)))

    assert_equal Date.new(2007, 3, 27), addition.value(@card)
  end

  def test_can_subtract_two_dates_in_sql_using_formulae
    formula = FormulaParser.new.parse("'start date' - 'start date'")

    for_postgresql { assert_equal %{CAST(#{Card.quoted_table_name}."cp_start_date" - #{Card.quoted_table_name}."cp_start_date" AS DECIMAL(#{connection.max_precision}, 2))}, formula.to_sql }
    for_oracle { assert_equal %{TO_CHAR(#{Card.quoted_table_name}.cp_start_date - #{Card.quoted_table_name}.cp_start_date, 'FM999999999999999999999999999999999990.00')}, formula.to_sql }
  end

  def test_cannot_add_two_dates_using_formulae
    start_date = @project.find_property_definition('start date')
    start_date.update_card(@card, '24 March 2007')
    @card.save!

    card_property_value = Formula::CardPropertyValue.new('start date')
    assert_raise Formula::UnsupportedOperationException do
      Formula.new(Formula::Addition.new(card_property_value, card_property_value)).value(@card)
    end
  end

  def test_formulae_know_their_output_type
    assert_kind_of Formula::Number, Formula::Primitive.create(3).output_type
    assert_kind_of Formula::Date, Formula::Primitive.create(Clock.today).output_type
    assert_kind_of Formula::Number, FormulaParser.new.parse('2').output_type
    assert_kind_of Formula::Number, FormulaParser.new.parse('2 + 3').output_type
    assert_kind_of Formula::NullType, FormulaParser.new.parse('(2 + 3) - (6 / 0)').output_type
    assert_kind_of Formula::NullType, FormulaParser.new.parse('(2 + 3) + (6 / 0)').output_type
    assert_kind_of Formula::NullType, FormulaParser.new.parse('(2 - 3) * {6 / 0}').output_type
    assert_kind_of Formula::Date, Formula::Addition.new(Formula::Primitive.create(3), Formula::Primitive.create(Clock.today)).output_type
    assert_kind_of Formula::Number, Formula::Subtraction.new(Formula::Primitive.create(Clock.today), Formula::Primitive.create(Clock.today)).output_type
    assert_kind_of Formula::NullType, Formula::Multiplication.new(Formula::Primitive.create(Clock.today), Formula::Primitive.create(Clock.today)).output_type
    assert_kind_of Formula::NullType, Formula::Division.new(Formula::Primitive.create(Clock.today), Formula::Primitive.create(Clock.today)).output_type
  end

  def test_null_behaviour
    assert_null_propogates_as_null_through_all_operations_with(2)
    assert_null_propogates_as_null_through_all_operations_with(Formula::Primitive.create(2))
    assert_null_propogates_as_null_through_all_operations_with(Formula::Primitive.create(Clock.today))
  end

  def assert_null_propogates_as_null_through_all_operations_with(argument)
    null = Formula::Null.new

    assert_equal null, (null + argument)
    assert_equal null, (null - argument)
    assert_equal null, (null * argument)
    assert_equal null, (null / argument)
    assert_equal null, (argument + null)
    assert_equal null, (argument - null)
    unless Formula::DatePrimitive === argument
      assert_equal null, (argument * null)
      assert_equal null, (argument / null)
    end
  end

  def test_date_added_to_scalar_will_build_appropriate_sql
    start_date = @project.find_property_definition('start date')
    start_date.update_card(@card, '24 March 2007')
    @card.save!

    card_property_value = Formula::CardPropertyValue.new('start date')
    addition = Formula.new(Formula::Addition.new(card_property_value, Formula::Primitive.create(3)))

    for_postgresql { assert_equal %{(#{Card.quoted_table_name}."cp_start_date" + CAST(CAST(3 AS NUMERIC) AS INTEGER))}, addition.to_sql }
    for_oracle { assert_equal %{(#{Card.quoted_table_name}.cp_start_date + CAST(CAST(3 AS NUMERIC) AS INTEGER))}, addition.to_sql }
  end

  def test_should_not_allow_multiplication_or_division_of_a_date_by_scalars
    card_property_value = Formula::CardPropertyValue.new('start date')
    invalid_multiplication = Formula.new(Formula::Multiplication.new(card_property_value, Formula::Primitive.create(3)))

    assert !invalid_multiplication.valid?
    assert_equal [%{The expression #{"'start date' * 3".bold} is invalid because a date (#{"'start date'".bold}) cannot be multiplied by a number (#{'3'.bold}). The supported operations are addition, subtraction.}], invalid_multiplication.errors
  end

  def test_should_have_valid_error_for_formula_that_attempts_to_subtract_a_date_from_a_scalar
    card_property_value = Formula::CardPropertyValue.new('start date')
    invalid_subtraction = Formula.new(Formula::Subtraction.new(Formula::Primitive.create(2), card_property_value))

    assert !invalid_subtraction.valid?
    assert_equal [%{The expression #{"2 - 'start date'".bold} is invalid because a date (#{"'start date'".bold}) cannot be subtracted from a number (#{'2'.bold}). The supported operation is addition.}], invalid_subtraction.errors
  end

  def test_should_have_valid_error_for_formula_that_attempts_to_negate_a_date
    card_property_value = Formula::CardPropertyValue.new('start date')
    invalid_negation = Formula.new(Formula::Negation.new(card_property_value))

    assert !invalid_negation.valid?
    assert_equal [%{The expression #{"-'start date'".bold} is invalid because #{"'start date'".bold} is a date and cannot be negated.}], invalid_negation.errors
  end

  def test_should_have_valid_error_for_formula_that_attempts_to_operate_on_two_dates_but_is_not_subtraction
    card_property_value = Formula::CardPropertyValue.new('start date')
    invalid_operation = Formula.new(Formula::Addition.new(card_property_value, card_property_value))

    assert !invalid_operation.valid?
    assert_equal [%{The expression #{"'start date' + 'start date'".bold} is invalid because a date (#{"'start date'".bold}) cannot be added to a date (#{"'start date'".bold}). The supported operation is subtraction.}], invalid_operation.errors

    invalid_operation = Formula.new(Formula::Multiplication.new(card_property_value, card_property_value))
    assert !invalid_operation.valid?
    assert_equal [%{The expression #{"'start date' * 'start date'".bold} is invalid because a date (#{"'start date'".bold}) cannot be multiplied by a date (#{"'start date'".bold}). The supported operation is subtraction.}], invalid_operation.errors

    invalid_operation = Formula.new(Formula::Division.new(card_property_value, card_property_value))
    assert !invalid_operation.valid?
    assert_equal [%{The expression #{"'start date' / 'start date'".bold} is invalid because a date (#{"'start date'".bold}) cannot be divided by a date (#{"'start date'".bold}). The supported operation is subtraction.}], invalid_operation.errors
  end

  # bug 3052
  def test_should_have_valid_error_for_formula_that_attempts_to_use_another_formula_as_a_component
    with_new_project do |project|
      hello = setup_formula_property_definition('hello', '1 + 2')
      bye = setup_formula_property_definition('bye', '1 + 2')

      formula = FormulaParser.new.parse('hello + 1')
      assert !formula.valid?
      assert_equal ["Property #{'hello'.bold} is a formula property and cannot be used within another formula."], formula.errors

      formula = FormulaParser.new.parse('hello + 1 + bye')
      assert !formula.valid?
      assert_equal ["Properties #{'hello'.bold} and #{'bye'.bold} are formula properties and cannot be used within another formula."], formula.errors
    end
  end

  def test_should_be_able_to_use_hidden_properties_in_a_formula
    release = @project.find_property_definition('release')
    release.update_card(@card, '2')
    @card.save!

    release.hidden = true
    release.save!

    formula = FormulaParser.new.parse('3 * (release + release / 2 + 1)')
    assert_equal 12, formula.value(@card)
  end

  def test_should_not_be_able_to_subtract_date_property_from_a_number
    formula = FormulaParser.new.parse("2 - 'start date'")
    assert_equal %{The expression #{"2 - 'start date'".bold} is invalid because a date (#{"'start date'".bold}) cannot be subtracted from a number (#{'2'.bold}). The supported operation is addition.}, formula.errors.join
  end

  def test_should_not_be_able_to_divide_a_date_property_by_a_number_or_vice_versa
    formula = FormulaParser.new.parse("'start date' / 2")
    assert_equal %{The expression #{"'start date' / 2".bold} is invalid because a date (#{"'start date'".bold}) cannot be divided by a number (#{'2'.bold}). The supported operations are addition, subtraction.}, formula.errors.join

    formula = FormulaParser.new.parse("2 / 'start date'")
    assert_equal %{The expression #{"2 / 'start date'".bold} is invalid because a number (#{'2'.bold}) cannot be divided by a date (#{"'start date'".bold}). The supported operation is addition.}, formula.errors.join
  end

  def test_should_not_be_able_to_divide_a_date_property_by_zero
    formula = FormulaParser.new.parse("'start date' / 0")
    assert_equal %{The expression #{"'start date' / 0".bold} is invalid because a date (#{"'start date'".bold}) cannot be divided by a number (#{'0'.bold}). The supported operations are addition, subtraction.}, formula.errors.join

    formula = FormulaParser.new.parse("0 / 'start date'")
    assert_equal "The expression #{"0 / 'start date'".bold} is invalid because a number (#{'0'.bold}) cannot be divided by a date (#{"'start date'".bold}). The supported operation is addition.", formula.errors.join
  end

  def test_can_evaluate_expressions_that_have_property_names_with_quotes_as_long_as_you_double_quote_the_name
    with_new_project do |project|
      size = setup_numeric_property_definition("'size'", [1, 2, 3])
      card = project.cards.create!(:name => 'card one', :card_type_name => 'Card', :cp__size_ => '2')
      assert_equal 5, FormulaParser.new.parse("\"'size'\" + 3").value(card)
    end
  end

  # bug 3726
  def test_can_ask_for_output_type_when_dividing_by_a_property_in_parentheses
    release = @project.find_property_definition('Release')
    card = @project.cards.create!(:name => 'card one', :card_type_name => 'Card', :cp_release => '2')
    assert_equal Formula::Number.new, FormulaParser.new.parse("10 / 'Release'").output_type
    assert_equal Formula::Number.new, FormulaParser.new.parse("10 / ('Release')").output_type
  end

  # bug 4527 - backslash portion
  def test_property_names_with_backslash_should_be_parseable
    with_new_project do |project|
      cost_size = setup_numeric_property_definition('Cost\Size', [1, 2, 3])
      card = project.cards.create!(:name => 'some card', :card_type_name => 'Card', :cp_1 => '3')
      assert_equal 5, FormulaParser.new.parse('Cost\Size + 2').value(card)
    end
  end

  # bug 4600
  def test_property_names_with_characters_other_than_mathematical_ones_should_be_parseable_without_having_to_put_quotes
    with_new_project do |project|
      assert_can_parse_with_property_named('s!@$%^_\~`{}|;.,:?<>ize')
    end
  end

  # bug 4621
  def test_property_names_with_single_and_double_quotes_can_should_be_parseable_if_quotes_are_escaped
    with_new_project do |project|
      some_property = setup_numeric_property_definition(%{hello'there}, [1, 2, 3])
      card = project.cards.create!(:name => 'some card', :card_type_name => 'Card', :cp_hello_there => '3')
      assert_equal 5, FormulaParser.new.parse(%{hello''there + 2}).value(card)

      some_property = setup_numeric_property_definition(%{hello' there}, [1, 2, 3])
      card = project.cards.create!(:name => 'some other card', :card_type_name => 'Card', :cp_hello__there => '3')
      assert_equal 5, FormulaParser.new.parse(%{"hello' there" + 2}).value(card)
      assert_equal 5, FormulaParser.new.parse(%{'hello'' there' + 2}).value(card)

      some_property = setup_numeric_property_definition(%{hello ther'e}, [1, 2, 3])
      card = project.cards.create!(:name => 'some other card 2', :card_type_name => 'Card', :cp_hello_ther_e => '3')
      assert_equal 5, FormulaParser.new.parse(%{'hello ther''e' + 2}).value(card)
      assert_equal 5, FormulaParser.new.parse(%{'hello ther''e'+2}).value(card)


      some_property = setup_numeric_property_definition(%{hello' +there}, [1, 2, 3])
      card = project.cards.create!(:name => 'some other card 4', :card_type_name => 'Card', :cp_1 => '3')
      assert_equal 5, FormulaParser.new.parse(%{"hello' +there"+2}).value(card)
      assert_equal 5, FormulaParser.new.parse(%{'hello'' +there'+2}).value(card)
    end
  end

  # bug 4621
  def test_parser_is_not_greedy_when_finding_property_names_between_quotes
    with_new_project do |project|
      hello = setup_numeric_property_definition('hello', [1, 2, 3])
      goodbye = setup_numeric_property_definition('goodbye', [1, 2, 3])
      card = project.cards.create!(:name => 'hiya', :card_type_name => 'Card', :cp_hello => '1', :cp_goodbye => '2')

      # case: single quotes; if the parser was greedy, it would mistakenly think hello' + 'goodbye is the property between quotes
      assert_equal 3, FormulaParser.new.parse("'hello' + 'goodbye'").value(card)

      # case: double quotes; if the parser was greedy, it would mistakenly think hello" + "goodbye is the property between quotes
      assert_equal 3, FormulaParser.new.parse("\"hello\" + \"goodbye\"").value(card)
    end
  end

  # Bug 7608
  def test_to_sql_should_turn_empty_string_into_null_when_using_numeric_property_overrides
    cp_release = @project.find_property_definition('release')
    thrice_release = FormulaParser.new.parse('3 * release')
    sql = thrice_release.to_sql(Card.table_name, false, cp_release => '')
    for_postgresql do
      assert_equal %{CAST(CAST(3 AS DECIMAL(#{connection.max_precision}, 10)) * CAST(NULL AS DECIMAL(#{connection.max_precision}, 10)) AS DECIMAL(#{connection.max_precision}, 2))}, sql
    end
    for_oracle do
      assert_equal "TO_CHAR(CAST(3 AS DECIMAL(38, 10)) * CAST(NULL AS DECIMAL(38, 10)), 'FM999999999999999999999999999999999990.00')", sql
    end
  end

  def test_to_sql_should_turn_empty_string_into_null_when_using_date_property_overrides
    cp_start_date = @project.find_property_definition('start date')
    parking_time = FormulaParser.new.parse("'start date' - 'created on'")
    sql = parking_time.to_sql(Card.table_name, false, cp_start_date => '')
    for_postgresql do
      assert_equal "CAST(NULL - \"first_project_cards\".\"created_at\" AS DECIMAL(#{connection.max_precision}, 2))", sql
    end

    for_oracle do
      assert_equal "TO_CHAR(TO_DATE(NULL, 'YYYY-MM-DD') - first_project_cards.created_at, 'FM999999999999999999999999999999999990.00')", sql
    end
  end

  def test_to_sql_should_return_value_represented_by_plv_when_using_numeric_property_overrides
    cp_numeric = @project.find_property_definition('Release')
    create_plv!(@project, :name => 'current release', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '2', :property_definition_ids => [cp_numeric.id])
    sql = FormulaParser.new.parse("3 * Release").to_sql(Card.table_name, false, cp_numeric => '(current release)')

    for_postgresql do
      assert_equal %{CAST(CAST(3 AS DECIMAL(%s, 10)) * CAST(2 AS DECIMAL(%s, 10)) AS DECIMAL(%s, 2))} % (Array(connection.max_precision) * 3), sql
    end
    for_oracle do
      assert_equal %{TO_CHAR(CAST(3 AS DECIMAL(%s, 10)) * CAST(2 AS DECIMAL(%s, 10)), 'FM999999999999999999999999999999999990.00')} % (Array(connection.max_precision) * 2), sql
    end
  end

  def test_can_add_dates_and_numeric_decimal_primitives
    cp_start_date = @project.find_property_definition('start date')

    card = @project.cards.create!(:name => 'I am card', :card_type_name => 'Card')
    cp_start_date.update_card(card, '20 Dec 2009')
    card.save!

    assert_equal "2009-12-22", FormulaParser.new.parse("'start date' + 2.1").value(card).to_s
    assert_equal "2009-12-22", FormulaParser.new.parse("2.1 + 'start date'").value(card).to_s
    assert_equal "2009-12-23", FormulaParser.new.parse("'start date' + 2.6").value(card).to_s
    assert_equal "2009-12-23", FormulaParser.new.parse("2.6 + 'start date'").value(card).to_s
    assert_equal "2009-12-23", FormulaParser.new.parse("'start date' + 2.5").value(card).to_s
    assert_equal "2009-12-23", FormulaParser.new.parse("2.5 + 'start date'").value(card).to_s
  end

  def test_can_subtract_dates_and_numeric_decimal_primitives
    cp_start_date = @project.find_property_definition('start date')

    card = @project.cards.create!(:name => 'I am card', :card_type_name => 'Card')
    cp_start_date.update_card(card, '20 Dec 2009')
    card.save!

    assert_equal "2009-12-18", FormulaParser.new.parse("'start date' - 2.1").value(card).to_s
    assert_equal "2009-12-17", FormulaParser.new.parse("'start date' - 2.6").value(card).to_s
    assert_equal "2009-12-17", FormulaParser.new.parse("'start date' - 2.5").value(card).to_s
  end

  def test_can_add_and_subtract_dates_and_numeric_properties_when_the_property_is_set_to_a_decimal_value
    cp_start_date = @project.find_property_definition('start date')
    cp_numeric = @project.find_property_definition('Release')

    card = @project.cards.create!(:name => 'I am card', :card_type_name => 'Card')
    cp_start_date.update_card(card, '20 Dec 2009')
    cp_numeric.update_card(card, '2.1')
    card.save!

    assert_equal "2009-12-22", FormulaParser.new.parse("'start date' + Release").value(card).to_s
    assert_equal "2009-12-22", FormulaParser.new.parse("Release + 'start date'").value(card).to_s
    assert_equal "2009-12-18", FormulaParser.new.parse("'start date' - Release").value(card).to_s

    cp_numeric.update_card(card, '2.6')
    card.save!

    assert_equal "2009-12-23", FormulaParser.new.parse("'start date' + Release").value(card).to_s
    assert_equal "2009-12-23", FormulaParser.new.parse("Release + 'start date'").value(card).to_s
    assert_equal "2009-12-17", FormulaParser.new.parse("'start date' - Release").value(card).to_s
  end

  # bug 8179
  def test_can_add_and_subtract_dates_and_numeric_expressions_when_the_expression_evaluates_to_a_decimal
    with_card_query_project do |p|
      cp_size = p.find_property_definition('Size')
      cp_accurate_estimate = p.find_property_definition('accurate_estimate')
      cp_date_created = p.find_property_definition('date_created')

      card = p.cards.create!(:name => 'I am card', :card_type_name => 'Card')
      cp_date_created.update_card(card, '20 Dec 2009')
      cp_size.update_card(card, '5')
      cp_accurate_estimate.update_card(card, '2.32')
      card.save!

      assert_equal "2009-12-22", FormulaParser.new.parse("date_created + (size / 2.5)").value(card).to_s
      assert_equal "2009-12-18", FormulaParser.new.parse("date_created - (size / 2.5)").value(card).to_s
      assert_equal "2009-12-22", FormulaParser.new.parse("(size / 2.5) + date_created").value(card).to_s

      assert_equal "2009-12-22", FormulaParser.new.parse("date_created + (size / accurate_estimate)").value(card).to_s  # 5 / 2.32 = 2.15517, which rounds down to 2
      assert_equal "2009-12-22", FormulaParser.new.parse("(size / accurate_estimate) + date_created").value(card).to_s  # 5 / 2.32 = 2.15517, which rounds down to 2
      assert_equal "2009-12-18", FormulaParser.new.parse("date_created - (size / accurate_estimate)").value(card).to_s  # 5 / 2.32 = 2.15517, which rounds down to 2

      assert_equal "2009-12-25", FormulaParser.new.parse("date_created + (accurate_estimate * 2)").value(card).to_s  # 2.32 * 2 = 4.64, which rounds to 5
      assert_equal "2009-12-15", FormulaParser.new.parse("date_created - (accurate_estimate * 2)").value(card).to_s  # 2.32 * 2 = 4.64, which rounds to 5
      assert_equal "2009-12-25", FormulaParser.new.parse("(accurate_estimate * 2) + date_created").value(card).to_s  # 2.32 * 2 = 4.64, which rounds to 5
    end
  end

  # bug 8630
  def test_can_subtract_an_expression_that_evaluates_to_a_primitive_from_a_numeric_property
    with_card_query_project do |p|
      card = p.cards.create!(:name => 'I am card', :card_type_name => 'Card', :cp_size => 100, :cp_accurate_estimate => 5)
      assert_equal "50", FormulaParser.new.parse("size - (accurate_estimate * 10)").value(card).to_s
    end
  end

  # bug 8633
  def test_can_subtract_an_expression_that_evaluates_to_a_primitive_date_from_a_date_property
    with_card_query_project do |p|
      cp_size = p.find_property_definition('Size')
      cp_accurate_estimate = p.find_property_definition('accurate_estimate')
      cp_date_created = p.find_property_definition('date_created')

      card = p.cards.create!(:name => 'I am card', :card_type_name => 'Card')
      cp_date_created.update_card(card, '20 Dec 2009')
      cp_size.update_card(card, '5')
      cp_accurate_estimate.update_card(card, '2.32')
      card.save!
      assert_equal '5', FormulaParser.new.parse('date_created - (date_created - 5)').value(card).to_s
    end
  end

  # bug 10348
  def test_property_in_formula_rename_ignores_case_and_whitespace
    with_card_query_project do |project|
      cp_size = project.find_property_definition('Size')
      formula = FormulaParser.new.parse("' sIzE ' * 2")
      formula.rename_property("size", "Estimated Size")
      assert_equal "('Estimated Size' * 2)", formula.to_s
    end
  end

  def test_that_property_with_special_character_in_formula_is_quoted
    with_new_project do |project|
      formula = FormulaParser.new.parse("vélocité * 2")
      assert_equal "('vélocité' * 2)", formula.to_s
    end
  end

  def test_that_formula_can_calculate_values_from_properties_with_special_characters
    with_new_project do |project|
      velocity = UnitTestDataLoader.setup_numeric_property_definition("Vélocité", [1, 2, 3, 4])
      prop = UnitTestDataLoader.setup_formula_property_definition("french", "Vélocité / 2")

      card = project.cards.create!(:name => 'used in formula', :card_type_name => 'Card', :"#{velocity.column_name}" => 4)
      assert_equal ["2"], prop.values
    end
  end

  private

  def assert_can_parse_with_property_named(prop_def_name)
    assert_nothing_raised do
      FormulaParser.new.parse("#{prop_def_name} + 2")
    end
  end
end
