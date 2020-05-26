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

class AggregateConditionValidationsTest < ActiveSupport::TestCase
  
  def setup
    login_as_member
  end
  
  def test_today_is_not_supported
    with_first_project do |project|
      assert_equal [CardQuery::AggregateConditionValidations::TODAY_USED], validations("'start date' is TODAY")
    end
  end
  
  def test_current_user_is_not_supported
    with_first_project do |project|
      assert_equal [CardQuery::AggregateConditionValidations::CURRENT_USER_USED], validations("dev is CURRENT USER")
    end
  end
  
  def test_and_combines_validations
    with_first_project do |project|
      assert_equal [CardQuery::AggregateConditionValidations::TODAY_USED, CardQuery::AggregateConditionValidations::CURRENT_USER_USED].sort, validations("'start date' is TODAY and dev is CURRENT USER").sort
    end
  end
  
  def test_or_combines_validations
    with_first_project do |project|
      assert_equal [CardQuery::AggregateConditionValidations::TODAY_USED, CardQuery::AggregateConditionValidations::CURRENT_USER_USED].sort, validations("'start date' is TODAY or dev is CURRENT USER").sort
    end
  end
  
  def test_validations_should_not_be_repeated
    with_first_project do |project|
      assert_equal [CardQuery::AggregateConditionValidations::TODAY_USED], validations("'start date' is TODAY AND 'start date' is TODAY")
    end
  end
  
  def test_from_tree_is_not_supported
    with_three_level_tree_project do |project|
      assert_equal [CardQuery::AggregateConditionValidations::FROM_TREE_USED], validations("FROM TREE 'three level tree'")
    end
  end
  
  def test_this_card_is_not_supported
    with_three_level_tree_project do |project|
      assert_equal [CardQuery::AggregateConditionValidations::THIS_CARD_USED], validations("'related card' = THIS CARD")
    end
  end
  
  def test_this_card_property_is_not_supported
    with_first_project do |project|
      assert_equal [CardQuery::AggregateConditionValidations::THIS_CARD_USED], validations("type = THIS CARD.type")
    end
  end
  
  def test_should_find_this_card_in_explicit_in_clause
    with_first_project do |project|
      assert_equal [CardQuery::AggregateConditionValidations::THIS_CARD_USED], validations("type IN (THIS CARD.type)")
    end
  end
  
  def test_should_find_this_card_in_numbers_in_clause
    with_card_query_project do |project|
      assert_equal [CardQuery::AggregateConditionValidations::THIS_CARD_USED], validations("'related card' NUMBERS IN (this card.number)")
    end
  end
  
  def test_should_find_this_card_in_negations
    with_first_project do |project|
      assert_equal [CardQuery::AggregateConditionValidations::THIS_CARD_USED], validations("NOT type = THIS CARD.type")
    end
  end
  
  private
  def validations(condition)
    query = CardQuery.parse_as_condition_query(condition)
    CardQuery::AggregateConditionValidations.new(query).execute
  end
end
