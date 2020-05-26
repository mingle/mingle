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

class CardQueryParsingTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  
  def setup
    @project = card_query_project
    @project.activate
    login_as_member
    @card = @project.cards.find_by_number(1)
  end
    
  def test_should_raise
    assert_raise CardQuery::Column::PropertyNotExistError do
      CardQuery.parse("prop_not_exists = story").to_s
    end
  end

  def test_can_parse_empty_expression
    assert_equal "", CardQuery.parse("").to_s
  end
  
  def test_can_parse_equals
    assert_equal "old_type is story", CardQuery.parse("old_type = story").to_s
  end  

  def test_can_recreate_column_selection_mql
    assert_regerenated_mql "SELECT Name", "SELECT name"
  end  
  
  def test_can_recreate_aggregate_function_mql
    assert_regerenated_mql "SELECT SUM(Number)", "SELECT SUM(number)"
  end  
  
  def test_can_recreate_equality_mql
    assert_regerenated_mql "old_type = story", "old_type = story"
  end  
  
  def test_can_parse_greater_than
    assert_equal "Iteration is greater than 2", CardQuery.parse("iteration > 2").to_s
  end  
  
  def test_can_recreate_greater_than
    assert_regerenated_mql "Iteration > '2.0'", "iteration > 2.0"
  end  
  
  def test_can_recreate_greater_than_or_equals
    assert_regerenated_mql "Iteration >= '2.0'", "iteration >= 2.0"
  end  
  
  def test_mql_for_relationship_properties
    with_three_level_tree_project do |project|
      assert_regerenated_mql "'Planning release' = release1", "'planning release' ='release1'"
      release_1 = project.cards.find_by_name('release1')
      assert_regerenated_mql "'Planning release' = NUMBER #{release_1.number}", "'planning release' = NUMBER #{release_1.number}"
    end  
  end  
  
  def test_can_parse_greater_than_with_a_decimal_value
    assert_equal "Iteration is greater than 2.0", CardQuery.parse("iteration > 2.0").to_s
  end  
  
  def test_can_parse_less_than
    assert_equal "Iteration is less than 2", CardQuery.parse("iteration < 2").to_s
  end  
  
  def test_can_recreate_less_than
    assert_regerenated_mql "Iteration < '2.0'", "iteration < 2.0"
  end  
  
  def test_can_recreate_less_than_or_equals
    assert_regerenated_mql "Iteration <= '2.0'", "iteration <= 2.0"
  end  
  
  def test_can_parse_less_than_or_equals
    assert_equal "Iteration is less than or equals 2", CardQuery.parse("iteration <= 2").to_s
  end  
  
  def test_can_parse_greater_than_or_equals
    assert_equal "Iteration is greater than or equals 2", CardQuery.parse("iteration >= 2").to_s
  end  
  
  def test_can_parse_ands_and_nots
    assert_equal "((old_type is story AND Release is 1) AND Priority is not low)",
      CardQuery.parse("old_type = story and release = 1 and not priority = low").to_s
  end
  
  def test_can_recreate_ands_and_nots
    assert_regerenated_mql "old_type = story AND Release = 1 AND NOT Priority = low", "old_type = story and release = 1 and not priority = low"
  end
  
  def test_can_parse_ands_nots_and_ors
    assert_equal "((old_type is story AND Release is 1) AND NOT (Priority is low OR Priority is medium))",
      CardQuery.parse("old_type = story and release = 1 and not (priority = low or priority = medium)").to_s
  end
  
  def test_can_recreate_ands_nots_and_ors
    assert_regerenated_mql "old_type = story AND Release = 1 AND NOT ((Priority = low) OR (Priority = medium))", "old_type = story and release = 1 and not (priority = low or priority = medium)"
  end
  
  def test_can_parse_tagged_with
    assert_equal "TAGGED WITH 'card attributes'", 
      CardQuery.parse("tagged with 'card attributes'").to_s
    assert_equal "(TAGGED WITH 'card attributes' OR TAGGED WITH 'needs refinement')", 
      CardQuery.parse("tagged with 'card attributes' or tagged with 'needs refinement'").to_s
    assert_equal "((old_type is story AND TAGGED WITH 'card attributes') AND NOT TAGGED WITH 'needs refinement')", 
      CardQuery.parse("old_type = story and tagged with 'card attributes' and not tagged with 'needs refinement'").to_s
  end
  
  def test_tagged_with_can_not_use_today_keyword
    assert_raise_message(CardQuery::DomainException, /parse error on value "today" \(TODAY\)/) do
      CardQuery.parse("tagged with today")
    end
  end
  
  def test_tagged_with_can_not_use_current_user_keyword
    assert_raise_message(CardQuery::DomainException, /parse error on value "current user" \(CURRENT_USER\)/) do
      CardQuery.parse("tagged with current user")
    end
  end
  
  def test_tagged_with_cannot_use_this_card_keyword
    assert_raise_message(CardQuery::DomainException, /parse error on value "this card" \(THIS_CARD\)/) do
      CardQuery.parse("tagged with this card")
    end
  end

  def test_can_parse_not_equal
    assert_equal "Status is not open", CardQuery.parse("NOT Status=open").to_s
  end
  
  def test_can_parse_not_and
    assert_equal "(Status is not open AND Iteration is not 1)", CardQuery.parse("NOT (Status=open and Iteration=1)").to_s
  end
  
  def test_can_convert_tagged_with_query_into_condition
    tag1 = @project.tags.create!(:name => 'this tag does exist')
    tag2 = @project.tags.create!(:name => 'another one')
    
    card_query_project_cards = ActiveRecord::Base.connection.quote_table_name("card_query_project_cards")
    assert_equal "#{card_query_project_cards}.id IN (SELECT taggable_id FROM taggings WHERE tag_id = #{tag1.id} AND taggable_type = 'Card')", 
      CardQuery.parse("tagged with 'this tag does exist'").to_conditions
    assert_equal "(#{card_query_project_cards}.id IN (SELECT taggable_id FROM taggings WHERE tag_id = #{tag1.id} AND taggable_type = 'Card') AND " +
                 "#{card_query_project_cards}.id IN (SELECT taggable_id FROM taggings WHERE tag_id = #{tag2.id} AND taggable_type = 'Card'))", 
      CardQuery.parse("tagged with 'this tag does exist' and tagged with 'another one'").to_conditions
  end
  
  def test_can_find_cards
    assert_equal [@card.name], CardQuery.parse("select name where tagged with 'tag1' and tagged with 'tag2'").single_values
    assert_equal [@card.name], CardQuery.parse("select name where release = 1").single_values
    assert_equal [@card.name], CardQuery.parse("select name where release = 1 and old_type = story").single_values
    assert_equal [@card.name], CardQuery.parse("select name where release = 1 and old_type = STORY").single_values
    assert_equal [], CardQuery.parse("select name where release = 1 and not old_type = story").single_values
    assert_equal [@card.name], CardQuery.parse("select name where release = 1 and tagged with tag2").single_values
    assert_equal [@card.name], CardQuery.parse("select name where tagged with 'TAG1' and tagged with 'TAG2'").single_values
  end
  
  def test_can_parse_complex_query_with_select_group_by_and_where
    q = CardQuery.parse %{
      SELECT 'Came Into Scope on Iteration', SUM(Size)
      WHERE Status = Open AND NOT 'Came Into Scope on Iteration' = 1
      GROUP BY 'Came Into Scope on Iteration'
    }
    assert_equal_ignoring_spaces %{
      SELECT 'Came Into Scope on Iteration', SUM(Size)
      WHERE (Status is Open AND 'Came Into Scope on Iteration' is not 1)
      GROUP BY 'Came Into Scope on Iteration'
      ORDER BY 'Came Into Scope on Iteration'
    }, q.to_s
  end

  def test_should_cast_columns_of_numeric_properties_to_numbers_when_used_anywhere_in_mql
    card_query_project_cards = "card_query_project_cards"
    
    assert_equal "CAST(cp_size.value AS DECIMAL(38, 2))", CardQuery.parse("SELECT Size, COUNT(*)").columns.first.to_sql(:cast_numeric_columns => true).gsub(/["']/, '')
    assert_equal "CAST(#{card_query_project_cards}.cp_numeric_free_text AS DECIMAL(38, 2))", CardQuery.parse("SELECT numeric_free_text, COUNT(*)").columns.first.to_sql(:cast_numeric_columns => true).gsub(/["']/, '')
  end  
  
  def test_can_find_null_and_not_null
    @project.connection.delete('DELETE FROM card_query_project_cards')
    create_card!(:name => 'Null Card', :feature => nil)
    create_card!(:name => 'Not Null Card', :feature => 'Applications')
    assert_equal ['Null Card'], CardQuery.parse('SELECT Name WHERE Feature IS NULL').single_values
    assert_equal ['Not Null Card'], CardQuery.parse('SELECT Name WHERE Feature IS NOT NULL').single_values
  end
  
  def test_other_syntax_for_is_and_is_not_null
    @project.cards.each(&:destroy)
    create_card!(:name => 'card 1', :status => nil)
    create_card!(:name => 'card 2', :status => nil)
    create_card!(:name => 'card 3', :status => 'Closed')
    assert_equal '1', CardQuery.parse("SELECT count(*) WHERE Status Is NOT NULL").single_value
    assert_equal '1', CardQuery.parse("SELECT count(*) WHERE NOT Status Is NULL").single_value
    assert_equal '1', CardQuery.parse("SELECT count(*) WHERE NOT Status = NULL").single_value
    assert_equal '1', CardQuery.parse("SELECT count(*) WHERE Status NOT = NULL").single_value
    assert_equal '1', CardQuery.parse("SELECT count(*) WHERE Status != NULL").single_value
    assert_equal '2', CardQuery.parse("SELECT count(*) WHERE Status IS NULL").single_value
    assert_equal '2', CardQuery.parse("SELECT count(*) WHERE Status = NULL").single_value
  end
  
  def test_alternative_syntax_for_not_equals
    assert_equal 'Status is not Open', CardQuery.parse('Status != Open').to_s
  end
  
  def test_can_use_today_in_where_clause
    @project.cards.each(&:destroy)
    create_card!(:name => 'card 0', :date_created => nil)
    create_card!(:name => 'card 1', :date_created => '2007-01-01')
    create_card!(:name => 'card 2', :date_created => '2007-01-02')
    assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE date_created = '2007-01-01'").single_value
    Clock.now_is(:year => 2007, :month => 5, :day => 5) do
      assert_equal "0", CardQuery.parse("SELECT COUNT(*) WHERE date_created IS TODAY").single_value
      assert_equal "3", CardQuery.parse("SELECT COUNT(*) WHERE date_created IS NOT TODAY").single_value
      assert_equal "0", CardQuery.parse("SELECT COUNT(*) WHERE date_created = TODAY").single_value
      assert_equal "3", CardQuery.parse("SELECT COUNT(*) WHERE date_created != TODAY").single_value
    end
    Clock.now_is(:year => 2007, :month => 1, :day => 1) do
      assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE date_created IS TODAY").single_value
      assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE date_created IS NOT TODAY").single_value
      assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE date_created = TODAY").single_value
      assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE date_created != TODAY").single_value
    end
  end
  
  def test_can_recreate_is_today_conditions
    assert_regerenated_mql "date_created IS TODAY", "date_created IS TODAY"
    assert_regerenated_mql "date_created IS NOT TODAY", "date_created IS NOT TODAY"
    assert_regerenated_mql "date_created > TODAY", "date_created > TODAY"
  end
  
  def test_handles_decimals_and_numbers
    @project.find_property_definition('Size').update_card(@card, '1.5')
    @card.save!
    CardQuery.parse("SELECT SUM(Size)")
    @project.find_property_definition('Size').update_card(@card, '1')
    @card.save!
    CardQuery.parse("SELECT SUM(Size)")
  end
  
  def test_can_use_hidden_properties
    @project.find_property_definition('status').update_attribute(:hidden, true)
    @project.reload
    assert_equal "Status is CLOSED", CardQuery.parse("'Status' = 'CLOSED'").to_s
  end
  
  def test_can_handle_quotes_everywhere
    assert_equal "Status is CLOSED", CardQuery.parse("'Status' = 'CLOSED'").to_s
  end
  
  def test_can_handle_quoting_needs_in_IN_clauses
    assert_regerenated_mql "Status IN ('in progress', closed)", "Status IN ('in progress', 'closed')"
  end
  
  def test_can_regenerate_is_current_user_mql
    assert_regerenated_mql "owner IS CURRENT USER", "owner IS CURRENT USER"
  end  
  
  def test_can_regenerate_mql_for_group_by_clauses
    assert_regerenated_mql "SELECT Status GROUP BY Status", "SELECT Status GROUP BY Status"
  end  
  
  def test_can_regenerate_mql_for_order_by_clauses
    assert_regerenated_mql "SELECT Number ORDER BY Status", "SELECT Number ORDER BY Status"
  end  
  
  def test_can_parse_card_relationship_property_in_select_clause
    assert_regerenated_mql "SELECT 'related card'", "SELECT 'related card'"
  end
  
  def test_can_parse_this_card
    assert_equal "'related card' is THIS CARD", CardQuery.parse("'related card' = THIS CARD", :content_provider => @card).to_s
  end
  
  def test_can_parse_when_a_plv_is_called_this_card
    rel_card = @project.find_property_definition('related card')
    some_card_type = rel_card.card_types.first
    some_card = @project.cards.first
    plv = create_plv!(@project, :name => 'THIS CARD', :data_type => ProjectVariable::CARD_DATA_TYPE, :property_definition_ids => [rel_card.id], :value => some_card.id)
    assert_equal "'related card' is 'Card[id: #{some_card.id}]'", CardQuery.parse("'related card' = (THIS CARD)", :content_provider => @card).to_s
    assert_equal "'related card' is 'Card[id: #{some_card.id}]'", CardQuery.parse("'related card' = ( THIS CARD )", :content_provider => @card).to_s
  end
  
  def test_should_raise_exception_if_comparing_number_with_a_non_card_column
    assert_raise_message(CardQuery::DomainException, /only card relationship properties or tree relationship properties can be used in 'column = NUMBER ...' clause/) do
      CardQuery.parse("SELECT number, COUNT(*) WHERE type = NUMBER 9")
    end
  end
  
  def test_should_give_error_when_comparing_non_relationship_property_to_number
    with_three_level_tree_project do |project|
      assert_raise_message(CardQuery::DomainException, /#{'9nine'.bold} is not a valid value for #{'Planning release'.bold}. Only numbers can be used as values in a 'column = NUMBER ...' clause/) do
        CardQuery.parse("'Planning release' = NUMBER '9nine'")
      end  
    end  
  end  
  
  def test_should_parse_an_in_clause_with_number_identical_to_a_numbers_keyword
    with_three_level_tree_project do |project|
      assert_regerenated_mql "'Planning release' NUMBER IN (8, 9)", "'Planning release' NUMBER IN (8, 9)"
    end  
  end  
  
  def test_should_continue_to_parse_number_alone_as_an_rvalue
    with_three_level_tree_project do |project|
      CardQuery.parse("'Planning release' = Number")
      assert_regerenated_mql "'Planning release' = PROPERTY Number", "'Planning release' = Number"
    end  
  end  
  
  def test_should_raise_exception_if_comparing_this_card_with_a_non_card_column
    assert_raise_message(CardQuery::DomainException, /only card relationship properties or tree relationship properties can be used in 'column = THIS CARD' clause/) do
      CardQuery.parse("SELECT number, COUNT(*) WHERE type = THIS CARD")
    end
  end
  
  def test_should_parse_from_when_the_condition_is_from_tree
    with_three_level_tree_project do |project|
      query = CardQuery.parse("FROM TREE 'three level tree'")
      assert query.from.is_a?(CardQuery::Tree)
    end
  end
  
  # bug 6981
  def test_can_parse_query_which_uses_the_word_issue
    assert_equal "Type is issue", CardQuery.parse("type = issue", :content_provider => @card).to_s
  end
  
  def assert_regerenated_mql(expected, original)
    assert_equal expected, CardQuery::MqlGeneration.new(CardQuery.parse(original)).execute
  end  
end
