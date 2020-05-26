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

# Tags: card_activity
class CardQueryAgainstCardVersionTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  
  def setup
    @project = card_query_project
    @project.activate
    @member = login_as_member
  end
  
  def teardown
    Clock.reset_fake
  end
  
  def test_card_version_query_does_not_support_from_tree_clause 
    with_three_level_tree_project do
      assert_raise(CardQuery::DomainException) do
        CardQuery.parse("FROM TREE 'three level tree'").to_card_version_sql
      end
    end
  end
  
  def test_card_version_query_does_not_support_tagged_with_clause
    assert_raise(CardQuery::DomainException) do
      CardQuery.parse("TAGGED WITH tag1").to_card_version_sql
    end
  end
  
  def test_card_version_query_does_not_support_tagged_with_clause
    assert_raise(CardQuery::DomainException) do
      CardQuery.parse("TAGGED WITH tag1").to_card_version_sql
    end
  end
  
  def test_card_version_query_does_not_support_aggregate_property
    with_three_level_tree_project do |project|
      assert_raise(CardQuery::DomainException) do
        CardQuery.parse("'Sum of size' > 5 and 'Sum of size' < 9 ").to_card_version_sql
      end      
    end
  end
  
  
  def test_should_match_all_versions_if_query_not_contains_condition
    assert_equal @project.cards.collect(&:versions).flatten.collect(&:id).sort, card_version_values_from_query("")
  end
  
  def test_get_card_version_ids_for_query_using_text_enumerated_property
    card1 = create_card!(:name => 'Card 1', :iteration => '2')
    card1.update_attributes(:cp_iteration => '1')
    card1.update_attributes(:cp_iteration => '2')
    card2 = create_card!(:name => 'Card 2', :iteration => '2')
    card2.update_attributes(:cp_iteration => '3')
    card_not_in_list = create_card!(:name => 'Card 3', :iteration => '1')
    
    assert_equal [card1.versions.second.id], card_version_values_from_query("iteration = 1 and number in (#{card1.number}, #{card2.number})")
    
    assert_equal [card1.versions.first.id, card1.versions.third.id, card2.versions.first.id, card2.versions.second.id].sort, 
                 card_version_values_from_query("iteration > 1 and number in (#{card1.number}, #{card2.number})")
  end
  
  def test_get_card_numbers_for_version_matching_critial
    card1 = create_card!(:name => 'Card 1', :iteration => '2')
    card1.update_attributes(:cp_iteration => '1')
    card1.update_attributes(:cp_iteration => '2')
    card2 = create_card!(:name => 'Card 2', :iteration => '2')
    card2.update_attributes(:cp_iteration => '3')
    card_not_in_list = create_card!(:name => 'Card 3', :iteration => '1')
    
    assert_equal [card1.number, card2.number].sort, 
                 card_version_values_from_query("select distinct number where iteration > 1 and number in (#{card1.number}, #{card2.number})")
    
    assert_equal [card1.number, card1.number, card2.number, card2.number].sort, 
                card_version_values_from_query("select number where iteration > 1 and number in (#{card1.number}, #{card2.number})")
    
  end
  
  def test_get_card_version_ids_for_query_using_numberic_enumerated_property
    card = create_card!(:name => 'Card 1', :size => 2)
    card.update_attributes(:cp_size => 3)
    
    assert_equal [card.versions.second.id].sort, card_version_values_from_query("size > 2 and number in (#{card.number})")
  end
  
  
  def test_get_card_version_ids_for_card_query_using_user_property
    card = create_card!(:name => 'card for user', :owner => @member.id)
    card.update_attributes(:cp_owner_user_id => nil)
    card.update_attributes(:cp_owner_user_id => @member.id)
    card.update_attributes(:cp_owner_user_id => nil)
    assert_equal [card.versions.first.id, card.versions.third.id].sort, card_version_values_from_query("owner = member and number in (#{card.number})")
  end
  
  def test_get_card_version_ids_for_card_query_using_date_property
    card = create_card!(:name => 'time to go home', :date_created => Time.parse('2010-11-15'))
    assert_equal [card.versions.first.id], card_version_values_from_query("date_created > '2010-11-14' and number in (#{card.number})")
    assert_equal [], card_version_values_from_query("date_created < '2010-11-15' and number in (#{card.number})")
  end
  
  def test_get_card_version_ids_for_card_query_using_card_type_property
    card = create_card!(:name => 'time to go home')
    assert_equal [card.versions.first.id], card_version_values_from_query("type = Card and number in (#{card.number})")
  end
  
  def test_get_card_version_ids_from_card_query_using_nested_in_query
    card1 = create_card!(:name => 'Card 1', :iteration => '2', :size => 5)
    card1.update_attributes(:cp_iteration => '1')
    card1.update_attributes(:cp_iteration => '2')
    card2 = create_card!(:name => 'Card 2', :iteration => '2', :size => 5)
    card2.update_attributes(:cp_iteration => '3')
    card2.update_attributes(:cp_size => 3)

    assert_equal [card1.number.to_s], CardQuery.parse("select number where number IN (SELECT number WHERE SIZE = 5)").single_values
    assert_equal [card1.versions.first.id, card1.versions.last.id], card_version_values_from_query("iteration = 2 AND number IN (SELECT number WHERE SIZE = 5) ")
  end
  
  def test_get_card_version_ids_from_card_query_using_card_property
    first_card = @project.cards.first
    card = create_card!(:name => 'card')
    card.update_attribute(:cp_related_card_card_id, first_card.id)
    assert_equal [card.versions.second.id], card_version_values_from_query("'related card' = '#{first_card.name}' and number in (#{card.number})")
  end
  
  def test_get_card_version_ids_from_card_query_using_card_plv
    first_card = @project.cards.first
    related_card_property = @project.find_property_definition("related card")
    create_plv!(@project, :name => 'first card', 
                          :data_type => ProjectVariable::CARD_DATA_TYPE,
                          :value => first_card.id,
                          :property_definition_ids => [related_card_property.id])
    card = create_card!(:name => 'Card 1')
    card.update_attributes(:cp_related_card_card_id => first_card.id)
    card.update_attributes(:cp_related_card_card_id => nil)
    assert_equal [card.versions.second.id], card_version_values_from_query("'related card' = (first card) and number in (#{card.number})")
  end
  
  
  private
  
  def card_version_values_from_query(query)
    values = SqlHelper.select_values(CardQuery.parse(query).to_card_version_sql)
    values.collect(&:to_i).sort
  end

end
