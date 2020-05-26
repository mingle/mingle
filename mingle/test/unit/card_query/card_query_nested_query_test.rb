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

class CardQueryNestedQueryTest < ActiveSupport::TestCase
    include TreeFixtures::PlanningTree
  
  def setup
    @project = card_query_project
    @project.activate
    login_as_admin
  end
  
  def test_support_negation_of_nested_in_condition
    @project.cards.map(&:destroy)
    create_card!(:name => 'card 1', :size => 1, :status => 'New')
    create_card!(:name => 'card 1', :size => 2, :status => 'Closed')
    assert_mql_value '3', "SELECT sum(size) WHERE status in (SELECT status WHERE NOT status IN (done, 'in progress'))"
    assert_mql_value nil, "SELECT sum(size) WHERE status in (SELECT status WHERE status IN (done, 'in progress'))"
  end

  def test_support_nested_in_condition_for_managed_text_properties
    @project.cards.map(&:destroy)
    card1 = create_card!(:name => 'card 1', :size => 1, :status => 'New')
    card2 = create_card!(:name => 'card 2', :size => 2, :status => 'Closed')
    assert_mql_value '2', "SELECT size WHERE status in (SELECT status WHERE number = #{card2.number})"
  end

  def test_should_fetch_cards_when_comparing_to_tree_relationship_properties_to_card_names
    with_three_level_tree_project do |project|
      card1 = project.cards.find_by_card_type_name_and_number('iteration', 3)
      card2 = project.cards.find_by_card_type_name_and_number('iteration', 2)
      
      assert_mql_value '2', "SELECT count(*) WHERE type=Story AND 'planning release' IN (SELECT name WHERE type=Release)"
      assert_mql_value '0', "SELECT count(*) WHERE type=Story AND 'planning iteration' IN (SELECT name WHERE number = #{card1.number})"
      assert_mql_value '2', "SELECT count(*) WHERE type=Story AND 'planning iteration' IN (SELECT name WHERE number = #{card2.number})"
    end
  end

  def test_should_fetch_cards_when_comparing_to_tree_relationship_properties_to_card_number
    with_three_level_tree_project do |project|
      card1 = project.cards.find_by_card_type_name_and_number('iteration', 3)
      card2 = project.cards.find_by_card_type_name_and_number('iteration', 2)

      assert_mql_value '2', "SELECT count(*) WHERE type=Story AND 'planning release' IN (SELECT number WHERE type=Release)"
      assert_mql_value '0', "SELECT count(*) WHERE type=Story AND 'planning iteration' IN (SELECT number WHERE number = #{card1.number})"
      assert_mql_value '2', "SELECT count(*) WHERE type=Story AND 'planning iteration' IN (SELECT number WHERE number = #{card2.number})"
    end
  end

  def test_should_apply_conditions_independently_to_inner_and_outer_mql_statements
    with_three_level_tree_project do |project|
      project.cards.find_by_card_type_name_and_number('iteration', 3).tag_with('brilliant')
      project.cards.find_by_card_type_name_and_number('iteration', 2).tag_with('rubbish')
      project.cards.find_by_card_type_name_and_number('story', 5).tag_with('brilliant')
      project.cards.find_by_card_type_name_and_number('story', 4).tag_with('rubbish')
      
      assert_mql_value '0', "SELECT count(*) WHERE type=Story AND 'planning iteration' IN (SELECT number WHERE TAGGED WITH brilliant)"
      assert_mql_value '2', "SELECT count(*) WHERE type=Story AND 'planning iteration' IN (SELECT number WHERE TAGGED WITH rubbish)"
      assert_mql_value '1', "SELECT count(*) WHERE type=Story AND 'planning iteration' IN (SELECT number WHERE TAGGED WITH rubbish) AND TAGGED WITH rubbish"
    end
  end

  def test_should_treat_card_relationship_properties_the_same_as_tree_relationship_properties
    with_three_level_tree_project do |project|
      related_card = project.find_property_definition('related card')
      story_cards = project.cards.select {|c| c.card_type_name == 'story'}
      related_card.update_card(story_cards.first, story_cards.last)
      story_cards.each(&:save!)
      
      assert_mql_value '1', "SELECT count(*) WHERE type=Story AND 'related card' IN (SELECT number WHERE number = #{story_cards.last.number})"
      assert_mql_value '1', "SELECT count(*) WHERE type=Story AND 'related card' IN (SELECT name WHERE number = #{story_cards.last.number})"
    end
  end

  def test_should_give_error_when_selecting_multiple_columns_in_nested_in_clause
    with_three_level_tree_project do |project|
      assert_raise_message(CardQuery::DomainException,  /Nested MQL statments can only SELECT one property./){
        evaluate("SELECT count(*) WHERE type=Story AND 'related card' IN (SELECT number, name)")
      }
    end
  end

  def test_should_give_error_when_comparing_relationship_properties_to_anything_other_than_number_name_or_relationship_properties
    with_three_level_tree_project do |project|
      assert_raise_message(CardQuery::DomainException,  /Nested MQL statments can only SELECT name or number properties\./){
        evaluate("SELECT count(*) WHERE type=Story AND 'related card' IN (SELECT owner)")
      }
    end
  end

  def test_should_give_error_when_using_as_of_in_nested_in_clause
    assert_raise_message(CardQuery::DomainException,  /AS OF is not allowed in a nested IN clause\./){
      evaluate "SELECT count(*) WHERE type=Story AND status IN (SELECT status AS OF '2010-09-08')"
    }
  end
  
  def test_should_give_error_when_using_group_by_in_nested_in_clause
    assert_raise_message(CardQuery::DomainException,  /GROUP BY is not allowed in a nested IN clause\./){
      evaluate "SELECT count(*) WHERE type=Story AND status IN (SELECT status GROUP BY Number)"
    }
  end
  
  def test_should_give_error_when_using_order_by_in_nested_in_clause
    assert_raise_message(CardQuery::DomainException,  /ORDER BY is not allowed in a nested IN clause\./){
      evaluate "SELECT count(*) WHERE type=Story AND status IN (SELECT status ORDER BY Number)"
    }
  end
  
  def assert_mql_value(expected, query_string)
    assert_equal expected, evaluate(query_string)
  end
  
  def evaluate(query_string)
    CardQuery.parse(query_string).single_value
  end
end
