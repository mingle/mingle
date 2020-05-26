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

require File.expand_path(File.dirname(__FILE__) + '/../simple_test_helper')
require 'mql'

class MqlTest < Test::Unit::TestCase
  include Mql

  def test_parse_blank_string
    assert_nil Mql.parse(nil)
    assert_nil Mql.parse("")
  end

  def test_format_mql_string
    assert_equal 'SELECT name', Mql.format("SELECT name")
    assert_equal nil, Mql.format(nil)
    assert_equal nil, Mql.format('')
  end

  def test_select_simple_column
    assert_equal 'SELECT name', Mql.format("SELECT name")
  end

  def test_select_list_of_columns
    assert_equal "SELECT property1, property2, property3", Mql.format("SELECT property1, property2, property3")
  end

  def test_select_list_with_aggregate_columns
    assert_equal 'SELECT SUM(estimate)', Mql.format("SELECT SuM(estimate)")
    assert_equal 'SELECT MIN(estimate)', Mql.format("SELECT MiN(estimate)")
    assert_equal 'SELECT MAX(estimate)', Mql.format("SELECT MaX(estimate)")
    assert_equal 'SELECT AVERAGE(estimate)', Mql.format("SELECT AvErAgE(estimate)")
    assert_equal 'SELECT COUNT(estimate)', Mql.format("SELECT CoUnT(estimate)")
    assert_equal 'SELECT COUNT(*)', Mql.format("SELECT CoUnT(*)")
    assert_equal 'SELECT property1, SUM(estimate)', Mql.format("SELECT property1, SUM(estimate)")
  end

  def test_select_distinct
    assert_equal 'SELECT DISTINCT property1, SUM(estimate)', Mql.format("SELECT disTINCT property1, SUM(estimate)")
  end

  def test_select_with_where
    assert_equal "SELECT property1 WHERE property1 > 1", Mql.format("SELECT property1 WHERE property1 > '1'")
  end

  def test_order_by_properties
    assert_equal 'ORDER BY property1, property2, property3', Mql.format("ORDER BY property1,property2,property3")
  end

  def test_order_by_properties_with_direction
    assert_equal 'ORDER BY property1 desc', Mql.format("ORDER BY property1 desc")
    assert_equal 'ORDER BY property1 desc, property2 asc, property3', Mql.format("ORDER BY property1 desc, property2 asc, property3")
  end

  def test_group_by_properties
    assert_equal "GROUP BY property1, property2, property3", Mql.format("group by property1, property2, property3")
  end

  def test_where_condition
    assert_equal 'WHERE property1 = high', Mql.format("WHERE property1 = 'high'")
  end

  def test_property_comparison
    assert_equal 'WHERE property1 = PROPERTY property2', Mql.format("WHERE property1 = PROPERTY property2")
  end

  def test_where_with_various_operators
    assert_equal 'WHERE property1 > high', Mql.format("WHERE property1 > 'high'")
    assert_equal 'WHERE property1 < high', Mql.format("WHERE property1 < 'high'")
    assert_equal 'WHERE property1 = high', Mql.format("WHERE property1 = 'high'")
    assert_equal 'WHERE property1 != high', Mql.format("WHERE property1 != 'high'")
    assert_equal 'WHERE property1 >= high', Mql.format("WHERE property1 >= 'high'")
    assert_equal 'WHERE property1 <= high', Mql.format("WHERE property1 <= 'high'")
  end

  def test_where_with_numeric_values
    assert_equal 'WHERE property1 = 1', Mql.format("WHERE property1 = 1")
  end

  def test_where_with_simple_AND
    assert_equal 'WHERE (property1 = high AND property2 = high)', Mql.format("WHERE property1 = 'high' AND property2 = 'high'")
  end

  def test_where_with_simple_OR
    assert_equal 'WHERE (property1 = high OR property2 = high)', Mql.format("WHERE property1 = 'high' OR property2 = 'high'")
  end

  def test_where_with_braces
    assert_equal 'WHERE property1 = high', Mql.format("WHERE (property1 = 'high')")
    assert_equal 'WHERE property1 = high', Mql.format("WHERE ((property1 = 'high'))")
    assert_equal 'WHERE property1 = high', Mql.format("WHERE ( (property1 = 'high') )")

    expected = "WHERE ((risk = high AND status != new) OR (risk = low OR number = 1))"
    assert_equal expected, Mql.format("WHERE (risk = high AND status != new) OR (risk = low OR number = 1)")
  end

  def test_where_with_current_user
    assert_equal 'WHERE owner = CURRENT USER', Mql.format("WHERE owner = CurrEnt USEr")
  end

  def test_where_with_today
    assert_equal 'WHERE "modified on" = ToDaY' , Mql.format("WHERE 'modified on' = ToDaY")
  end

  def test_where_with_date
    assert_equal 'WHERE "modified on" = 2011-08-16' , Mql.format("WHERE 'modified on' = '2011-08-16'")
  end

  def test_property_keyword
    assert_equal 'SELECT property1', Mql.format("SELECT PROPERTY 'property1'")
    assert_equal 'SELECT property', Mql.format("SELECT PROPERTY property")
    assert_equal 'WHERE property1 = high', Mql.format("WHERE PROPERTY 'property1' = 'high'")
  end

  def test_where_with_this_card
    assert_equal 'WHERE iteration = THIS CARD', Mql.format("WHERE iteration = this card")
  end

  def test_where_with_this_card_property
    assert_equal 'WHERE iteration = THIS CARD.iteration', Mql.format("WHERE iteration = this card.iteration")
  end

  def test_where_with_tagged_with
    assert_equal 'WHERE TAGGED WITH bug, "feature request", something', Mql.format("WHERE tagged with bug, 'feature request', 'something'")
  end

  def test_where_in_plan
    assert_equal 'WHERE IN PLAN purloin', Mql.format("WHERE IN PLAN 'purloin'")
    assert_equal 'WHERE type = plan', Mql.format("WHERE type is plan")
    assert_equal 'WHERE type != plan', Mql.format("WHERE type is not plan")
  end

  def test_not_condition
    assert_equal 'WHERE NOT status = done', Mql.format("WHERE NOT status = done")
  end

  def test_in_condition
    assert_equal 'WHERE iteration IN ("Iteration 9", "Iteration 10")', Mql.format("WHERE iteration IN ('Iteration 9', 'Iteration 10')")
  end

  def test_nested_in
    assert_equal 'WHERE number IN (SELECT number WHERE status = in development)', Mql.format("WHERE number IN (SELECT number WHERE status = 'in development')")
  end

  def test_numbers_in
    assert_equal 'WHERE "Depend On" NUMBER IN (1)', Mql.format(%Q{WHERE "Depend On" NUMBERS IN (1) })
    assert_equal 'WHERE "Depend On" NUMBER IN (1)', Mql.format(%Q{WHERE "Depend On" NUMBER IN (1) })
  end

  def test_as_of
    assert_equal 'SELECT number AS OF July 12, 2010 WHERE status = open', Mql.format("SELECT number AS OF 'July 12, 2010' WHERE status=open")
  end

  def test_from_trees
    assert_equal "FROM TREE \"Release Planning\", Features", Mql.format("FROM TREE 'Release Planning', Features")
  end

  def test_select_where_number
    assert_equal 'WHERE iteration = NUMBER 2', Mql.format("WHERE iteration = NUMBER 2")
    assert_equal 'WHERE iteration = NUMBER 2', Mql.format("WHERE iteration = NUMBERS 2")
  end

  def test_null
    assert_equal 'WHERE owner = NULL', Mql.format("WHERE owner = NULL")
  end

  def test_parsing_out_project_variable
    assert_equal 'WHERE iteration = (current iteration)', Mql.format("WHERE iteration = (current iteration)")
    assert_equal 'WHERE iteration = (Current Sprint - 3PP DE)', Mql.format("WHERE iteration = (Current Sprint - 3PP DE)")
    assert_equal 'WHERE iteration = (Current Sprint / 3PP DE)', Mql.format("WHERE iteration = (Current Sprint / 3PP DE)")
  end

  def test_parsing_out_project_variable_containing_quote
    assert_equal "WHERE iteration = 'R1511RB\"", Mql.format(%Q{WHERE iteration = 'R1511RB"})
    assert_equal "WHERE iteration = 'R1511RB\"", Mql.format("WHERE iteration = \"'R1511RB\\\"\"")
  end


  def test_is_is_the_same_as_equal_sign
    assert_equal 'WHERE property1 = 1', Mql.format("WHERE property1 IS 1")
  end

  def test_is_not_is_the_same_as_not_equal_sign
    assert_equal 'WHERE property1 != 1', Mql.format("WHERE property1 IS NOT 1")
  end

  def test_not_equal_sign_is_the_same_as_not_equal_sign
    assert_equal 'WHERE property1 != 1', Mql.format("WHERE property1 NOT = 1")
  end

  def test_today
    assert_equal 'WHERE property1 = today', Mql.format("WHERE property1 = today")
  end

  def test_date_value
    assert_equal 'WHERE property1 = 2011-1-22', Mql.format("WHERE property1 = 2011-1-22")
    assert_equal 'WHERE property1 = 2011-01-22', Mql.format("WHERE property1 = 2011-01-22")
    assert_equal 'WHERE property1 = 2011-01-2', Mql.format("WHERE property1 = 2011-01-2")
    assert_equal 'WHERE property1 = 2011-01-02', Mql.format("WHERE property1 = 2011-01-02")
  end

  def test_parse_words_as_one_literal
    assert_equal 'WHERE "pre est" = 1', Mql.format("WHERE pre est = 1")
    assert_equal 'WHERE "pre est" = 1', Mql.format("WHERE pre    est = 1")
    assert_equal 'WHERE "pre est" = ha ha', Mql.format("WHERE pre est = ha ha")
    assert_equal 'WHERE "pre est" IN ("ha ha", "ha ha2")', Mql.format("WHERE pre est in (ha ha, ha ha2)")
    assert_equal 'WHERE TAGGED WITH "pre est"', Mql.format("WHERE TAGGED WITH pre est")
    assert_equal 'WHERE "pre est" IN ("ha ha", "ha ha2")', Mql.format("WHERE pre est in (ha ha, ha ha2)")
    assert_equal 'ORDER BY property1 desc, haha asc', Mql.format("ORDER BY property1 desc, property haha asc")
    assert_equal 'ORDER BY property1 desc, "ha ha" asc', Mql.format("ORDER BY property1 desc, ha ha asc")

    assert_equal 'FROM TREE "pre est"', Mql.format("from tree pre est")
  end
end
