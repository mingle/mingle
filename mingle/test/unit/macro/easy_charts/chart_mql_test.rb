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

require File.expand_path(File.dirname(__FILE__) + '../../../../unit_test_helper')

class EasyChartsMqlTest < ActiveSupport::TestCase

  def setup
    login_as_member
    @project = pie_chart_test_project
    @project.activate
  end

  test 'from_should_extract_chart_condition_from_query' do
    data_query = CardQuery.parse('Select Size, count(*) Where Type = "Card" AND Size < 10')

    chart_mql = EasyCharts::ChartMql.from(data_query)
    chart_conditions = chart_mql.conditions

    assert_equal 2, chart_conditions.size
    assert_chart_condition('Type', Operator::Equals, [%w(Card Card)], chart_conditions[0])
    assert_chart_condition('size', Operator::LessThan, [%w(10 10)], chart_conditions[1])
    assert_equal('Card', chart_conditions[1].property_type)
  end

  test 'from_should_extract_card_type_condition_when_no_chart_conditions_are_specified' do
    data_query = CardQuery.parse('Select Size, count(*) Where Type = "Card"')

    chart_mql = EasyCharts::ChartMql.from(data_query)
    chart_conditions = chart_mql.conditions

    assert_equal 1, chart_conditions.size
    assert_chart_condition('Type', Operator::Equals, [%w(Card Card)], chart_conditions[0])
  end

  test 'from_should_extract_card_type_condition_having_in_clause' do
    data_query = CardQuery.parse('Select Size, count(*) Where Type IN ("Card", "Story")')

    chart_mql = EasyCharts::ChartMql.from(data_query)
    chart_conditions = chart_mql.conditions

    assert_equal 1, chart_conditions.size
    assert_chart_condition('Type', Operator::Equals, [%w(Card Card), %w(Story Story)], chart_conditions[0])
  end

  test 'from_should_extract_chart_condition_for_multiple_and_conditions' do
    with_three_level_tree_project do
      data_query = CardQuery.parse('SELECT size, COUNT(*) WHERE "Type" IN ("story") AND "size" > 12 AND "Planning iteration" = NUMBER 3 AND "Planning iteration" != NUMBER 2')

      chart_mql = EasyCharts::ChartMql.from(data_query)
      chart_conditions = chart_mql.conditions

      assert_equal 4, chart_conditions.size
      assert_chart_condition('Type', Operator::Equals, [%w(story story)], chart_conditions[0])
      assert_equal('Card', chart_conditions[1].property_type)
      assert_chart_condition('size', Operator::GreaterThan, [%w(12 12)], chart_conditions[1])

      assert_equal('Tree', chart_conditions[2].property_type)
      assert_chart_condition('Planning iteration', Operator::Equals, [['#3 iteration2', '3']], chart_conditions[2])

      assert_equal('Tree', chart_conditions[3].property_type)
      assert_chart_condition('Planning iteration', Operator::NotEquals, [['#2 iteration1', '2']], chart_conditions[3])
    end
  end

  test 'from_should_raise_exception_for_an_invalid_or_condition' do
    with_three_level_tree_project do
      data_query = CardQuery.parse('SELECT size, COUNT(*) WHERE "Type" IN ("story") OR "size" > 12 AND NOT("Planning iteration" = NUMBER 3) AND "Planning iteration" != NUMBER 2')

      assert_raise_with_message(EasyCharts::InvalidChartMqlException, 'Invalid OR condition') do
        EasyCharts::ChartMql.from(data_query)
      end
    end
  end

  test 'from_should_raise_condition_for_non_existent_cards' do
    with_three_level_tree_project do
      data_query = CardQuery.parse('SELECT size, COUNT(*) WHERE "Type" IN ("story") AND "size" > 12 AND ("Planning iteration" != NUMBER 3 AND "Planning iteration" != NUMBER 7)')

      assert_raise_with_message(EasyCharts::InvalidChartMqlException, "Card doesn't exist") do
        EasyCharts::ChartMql.from(data_query)
      end
    end
  end

  test 'from_should_raise_exception_when_user_does_not_exist' do
    with_three_level_tree_project do
      data_query = CardQuery.parse('SELECT size, COUNT(*) WHERE "Type" IN ("story") AND "Owner" = "nonmember"')

      assert_raise_with_message(EasyCharts::InvalidChartMqlException, "nonmember doesn't exist") do
        EasyCharts::ChartMql.from(data_query)
      end
    end
  end

  test 'from_should_raise_exception_when_nested_or_condition_exist' do
    with_three_level_tree_project do
      data_query = CardQuery.parse('SELECT size, COUNT(*) WHERE "Type" IN ("story") AND ("Owner" = "member" OR "size" > 12 )')

      assert_raise_with_message(EasyCharts::InvalidChartMqlException, 'Invalid OR condition') do
        EasyCharts::ChartMql.from(data_query)
      end
    end
  end

  test 'from_should_raise_exception_when_highest_level_condition_is_OR' do
    with_three_level_tree_project do
      data_query = CardQuery.parse('SELECT size, COUNT(*) WHERE "Type" = "Card" OR "Owner" = "admin"')

      assert_raise_with_message(EasyCharts::InvalidChartMqlException, 'Invalid OR condition') do
        EasyCharts::ChartMql.from(data_query)
      end
    end
  end

  test 'from_should_raise_exception_for_multiple_card_types' do
    with_three_level_tree_project do
      data_query = CardQuery.parse('Select Size, count(*) Where Type = "Card" AND Type = "Story" AND Size < 10')

      assert_raise_with_message(EasyCharts::InvalidChartMqlException, 'Multiple card type conditions not supported') do
        EasyCharts::ChartMql.from(data_query)
      end
    end
  end

  test 'from_should_raise_exception_for_invalid_operator_in_card_type_condition' do
    with_three_level_tree_project do
      data_query = CardQuery.parse('Select Size, count(*) Where Type != "Story" AND Size < 10')

      assert_raise_with_message(EasyCharts::InvalidChartMqlException, 'Invalid card type condition') do
        EasyCharts::ChartMql.from(data_query)
      end
    end
  end

  test 'from_should_extract_conditions_from_not_in_clause' do
    data_query = CardQuery.parse("SELECT 'Size', COUNT(*) WHERE 'Type' = 'Story' AND NOT ('Size' IN (2, 3, 5))")

    chart_mql = EasyCharts::ChartMql.from(data_query)
    chart_conditions = chart_mql.conditions

    assert_equal 2, chart_conditions.size
    assert_chart_condition('Type', Operator::Equals, [%w(Story Story)], chart_conditions[0])
    assert_chart_condition('size', Operator::NotEquals, [%w(2 2), %w(3 3), %w(5 5)], chart_conditions[1])
  end

  test 'from_should_raise_exception_when_not_clause_does_not_have_in_condition' do
    data_query = CardQuery.parse("SELECT 'Size', COUNT(*) WHERE 'Type' = 'Story' AND NOT 'Size' = 5")

    assert_raise_with_message(EasyCharts::InvalidChartMqlException, 'Invalid NOT condition') do
      EasyCharts::ChartMql.from(data_query)
    end
  end

  test 'from_should_extract_chart_conditions_from_nested_or_conditions' do
    data_query = CardQuery.parse("SELECT 'Size', COUNT(*) WHERE 'Type' = 'Story' AND ('Size' = null OR 'Size' IN (2,3))")

    chart_mql = EasyCharts::ChartMql.from(data_query)
    chart_conditions = chart_mql.conditions

    assert_equal 2, chart_conditions.size
    assert_chart_condition('Type', Operator::Equals, [%w(Story Story)], chart_conditions[0])
    assert_chart_condition('size', Operator::Equals, [['(not set)', 'null'], %w(2 2), %w(3 3)], chart_conditions[1])
  end

  test 'from_should_raise_exception_for_nested_or_having_conditions_other_than_in_and_is_null' do
    data_query = CardQuery.parse("SELECT 'Size', COUNT(*) WHERE 'Type' = 'Story' AND ('Size' = 6 OR 'Size' IN (2,3))")

    assert_raise_with_message(EasyCharts::InvalidChartMqlException, 'Invalid OR condition') do
      EasyCharts::ChartMql.from(data_query)
    end
  end

  test 'from_should_extract_chart_conditions_with_project_level_variables' do
    size_property = @project.find_property_definition('size')

    @project.project_variables.create!(name: 'large story', data_type: 'NumericType', value: 8, property_definition_ids: [size_property.id])
    data_query = CardQuery.parse("SELECT 'Size', COUNT(*) WHERE 'Type' = 'Story' AND Size = (large story)")

    chart_mql = EasyCharts::ChartMql.from(data_query)
    chart_conditions = chart_mql.conditions

    assert_equal 2, chart_conditions.size
    assert_chart_condition('Type', Operator::Equals, [%w(Story Story)], chart_conditions[0])
    assert_chart_condition('size', Operator::Equals, [['(large story)', '(large story)']], chart_conditions[1])
  end

  test 'from_should_extract_chart_conditions_with_project_level_variables_in_nested_or_clause' do
    size_property = @project.find_property_definition('size')

    @project.project_variables.create!(name: 'large story', data_type: 'NumericType', value: 8, property_definition_ids: [size_property.id])
    @project.project_variables.create!(name: 'small story', data_type: 'NumericType', value: 2, property_definition_ids: [size_property.id])
    data_query = CardQuery.parse("SELECT 'Size', COUNT(*) WHERE 'Type' = 'Story' AND (Size = (large story) OR Size IN (1, 3) OR Size = (small story))")

    chart_mql = EasyCharts::ChartMql.from(data_query)
    chart_conditions = chart_mql.conditions

    assert_equal 2, chart_conditions.size
    assert_chart_condition('Type', Operator::Equals, [%w(Story Story)], chart_conditions[0])
    assert_chart_condition('size', Operator::Equals, [['(large story)', '(large story)'], %w(1 1), %w(3 3), ['(small story)', '(small story)']], chart_conditions[1])
  end

  test 'from_should_extract_chart_conditions_with_card_numbers_as_value' do
    with_three_level_tree_project do
      data_query = CardQuery.parse('Select Size, count(*) Where Type = "Story" AND "Planning iteration" = NUMBER 1')

      chart_mql = EasyCharts::ChartMql.from(data_query)
      chart_conditions = chart_mql.conditions

      assert_equal 2, chart_conditions.size
      assert_chart_condition('Type', Operator::Equals, [%w(Story Story)], chart_conditions[0])
      assert_chart_condition('Planning iteration', Operator::Equals, [['#1 release1', '1']], chart_conditions[1])
    end
  end

  test 'from_should_extract_chart_conditions_with_card_numbers_as_value_within_a_nested_and_clause' do
    with_three_level_tree_project do |project|
      type_release = project.card_types.find_by_name('release')
      planning_release = project.find_property_definition('Planning release')
      release1 = project.cards.find_by_name('release1')
      create_plv!(project, :name => 'current release', :value => release1.id, :card_type => type_release,
                                    :data_type => ProjectVariable::CARD_DATA_TYPE, :property_definition_ids => [planning_release.id])
      data_query = CardQuery.parse('Select Size, count(*) Where Type = "Story" AND "Planning release" = NUMBER 1 AND "Planning release" != NUMBER 2 AND "Planning release" = (current release)')

      chart_mql = EasyCharts::ChartMql.from(data_query)
      chart_conditions = chart_mql.conditions

      assert_equal 4, chart_conditions.size
      assert_chart_condition('Type', Operator::Equals, [%w(Story Story)], chart_conditions[0])
      assert_chart_condition('Planning release', Operator::Equals, [['#1 release1', '1']], chart_conditions[1])
      assert_chart_condition('Planning release', Operator::NotEquals, [['#2 iteration1', '2']], chart_conditions[2])
      assert_chart_condition('Planning release', Operator::Equals, [['(current release)', '(current release)']], chart_conditions[3])
    end
  end

  test 'from_should_extract_chart_conditions_for_query_having_reserverd_keyword_current_user' do

    data_query = CardQuery.parse("SELECT 'Size', COUNT(*) WHERE 'Type' = 'Story' AND 'Owner' = CURRENT USER")
    chart_mql = EasyCharts::ChartMql.from(data_query)
    chart_conditions = chart_mql.conditions

    assert_equal 2, chart_conditions.size
    assert_chart_condition('Type', Operator::Equals, [%w(Story Story)], chart_conditions[0])
    assert_chart_condition('owner', Operator::Equals, [['CURRENT USER', 'CURRENT USER']], chart_conditions[1])
  end

  test 'from_should_extract_chart_conditions_for_query_having_reserved_keyword_today' do
    data_query = CardQuery.parse("SELECT 'Size', COUNT(*) WHERE 'Type' = 'Story' AND 'date_created' = TODAY")
    chart_mql = EasyCharts::ChartMql.from(data_query)
    chart_conditions = chart_mql.conditions

    assert_equal 2, chart_conditions.size
    assert_chart_condition('Type', Operator::Equals, [%w(Story Story)], chart_conditions[0])
    assert_chart_condition('date_created', Operator::Equals, [['TODAY', 'TODAY']], chart_conditions[1])
  end

  test 'from_should_extract_chart_conditions_for_query_having_reserved_keyword_this_card' do
    with_three_level_tree_project do |project|

      data_query = CardQuery.parse("SELECT 'Size', COUNT(*) WHERE 'Type' = 'Story' AND 'Planning release' = THIS CARD")
      chart_mql = EasyCharts::ChartMql.from(data_query)
      chart_conditions = chart_mql.conditions

      assert_equal 2, chart_conditions.size
      assert_chart_condition('Type', Operator::Equals, [%w(Story Story)], chart_conditions[0])
      assert_chart_condition('Planning release', Operator::Equals, [['THIS CARD', 'THIS CARD']], chart_conditions[1])
    end
  end

  test 'from_should_extract_chart_conditions_tags_from query' do
    defect_tag = @project.tags.create!(:name => 'defect', :project_id => @project.identifier, :color => random_color)
    build_tag = @project.tags.create!(:name => 'build', :project_id => @project.identifier, :color => random_color)

    data_query = CardQuery.parse("SELECT 'Size', COUNT(*) WHERE 'Type' = 'Story' AND TAGGED WITH #{defect_tag} AND TAGGED WITH #{build_tag}")
    chart_mql = EasyCharts::ChartMql.from(data_query)
    chart_conditions = chart_mql.conditions
    chart_tags = chart_mql.tags

    assert_equal 1, chart_conditions.size
    assert_chart_condition('Type', Operator::Equals, [%w(Story Story)], chart_conditions[0])
    assert_equal 2, chart_tags.size
    assert_equal(%w(defect build), chart_tags)
  end

  test 'from_should_extract_aggregate_function_from_query' do
    data_query = CardQuery.parse('Select Size, count(*) Where Type = "Card" AND Size < 10')

    chart_mql = EasyCharts::ChartMql.from(data_query)
    chart_aggregate = chart_mql.aggregate

    assert_equal( 'count', chart_aggregate.function)
    assert_equal( nil, chart_aggregate.property)
  end

  test 'from_should_extract_aggregate_property_from_query' do
    data_query = CardQuery.parse('Select Size, AVG(accurate_estimate) Where Type = "Card" AND Size < 10')

    chart_mql = EasyCharts::ChartMql.from(data_query)
    chart_aggregate = chart_mql.aggregate

    assert_equal( 'avg', chart_aggregate.function)
    assert_equal( 'accurate_estimate', chart_aggregate.property)
  end

  test 'from_should_extract_property_from_query' do
    data_query = CardQuery.parse('Select Size, AVG(accurate_estimate) Where Type = "Card" AND Size < 10')

    chart_mql = EasyCharts::ChartMql.from(data_query)

    assert_equal('size', chart_mql.property)
  end

  test 'from_should_raise_error_when_select_clause_is_not_given' do
    data_query = CardQuery.parse('Where Type = "Card" AND Size < 10')

    assert_raise_with_message(EasyCharts::InvalidChartMqlException, 'No SELECT clause given') do
      EasyCharts::ChartMql.from(data_query)
    end
  end

  test 'from_should_raise_error_when_select_clause_is_invalid' do
    data_query = CardQuery.parse('Select Size Where Type = "Card" AND Size < 10')

    assert_raise_with_message(EasyCharts::InvalidChartMqlException, 'Invalid SELECT clause') do
      EasyCharts::ChartMql.from(data_query)
    end
  end

  test 'from_should_raise_error_when_from_clause_specified' do
    with_three_level_tree_project do
      data_query = CardQuery.parse('Select Size, count(*) FROM TREE "three level tree" Where Type = "Card" AND Size < 10')

      assert_raise_with_message(EasyCharts::InvalidChartMqlException, 'FROM clause not supported') do
        EasyCharts::ChartMql.from(data_query)
      end
    end
  end

  test 'from_should_raise_error_when_as_of_clause_specified' do
    data_query = CardQuery.parse('Select Size, count(*) AS OF "Aug 28, 2017" Where Type = "Card" AND Size < 10')

    assert_raise_with_message(EasyCharts::InvalidChartMqlException, 'AS OF clause not supported') do
      EasyCharts::ChartMql.from(data_query)
    end
  end

  test 'from_should_extract_is_null_condition_on_top_level' do
    data_query = CardQuery.parse('Select Size, count(*) Where Type = "Card" AND Size = null')

    chart_conditions = EasyCharts::ChartMql.from(data_query).conditions

    assert_equal 2, chart_conditions.size
    assert_chart_condition('Type', Operator::Equals, [%w(Card Card)], chart_conditions[0])
    assert_chart_condition('size', Operator::Equals, [['(not set)', 'null']], chart_conditions[1])
  end

  test 'from_should_extract_is_not_null_condition_on_top_level' do
    data_query = CardQuery.parse('Select Size, count(*) Where Type = "Card" AND Size != null')

    chart_conditions = EasyCharts::ChartMql.from(data_query).conditions

    assert_equal 2, chart_conditions.size
    assert_chart_condition('Type', Operator::Equals, [%w(Card Card)], chart_conditions[0])
    assert_chart_condition('size', Operator::NotEquals, [['(not set)', 'null']], chart_conditions[1])
  end

  test 'from_should_extract_date_values_in_project_specific_format' do
    data_query = CardQuery.parse('Select Size, count(*) Where Type = "Card" AND date_created != \'07-09-2017\'')

    chart_conditions = EasyCharts::ChartMql.from(data_query).conditions

    assert_equal 2, chart_conditions.size
    assert_chart_condition('Type', Operator::Equals, [%w(Card Card)], chart_conditions[0])
    assert_chart_condition('date_created', Operator::NotEquals, [%w(2017-09-07 07-09-2017)], chart_conditions[1])
  end

  test 'from_should_raise_error_when_greater_than_or_equal_to_operator_is_used' do
    data_query = CardQuery.parse('Select Size, count(*) Where Type = "Card" AND date_created >= \'07-09-2017\'')

    assert_raise_with_message(EasyCharts::InvalidChartMqlException, 'IS GREATER THAN OR EQUALS operator not supported') do
      EasyCharts::ChartMql.from(data_query)
    end
  end

  test 'from_should_raise_error_when_less_than_or_equal_to_operator_is_used' do
    data_query = CardQuery.parse('Select Size, count(*) Where Type = "Card" AND date_created <= \'07-09-2017\'')

    assert_raise_with_message(EasyCharts::InvalidChartMqlException, 'IS LESS THAN OR EQUALS operator not supported') do
      EasyCharts::ChartMql.from(data_query)
    end
  end

  test 'from_should_raise_error_when_composite_query_is_given' do
    data_query = CardQuery.parse('Select Size, count(*) Where Type = "Card" AND accurate_estimate IN (SELECT inaccurate_estimate WHERE size < 10)')

    assert_raise_with_message(EasyCharts::InvalidChartMqlException, 'CardQuery::ImplicitIn condition not supported') do
      EasyCharts::ChartMql.from(data_query)
    end
  end

  test 'from_should_raise_error_when_comparison_with_this_card_property' do
    data_query = CardQuery.parse('Select Size, count(*) Where Type = "Card" AND size = THIS CARD."size"')

    assert_raise_with_message(EasyCharts::InvalidChartMqlException, 'CardQuery::ComparisonWithThisCardProperty condition not supported') do
      EasyCharts::ChartMql.from(data_query)
    end
  end

  test 'from_should_extract_enumerated_property_definition_values_with_same_case_as_in_query' do
    data_query = CardQuery.parse('Select Size, count(*) Where Type = "card" AND feature in ("dashboard", "Applications", "RaTe CaLcUlAtOr")')

    chart_conditions = EasyCharts::ChartMql.from(data_query).conditions

    assert_equal 2, chart_conditions.size
    assert_chart_condition('Type', Operator::Equals, [%w(card card)], chart_conditions[0])
    assert_chart_condition('feature', Operator::Equals, [%w(dashboard dashboard), %w(Applications Applications), ['RaTe CaLcUlAtOr', 'RaTe CaLcUlAtOr']], chart_conditions[1])
  end

  private
  def assert_chart_condition(prop_name, operator, values, condition)
    assert_equal(prop_name, condition.property.name)
    assert_equal operator, condition.operator
    assert_equal(values, condition.values)
  end
end
