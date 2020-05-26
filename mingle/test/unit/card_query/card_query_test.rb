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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class CardQueryTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  def setup
    @project = card_query_project
    @project.activate
    @member = login_as_member
    @card = @project.cards.find_by_number(1)
  end

  def teardown
    Clock.reset_fake
  end

  def test_limit_query_values
    create_card!(:name => 'Blah', :iteration => '1', :size => '5')
    create_card!(:name => 'Blah', :iteration => '2', :size => '4')
    create_card!(:name => 'Blah', :iteration => '2', :size => '3')
    assert_equal 2, CardQuery.parse("select number").values(2).size
  end

  def test_good_error_message_when_duplicate_select_column
    begin
      CardQuery.parse('SELECT Name, Name')
    rescue => e
      assert_equal 'Duplicate columns in SELECT clause are illegal', e.message
      return
    end
    fail 'parse should have failed.'
  end

  def test_can_size_up_each_iteration
   create_card!(:name => 'Blah', :iteration => '1', :size => '5')
   create_card!(:name => 'Blah', :iteration => '2', :size => '4')
   create_card!(:name => 'Blah', :iteration => '2', :size => '3')
   create_card!(:name => 'Blah', :iteration => '3', :size => '2')
    coords = CardQuery.parse("SELECT Iteration, SUM(Size) GROUP BY Iteration").values_as_coords
    assert_equal({nil => 0, '1' => 5, '2' => 7, '3' => 2}, coords)
  end


  def test_group_by_with_and_condition
    create_card!(:name => 'Blah', :iteration => '1', :size => '5')
    create_card!(:name => 'Blah', :iteration => '2', :size => '4')
    create_card!(:name => 'Blah', :iteration => '2', :size => '3')
    create_card!(:name => 'Blah', :iteration => '3', :size => '2')
    values = CardQuery.parse("SELECT SUM(Size) WHERE iteration>'1' AND iteration < '3' GROUP BY Iteration").single_values
    assert_equal(["7"], values)
  end

  def test_automatically_adds_group_by_and_order_by_if_unspecified
    assert_equal_ignoring_spaces 'SELECT Feature, SUM(Size) GROUP BY Feature ORDER BY Feature',
      CardQuery.parse('SELECT Feature, SUM(Size)').to_s
  end

  def test_can_parse_order_by
    assert_equal 'Feature', CardQuery.parse("SELECT Feature, SUM(Size) GROUP BY Feature ORDER BY Feature").order_by.first.name
    assert_equal 'Feature', CardQuery.parse("SELECT Feature, SUM(Size) ORDER BY Feature").order_by.first.name
  end

  def test_can_restrict_with_additional_conditions
    q = CardQuery.parse('SELECT Feature, SUM(Size) GROUP BY Feature ORDER BY Feature')
    assert_equal_ignoring_spaces 'SELECT Feature, SUM(Size) WHERE Status is Closed GROUP BY Feature ORDER BY Feature',
      q.restrict_with('Status = Closed').to_s
    assert_equal_ignoring_spaces 'SELECT Feature, SUM(Size) GROUP BY Feature ORDER BY Feature', q.to_s
    q = CardQuery.parse('SELECT Feature, SUM(Size) WHERE old_type = Story GROUP BY Feature ORDER BY Feature')
    assert_equal_ignoring_spaces 'SELECT Feature, SUM(Size) WHERE (old_type is Story AND Status is Closed) GROUP BY Feature ORDER BY Feature',
      q.restrict_with('Status = Closed').to_s
    assert_equal_ignoring_spaces 'SELECT Feature, SUM(Size) WHERE old_type is Story GROUP BY Feature ORDER BY Feature',
      q.to_s

    assert_equal_ignoring_spaces 'SELECT Feature, SUM(Size) WHERE (old_type is Story AND size is greater than 20) GROUP BY Feature ORDER BY Feature',
      q.restrict_with(CardQuery.parse('size > 20').conditions).to_s
  end

  def test_can_nonexistant_tags_are_handled_correctly
    assert_equal '1', CardQuery.parse('select count(*) where TAGGED WITH tag1 OR TAGGED WITH nonexistant').single_value
    assert_equal '0', CardQuery.parse('select count(*) where TAGGED WITH tag1 AND TAGGED WITH nonexistant').single_value
  end

  def test_can_parse_distinct
    card_query_project_cards = ActiveRecord::Base.connection.quote_table_name('card_query_project_cards')
    q = CardQuery.parse('SELECT DISTINCT Feature')
    assert_equal_ignoring_spaces 'SELECT DISTINCT Feature', q.to_s
    assert_equal_ignoring_spaces %{
      SELECT DISTINCT #{quote_column_name('cp_feature')}.#{quote_column_name('value')}
                AS #{quote_value('Feature')}
      FROM #{card_query_project_cards}
        LEFT OUTER JOIN enumeration_values #{quote_column_name("cp_feature")} ON lower(#{quote_column_name("cp_feature")}.value) = lower(#{card_query_project_cards}.#{quote_column_name('cp_feature')})
        AND #{quote_column_name("cp_feature")}.property_definition_id = #{@project.find_property_definition('feature').id}
    }, q.to_sql
  end

  def test_uses_sort_defined_in_property_definition
    @project.connection.delete('DELETE FROM card_query_project_cards')

    # define a counter-intuitive order
    @project.find_enumeration_value('iteration', '3').update_attributes(:position => '1', :nature_reorder_disabled => true)
    @project.find_enumeration_value('iteration', '1').update_attributes(:position => '2', :nature_reorder_disabled => true)
    @project.find_enumeration_value('iteration', '2').update_attributes(:position => '3',:nature_reorder_disabled => true)

    # create cards in a counter-intuitive order
    create_card!(:name => 'Card 2', :iteration => '2')
    create_card!(:name => 'Card 1', :iteration => '1')
    create_card!(:name => 'Card 3', :iteration => '3')
    create_card!(:name => 'Card 4', :iteration => '3')

    # ensure order is correct
    assert_equal ['3', '1', '2'], @project.find_property_definition('iteration').enumeration_values[0..2].collect(&:value)

    # TODO still not sorting on number desc
    assert_equal ['Card 4', 'Card 3', 'Card 1', 'Card 2'], CardQuery.parse('SELECT Name ORDER BY Iteration').single_values
  end

  def test_can_count_stuff
   @project.connection.delete('DELETE FROM card_query_project_cards')
   create_card!(:name => 'Card 2', :feature => 'Dashboard')
   create_card!(:name => 'Card 1', :feature => 'Dashboard')
   create_card!(:name => 'Card 3', :feature => 'Applications')

   assert_equal({'Dashboard' => 2, 'Applications' => 1}, CardQuery.parse('SELECT Feature, COUNT(*)').values_as_coords)
  end

  def test_can_select_distinct_property_and_order_by_it_too
    @project.connection.delete('DELETE FROM card_query_project_cards')
    create_card!(:name => 'Card 2', :feature => 'Dashboard')
    create_card!(:name => 'Card 1', :feature => 'Dashboard')
    create_card!(:name => 'Card 3', :feature => 'Applications')

    query = CardQuery.parse("SELECT DISTINCT Feature ORDER BY Feature")
    assert_equal ['Dashboard', 'Applications'], query.single_values
  end

  def test_can_convert_to_card_list_view_with_loss_of_information
    view = CardQuery.parse('SELECT Name WHERE Feature = Dashboard AND Status = New AND TAGGED WITH Tag1 ORDER BY Feature').as_card_list_view
    assert_equal("Feature = Dashboard AND Status = New AND TAGGED WITH Tag1", view.to_params[:filters][:mql])

    assert_equal_ignoring_case 'Feature', view.to_params[:sort]
    assert_equal_ignoring_case 'ASC', view.to_params[:order]

    view = CardQuery.parse('SELECT Name').restrict_with('Feature = Dashboard').as_card_list_view
    assert_equal('Feature = Dashboard', view.to_params[:filters][:mql])

    view = CardQuery.parse('SELECT Name WHERE Feature IS NOT NULL AND Status = New').as_card_list_view
    assert_equal('Feature IS NOT NULL AND Status = New', view.to_params[:filters][:mql])

    view = CardQuery.parse("'In Scope' = Yes").as_card_list_view
    assert_equal("'In scope' = Yes", view.to_params[:filters][:mql])

    view = CardQuery.parse('SELECT Name WHERE Feature = Dashboard OR Status = New').as_card_list_view
    assert_equal '((Feature = Dashboard) OR (Status = New))', view.to_params[:filters][:mql]
  end

  def test_can_convert_to_card_list_view_when_not_is_used
    assert_equal "Iteration IS NOT NULL", CardQuery.parse('Iteration IS NOT NULL').as_card_list_view.to_params[:filters][:mql]
    assert_equal 'Iteration IS NOT NULL', CardQuery.parse('NOT Iteration IS NULL').as_card_list_view.to_params[:filters][:mql]
  end

  def test_can_convert_to_card_list_view_when_in_is_used
    assert_equal "Status IN (Open, New)", CardQuery.parse("Status in ('Open', 'New')").as_card_list_view.to_params[:filters][:mql]
  end

  def test_can_select_distinct_and_order_by
    @project.connection.delete('DELETE FROM card_query_project_cards')
    create_card!(:name => 'Card 1', :feature => 'Dashboard')
    create_card!(:name => 'Card 2', :feature => 'Applications')

    assert_equal ['Dashboard', 'Applications'], CardQuery.parse('SELECT DISTINCT Feature ORDER BY Feature').single_values
  end

  def test_can_order_by_built_in_properties
    @project.connection.delete('DELETE FROM card_query_project_cards')
    create_card!(:name => 'Card 1', :iteration => '1')
    create_card!(:name => 'Card 2', :iteration => '2')
    create_card!(:name => 'Card 3', :iteration => '3')

    assert_equal ['Card 1', 'Card 2', 'Card 3'], CardQuery.parse('SELECT Name ORDER BY Name').single_values
  end

  def test_can_handle_in_clause
    @project.connection.delete('DELETE FROM card_query_project_cards')
   create_card!(:name => 'Card 1', :iteration => '1')
   create_card!(:name => 'Card 2', :iteration => '2')
   create_card!(:name => 'Card 3', :iteration => '3')

    assert_equal ['Card 1', 'Card 2'],
      CardQuery.parse('SELECT Name WHERE Iteration IN (1, 2) ORDER BY Iteration').single_values
  end

  def test_good_error_message_when_duplicate_order_by_column
    begin
      CardQuery.parse('SELECT Name ORDER BY Name, Iteration, Name')
    rescue => e
      assert_equal 'Duplicate columns in ORDER BY clause are illegal', e.message
      return
    end
    fail 'parse should have failed.'
  end

  def test_good_error_message_when_duplicate_group_by_column
    begin
      CardQuery.parse('SELECT Name GROUP BY Name, Iteration, Name')
    rescue => e
      assert_equal 'Duplicate columns in GROUP BY clause are illegal', e.message
      return
    end
    fail 'parse should have failed.'
  end

  def test_can_use_very_long_property_name
    CardQuery.parse("SELECT 'Analysis Done in Iteration', SUM(Size)")
  end

  def test_can_select_user_property
    assert_equal ['member@email.com (member)'], CardQuery.parse("SELECT 'Assigned To'").single_values
  end

  def test_can_use_user_in_where_clause
    assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE 'Assigned To' = member").single_value
    assert_equal "0", CardQuery.parse("SELECT COUNT(*) WHERE 'Assigned To' IS NULL").single_value
    assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE 'Assigned To' IS NOT NULL AND 'Assigned To' = member").single_value
    assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE 'Assigned To' IS CURRENT USER").single_value
    assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE 'Assigned To' = CURRENT USER").single_value
    assert_equal "0", CardQuery.parse("SELECT COUNT(*) WHERE 'Assigned To' IS NOT CURRENT USER").single_value
    assert_equal "0", CardQuery.parse("SELECT COUNT(*) WHERE 'Assigned To' != CURRENT USER").single_value
    assert_equal "member@email.com (member)", CardQuery.parse("SELECT 'Assigned To' WHERE 'Assigned To' = member").single_value
  end

  def test_current_user_can_not_select_any_card_when_login_as_anonymous
    logout_as_nil
    assert_equal "0", CardQuery.parse("SELECT COUNT(*) WHERE 'Assigned To' IS CURRENT USER").single_value
    assert_equal @project.cards.count.to_s, CardQuery.parse("SELECT COUNT(*) WHERE 'Assigned To' IS NOT CURRENT USER").single_value
  end

  def test_good_error_message_when_compare_today_with_numeric_property
    ['Size', 'numeric_free_text'].each do |column|
      begin
        CardQuery.parse("SELECT Name WHERE  #{column}= today")
        fail "numeric check should have failed for #{column}."
      rescue => e
        assert_equal "Comparing numeric property #{column.bold} with today is not supported", e.message
      end
    end
  end

  def test_support_in_condition_with_user_property
    @project.cards.each(&:destroy)
    create_card!(:name => 'card 1', :owner => User.find_by_login('member').id)
    create_card!(:name => 'card 1', :owner => User.find_by_login('proj_admin').id)
    assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE owner in (member, proj_admin)").single_value
  end

  def test_support_in_condition_with_enum_property
    @project.cards.each(&:destroy)
    create_card!(:name => 'card 1', :size => 1, :status => 'New')
    create_card!(:name => 'card 1', :size => 2, :status => 'Closed')
    assert_equal '3', CardQuery.parse("SELECT sum(size) WHERE status in (new, closed)").single_value
  end

  def test_support_using_same_enum_property_multiple_times_in_condition
    @project.cards.each(&:destroy)
    create_card!(:name => 'card 1', :size => 1, :status => 'New')
    create_card!(:name => 'card 1', :size => 2, :status => 'Closed')
    assert_equal '1', CardQuery.parse("SELECT count(*) WHERE (size > 1 or size < 2) and size = 2").single_value
  end

  def test_support_using_same_enum_property_in_condition_and_order_by_and_group_by
    @project.cards.each(&:destroy)
    create_card!(:name => 'card 1', :size => 1, :status => 'New')
    create_card!(:name => 'card 2', :size => 1, :status => 'New')
    create_card!(:name => 'card 3', :size => 2, :status => 'Closed')
    assert_equal ['1', '2'], CardQuery.parse("SELECT size WHERE size >= 1 group by size order by size").single_values
  end

  def test_support_using_null_condition_with_same_enum_property_as_select_column
    @project.cards.each(&:destroy)
    create_card!(:name => 'card 1', :status => nil)
    create_card!(:name => 'card 2', :status => nil)
    create_card!(:name => 'card 3', :status => 'Closed')
    assert_equal 'Closed', CardQuery.parse("SELECT status WHERE not status = NULL").single_value
  end

  def test_support_compare_operations_using_today_in_where_clause
    @project.cards.each(&:destroy)
    create_card!(:name => 'card 1', :date_created => '2007-01-01')
    create_card!(:name => 'card 2', :date_created => '2007-01-02')
    create_card!(:name => 'card 3', :date_created => '2007-01-03')
    create_card!(:name => 'card 4', :date_created => '2007-01-04')
    Clock.now_is(:year => 2007, :month => 1, :day => 2) do
      assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE date_created < TODAY").single_value
      assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE date_created > TODAY").single_value
      assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE date_created <= TODAY").single_value
      assert_equal "3", CardQuery.parse("SELECT COUNT(*) WHERE date_created >= TODAY").single_value
    end
  end

  def test_consistent_usage_of_today
    operators = ['=', '!=', 'IS', 'IS NOT']
    invalid_usages_of_today = ["'TODAY'", "(TODAY)", "('TODAY')", "'(TODAY)'"]
    operators.each do |operator|
      assert_raise CardQuery::MqlValidationError do
        CardQuery.parse("SELECT COUNT(*) WHERE date_created #{operator} 'TODAY'").single_value
      end
      assert_raise CardQuery::MqlValidationError do
        CardQuery.parse("SELECT COUNT(*) WHERE date_created #{operator} '(TODAY)'").single_value
      end
      assert_raise CardQuery::PLV::InvalidNameError do
        CardQuery.parse("SELECT COUNT(*) WHERE date_created #{operator} (TODAY)").single_value
      end
      assert_raise CardQuery::PLV::InvalidNameError do
        CardQuery.parse("SELECT COUNT(*) WHERE date_created #{operator} ('TODAY')").single_value
      end
    end
  end

  def test_consistent_usage_of_current_user
    operators = ['=', '!=', 'IS', 'IS NOT']
    operators.each do |operator|
      assert_raise CardQuery::MqlValidationError do
        CardQuery.parse("SELECT COUNT(*) WHERE owner #{operator} 'CURRENT USER'").single_value
      end
      assert_raise CardQuery::MqlValidationError do
        CardQuery.parse("SELECT COUNT(*) WHERE owner #{operator} '(CURRENT USER)'").single_value
      end
      assert_raise CardQuery::PLV::InvalidNameError do
        CardQuery.parse("SELECT COUNT(*) WHERE owner #{operator} ('CURRENT USER')").single_value
      end
      assert_raise CardQuery::PLV::InvalidNameError do
        CardQuery.parse("SELECT COUNT(*) WHERE owner #{operator} (CURRENT USER)").single_value
      end
    end
  end

  def test_support_compare_operations_in_where_clause_for_numeric_free_text_property
    @project.cards.each(&:destroy)
    create_card!(:name => 'card 1', :numeric_free_text => 1)
    create_card!(:name => 'card 2', :numeric_free_text => 2)
    create_card!(:name => 'card 3', :numeric_free_text => 2)
    create_card!(:name => 'card 4', :numeric_free_text => 11)
    assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE numeric_free_text = 2").single_value
    assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE numeric_free_text < 2").single_value
    assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE numeric_free_text > 2").single_value
    assert_equal "3", CardQuery.parse("SELECT COUNT(*) WHERE numeric_free_text <= 2").single_value
    assert_equal "3", CardQuery.parse("SELECT COUNT(*) WHERE numeric_free_text >= 2").single_value
  end

  def test_should_raise_error_when_comparing_numeric_free_text_to_non_numeric_data
    assert_raise (CardQuery::DomainException) { CardQuery.parse("SELECT COUNT(*) WHERE numeric_free_text < something").single_value }
  end

  def test_should_allow_null_as_comparison_with_numeric_free_text_properties
    @project.cards.each(&:destroy)
    create_card!(:name => 'card 1', :numeric_free_text => nil)
    create_card!(:name => 'card 2', :numeric_free_text => 2)
    assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE numeric_free_text IS NULL").single_value
    assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE numeric_free_text IS NOT NULL").single_value
  end

  def test_should_allow_null_as_comparison_with_numeric_enumerated_properties
    @project.cards.each(&:destroy)
    create_card!(:name => 'card 1', :size => nil)
    create_card!(:name => 'card 2', :size => 2)
    assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE size IS NULL").single_value
    assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE size IS NOT NULL").single_value
  end

  def test_should_allow_null_as_comparison_with_non_numeric_enumerated_properties
    @project.cards.each(&:destroy)
    create_card!(:name => 'card 1', :iteration => nil)
    create_card!(:name => 'card 2', :iteration => 2)
    assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE iteration IS NULL").single_value
    assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE iteration IS NOT NULL").single_value
  end

  def test_support_compare_operations_in_where_clause_with_enum_property_position
    @project.cards.each(&:destroy)
    @project.find_property_definition('Status').reorder(['New', 'In Progress', 'Done', 'Closed']) {|enum| enum.value}
    create_card!(:name => 'card 1', :status => 'New')
    create_card!(:name => 'card 2', :status => 'Closed')
    create_card!(:name => 'card 3', :status => 'Done')
    create_card!(:name => 'card 4', :status => 'Closed')

    assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE status = Closed").single_value
    assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE status < Done").single_value
    assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE status > Done").single_value
    assert_equal "4", CardQuery.parse("SELECT COUNT(*) WHERE status <= Closed").single_value
    assert_equal "3", CardQuery.parse("SELECT COUNT(*) WHERE status >= Done").single_value
  end

  def test_should_show_errors_if_try_to_compare_enumeration_value_with_not_exists_value
    @project.find_property_definition('Status').reorder(['New', 'In Progress', 'Done', 'Closed']) {|enum| enum.value}
    begin
      CardQuery.parse("SELECT COUNT(*) WHERE status < something").single_value
      fail('should failed card query parse')
    rescue  => e
      assert_equal "#{'something'.bold} is not a valid value for #{'Status'.bold}, which is restricted to #{'New'.bold}, #{'In Progress'.bold}, #{'Done'.bold}, and #{'Closed'.bold}", e.message
    end
  end

  def test_should_allow_numeric_free_text_to_be_aggregated
    assert CardQuery.parse("SELECT SUM(numeric_free_text)")
  end

  def test_should_not_allow_non_numeric_free_text_to_be_aggregated
    assert_raise(CardQuery::DomainException) do
      CardQuery.parse("SELECT SUM(freetext1)")
    end
  end

  def test_should_only_allow_star_aggregate_expression_with_count
    CardQuery.parse('SELECT COUNT(*)')
    CardQuery.parse('SELECT  CoUnT ( * ) ')
    assert_raise(CardQuery::DomainException) do CardQuery.parse("SELECT AVG(*)") end
    assert_raise(CardQuery::DomainException) do CardQuery.parse("SELECT MAX(*)") end
    assert_raise(CardQuery::DomainException) do CardQuery.parse("SELECT MIN(*)") end
    assert_raise(CardQuery::DomainException) do CardQuery.parse("SELECT SUM(*)") end
  end

  def test_should_only_allow_recognized_aggregates
    CardQuery.parse('SELECT AVG(numeric_free_text)')
    CardQuery.parse('SELECT COUNT(numeric_free_text)')
    CardQuery.parse('SELECT MAX(numeric_free_text)')
    CardQuery.parse('SELECT MIN(numeric_free_text)')
    CardQuery.parse('SELECT SUM(numeric_free_text)')
    assert_raise(CardQuery::DomainException) do CardQuery.parse("SELECT TIMMY(numeric_free_text)") end
  end

  def test_can_use_modified_by_and_created_by
    assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE 'Created by' = member").single_value
  end

  def test_good_error_message_for_aggregation_none_numeric_property_defintion
    @project.find_property_definition('Status').update_card(@card, '#REF!')
    @card.save!
    begin
      CardQuery.parse("SELECT SUM(Status)")
    rescue => e
      assert_equal "Property #{'Status'.bold} is not numeric, only numeric properties can be aggregated.",e.message
      return
    end
    fail 'parse should have failed.'
  end

  def test_good_error_message_for_non_numeric_properties
    begin
      CardQuery.parse("SELECT SUM(Estimate)")
    rescue => e
      assert_equal "Property #{'Estimate'.bold} is not numeric, only numeric properties can be aggregated.",e.message
      return
    end
    fail 'parse should have failed.'
  end

  def test_can_be_cached
    assert CardQuery.parse("Priority = High").can_be_cached?
    assert CardQuery.parse("Priority = High AND Status = Closed").can_be_cached?
    assert CardQuery.parse("Priority = High OR Status = Closed").can_be_cached?
    assert CardQuery.parse("Priority = High AND NOT Status = Closed").can_be_cached?
    assert !CardQuery.parse("Owner IS CURRENT USER").can_be_cached?
    assert !CardQuery.parse("Owner IS CURRENT USER AND Status = Closed").can_be_cached?
    assert !CardQuery.parse("Owner IS NOT CURRENT USER AND Status = Closed").can_be_cached?
  end

  def test_should_out_date_value_with_project_format_if_column_is_date_property
    create_card!(:name => 'Blah #1', :size => '1', :date_created => '2007-01-02')
    query = CardQuery.parse("SELECT date_created, size WHERE Name = 'Blah #1'")
    @project.update_attributes(:date_format => Date::DAY_MONTH_YEAR)
    assert_equal "02/01/2007",  query.single_value
    assert_equal ["02/01/2007"],  query.single_values
    assert_equal [["02/01/2007", 1]],  query.values_as_pairs
    assert_equal({"02/01/2007" => 1},  query.values_as_coords)
  end

  def test_order_by_name_should_be_case_insensitive
    @project.cards.destroy_all
    create_card!(:name => 'aaa', :number => 1)
    create_card!(:name => 'AAA', :number => 2)
    create_card!(:name => 'zzz', :number => 3)
    create_card!(:name => 'ZZZ', :number => 4)

    query = CardQuery.parse("ORDER BY name")
    assert_equal ['AAA', 'aaa', 'ZZZ', 'zzz'], query.find_cards.collect(&:name)
    # note, result isn't [1, 2, 3, 4] because an additional number DESC order by clause is added behind the scenes.
    expected_card_number_order = [2, 1, 4, 3]
    assert_equal expected_card_number_order, query.find_card_numbers
    assert_equal expected_card_number_order, query.values.collect { |row| row['number'].to_i }
  end

  def test_order_by_enumerated_properties_should_be_in_position_order
    @project.cards.destroy_all

    create_card!(:name => 'Card 1', :number => 1, :iteration => '1', :feature => 'Dashboard')
    create_card!(:name => 'Card 2', :number => 2, :iteration => '1', :feature => 'Applications')
    create_card!(:name => 'Card 4', :number => 4, :iteration => '2', :feature => 'Applications')
    create_card!(:name => 'Card 3', :number => 3, :iteration => '2', :feature => 'Dashboard')

    query = CardQuery.parse("ORDER BY iteration, feature")
    expected_card_number_order = (1..4).to_a
    assert_equal expected_card_number_order, query.find_cards.collect(&:number)
    assert_equal expected_card_number_order, query.find_card_numbers
    assert_equal expected_card_number_order, query.values.collect { |row| row['number'].to_i }
  end

  def test_find_cards_order_by_enumerated_properties_nulls_should_come_last
    @project.cards.destroy_all

    create_card!(:name => 'Card 1', :number => 1, :iteration => '1', :feature => 'Applications')
    create_card!(:name => 'Card 5', :number => 5, :feature => 'Applications')
    create_card!(:name => 'Card 3', :number => 3, :iteration => '2', :feature => 'Applications')
    create_card!(:name => 'Card 2', :number => 2, :iteration => '1')
    create_card!(:name => 'Card 4', :number => 4, :iteration => '2')

    query = CardQuery.parse("ORDER BY iteration, feature")
    expected_card_number_order = (1..5).to_a
    assert_equal expected_card_number_order, query.find_cards.collect(&:number)
    assert_equal expected_card_number_order, query.find_card_numbers
    assert_equal expected_card_number_order, query.values.collect { |row| row['number'].to_i }
  end

  def test_find_cards_should_be_able_to_order_by_non_enumerated_numbers
    @project.cards.destroy_all

    create_card!(:name => 'Card 1', :number => 1, :numeric_free_text => '1')
    create_card!(:name => 'Card 2', :number => 2, :numeric_free_text => '2')
    create_card!(:name => 'Card 4', :number => 4, :numeric_free_text => '10')
    create_card!(:name => 'Card 3', :number => 3, :numeric_free_text => '3')

    query = CardQuery.parse("ORDER BY numeric_free_text")
    expected_card_number_order = (1..4).to_a
    assert_equal expected_card_number_order, query.find_cards.collect(&:number)
    assert_equal expected_card_number_order, query.find_card_numbers
    assert_equal expected_card_number_order, query.values.collect { |row| row['number'].to_i }
  end

  def test_order_with_specified_value
    create_card!(:name => 'name1', :iteration => '1', :size => '5')
    create_card!(:name => 'NAME2', :iteration => '2', :size => '4')
    create_card!(:name => 'name3', :iteration => '2', :size => '3')

    order_by = [CardQuery::Column.new('name', 'desc')]
    assert_equal ['name3', 'NAME2', 'name1', "for card query test"], CardQuery.new(:order_by => order_by).find_cards.collect(&:name)

    order_by = [CardQuery::Column.new('name', 'asc')]
    assert_equal ["for card query test", 'name1', 'NAME2', 'name3'], CardQuery.new(:order_by => order_by).find_cards.collect(&:name)
  end

  def test_support_compare_operations_between_two_numeric_free_text_property
    create_project.with_active_project do |project|
      setup_numeric_text_property_definition('freetext1')
      setup_numeric_text_property_definition('freetext2')
      create_card!(:name => 'card 1', :freetext1 => 1, :freetext2 => 2)
      create_card!(:name => 'card 2', :freetext1 => 2, :freetext2 => 2)
      create_card!(:name => 'card 3', :freetext1 => 2, :freetext2 => 2)
      create_card!(:name => 'card 4', :freetext1 => 11, :freetext2 => 2)

      assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE freetext1 = PROPERTY freetext2").single_value
      assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE freetext1 < PROPERTY freetext2").single_value
      assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE freetext1 > PROPERTY freetext2").single_value
      assert_equal "3", CardQuery.parse("SELECT COUNT(*) WHERE freetext1 <= PROPERTY freetext2").single_value
      assert_equal "3", CardQuery.parse("SELECT COUNT(*) WHERE freetext1 >= PROPERTY freetext2").single_value
    end
  end

  def test_support_compare_operations_between_two_string_free_text_property
    @project.cards.each(&:destroy)
    create_card!(:name => 'card 1', :freetext1 => "b", :freetext2 => "b")
    create_card!(:name => 'card 2', :freetext1 => "a", :freetext2 => "b")
    create_card!(:name => 'card 3', :freetext1 => "a", :freetext2 => "c")

    assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE freetext1 = PROPERTY freetext2").single_value
    assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE freetext1 != PROPERTY freetext2").single_value

    assert_raise CardQuery::DomainException do CardQuery.parse("SELECT COUNT(*) WHERE freetext1 < PROPERTY freetext2").single_value end
    assert_raise CardQuery::DomainException do CardQuery.parse("SELECT COUNT(*) WHERE freetext1 > PROPERTY freetext2").single_value end
    assert_raise CardQuery::DomainException do CardQuery.parse("SELECT COUNT(*) WHERE freetext1 <= PROPERTY freetext2").single_value end
    assert_raise CardQuery::DomainException do CardQuery.parse("SELECT COUNT(*) WHERE freetext1 >= PROPERTY freetext2").single_value end
  end

  def test_should_raise_error_when_compare_ordinal_operations_between_two_enumerated_text_property
    create_project.with_active_project do |project|
      setup_property_definitions 'status' => ['open', 'in-progress', 'close']
      setup_property_definitions 'status-b' => ['open', 'in-progress', 'close']

      create_card!(:name => 'card 1', :status => 'open', :'status-b' => 'close')
      create_card!(:name => 'card 2', :status => 'open', :'status-b' => 'open')
      create_card!(:name => 'card 3', :status => 'open', :'status-b' => 'in-progress')
      create_card!(:name => 'card 4', :status => 'close', :'status-b' => 'close')

      assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE status = PROPERTY status-b").single_value
      assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE status != PROPERTY status-b").single_value

      assert_raise CardQuery::DomainException do
        CardQuery.parse("SELECT COUNT(*) WHERE status < PROPERTY status-b").single_value
      end

      assert_raise CardQuery::DomainException do
        CardQuery.parse("SELECT COUNT(*) WHERE status > PROPERTY status-b").single_value
      end

      assert_raise CardQuery::DomainException do
        CardQuery.parse("SELECT COUNT(*) WHERE status >= PROPERTY status-b").single_value
      end

      assert_raise CardQuery::DomainException do
        CardQuery.parse("SELECT COUNT(*) WHERE status <= PROPERTY status-b").single_value
      end

    end
  end

  def test_support_compare_operations_between_two_numeric_enum_property
    create_project.with_active_project do |project|
      setup_numeric_property_definition 'size', [1, 2, 4, 11]
      setup_numeric_property_definition 'dev_size', [1, 2, 4, 8]
      create_card!(:name => 'card 1', :size => 1, :dev_size => 2)
      create_card!(:name => 'card 2', :size => 2, :dev_size => 2)
      create_card!(:name => 'card 3', :size => 2, :dev_size => 2)
      create_card!(:name => 'card 4', :size => 11, :dev_size => 2)

      assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE size = PROPERTY dev_size").single_value
      assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE size < PROPERTY dev_size").single_value
      assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE size > PROPERTY dev_size").single_value
      assert_equal "3", CardQuery.parse("SELECT COUNT(*) WHERE size <= PROPERTY dev_size").single_value
      assert_equal "3", CardQuery.parse("SELECT COUNT(*) WHERE size >= PROPERTY dev_size").single_value
    end
  end

  def test_support_compare_operations_between_numberic_and_formular_property
    create_project.with_active_project do |project|
      setup_numeric_text_property_definition('freetext1')
      setup_numeric_text_property_definition('freetext2')
      setup_formula_property_definition('formula1', 'freetext2 - 1')
      create_card!(:name => 'card 1', :freetext1 => 1, :freetext2 => 2)
      create_card!(:name => 'card 2', :freetext1 => 0, :freetext2 => 2)
      create_card!(:name => 'card 3', :freetext1 => 2, :freetext2 => 2)
      create_card!(:name => 'card 4', :freetext1 => 11, :freetext2 => 2)

      assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE freetext1 = PROPERTY formula1").single_value
      assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE freetext1 < PROPERTY formula1").single_value
      assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE freetext1 > PROPERTY formula1").single_value
      assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE freetext1 <= PROPERTY formula1").single_value
      assert_equal "3", CardQuery.parse("SELECT COUNT(*) WHERE freetext1 >= PROPERTY formula1").single_value

      assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE formula1 = PROPERTY freetext1").single_value
      assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE formula1 < PROPERTY freetext1").single_value
      assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE formula1 > PROPERTY freetext1").single_value
      assert_equal "3", CardQuery.parse("SELECT COUNT(*) WHERE formula1 <= PROPERTY freetext1").single_value
      assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE formula1 >= PROPERTY freetext1").single_value
    end
  end

  def test_support_compare_operations_between_date_and_formular_property
    create_project.with_active_project do |project|
      setup_date_property_definition("signoff_day")
      setup_date_property_definition("release_day")
      setup_formula_property_definition('realrelease_day', 'release_day + 5')

      create_card!(:name => 'card 1', :signoff_day => '2007-01-01', :release_day => '2006-12-28')
      create_card!(:name => 'card 2', :signoff_day => '2007-01-02', :release_day => '2006-12-28')
      create_card!(:name => 'card 3', :signoff_day => '2007-01-02', :release_day => '2006-12-28')
      create_card!(:name => 'card 4', :signoff_day => '2007-01-11', :release_day => '2006-12-28')

      assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE signoff_day = PROPERTY realrelease_day").single_value
      assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE signoff_day < PROPERTY realrelease_day").single_value
      assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE signoff_day > PROPERTY realrelease_day").single_value
      assert_equal "3", CardQuery.parse("SELECT COUNT(*) WHERE signoff_day <= PROPERTY realrelease_day").single_value
      assert_equal "3", CardQuery.parse("SELECT COUNT(*) WHERE signoff_day >= PROPERTY realrelease_day").single_value

      assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE realrelease_day = PROPERTY signoff_day ").single_value
      assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE realrelease_day < PROPERTY signoff_day").single_value
      assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE realrelease_day > PROPERTY signoff_day").single_value
      assert_equal "3", CardQuery.parse("SELECT COUNT(*) WHERE realrelease_day <= PROPERTY signoff_day").single_value
      assert_equal "3", CardQuery.parse("SELECT COUNT(*) WHERE realrelease_day >= PROPERTY signoff_day").single_value

    end
  end

  def test_support_compare_operations_between_two_date_property
    create_project.with_active_project do |project|
      setup_date_property_definition("signoff_day")
      setup_date_property_definition("release_day")

      create_card!(:name => 'card 1', :signoff_day => '2007-01-01', :release_day => '2007-01-02')
      create_card!(:name => 'card 2', :signoff_day => '2007-01-02', :release_day => '2007-01-02')
      create_card!(:name => 'card 3', :signoff_day => '2007-01-02', :release_day => '2007-01-02')
      create_card!(:name => 'card 4', :signoff_day => '2007-01-11', :release_day => '2007-01-02')

      assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE signoff_day = PROPERTY release_day").single_value
      assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE signoff_day < PROPERTY release_day").single_value
      assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE signoff_day > PROPERTY release_day").single_value
      assert_equal "3", CardQuery.parse("SELECT COUNT(*) WHERE signoff_day <= PROPERTY release_day").single_value
      assert_equal "3", CardQuery.parse("SELECT COUNT(*) WHERE signoff_day >= PROPERTY release_day").single_value
    end
  end

  def test_should_give_clear_message_when_comparing_two_date_properties
    create_project.with_active_project do |project|
      setup_date_property_definition("signoff_day")
      setup_date_property_definition("release_day")
      assert_raise CardQuery::DomainException do
        CardQuery.parse("SELECT COUNT(*) WHERE signoff_day = release_day").single_value
      end
    end
  end

  def test_should_give_clear_message_when_comparing_two_numeric_properties
    create_project.with_active_project do |project|
      setup_numeric_property_definition 'size', [1, 2, 4, 11]
      setup_numeric_property_definition 'dev_size', [1, 2, 4, 8]
      assert_raise CardQuery::DomainException do
        CardQuery.parse("SELECT COUNT(*) WHERE size = dev_size").single_value
      end
    end
  end

  def test_comparison_between_properties_should_work_with_property_named_property
    create_project.with_active_project do |project|
      setup_numeric_property_definition 'size', [1, 2, 4, 11]
      setup_numeric_property_definition 'property', [1, 2, 4, 8]
      create_card!(:name => 'card 1', :size => 1, :property => 2)
      create_card!(:name => 'card 2', :size => 2, :property => 2)
      create_card!(:name => 'card 3', :size => 2, :property => 2)
      create_card!(:name => 'card 4', :size => 11, :property => 2)

      assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE size = PROPERTY property").single_value
      assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE size < PROPERTY property").single_value
      assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE size > PROPERTY property").single_value
      assert_equal "3", CardQuery.parse("SELECT COUNT(*) WHERE size <= PROPERTY property").single_value
      assert_equal "3", CardQuery.parse("SELECT COUNT(*) WHERE size >= PROPERTY property").single_value
    end
  end

  def test_comparison_between_properties_should_work_with_card_type
    create_project.with_active_project do |project|
      setup_property_definitions :my_type => ["Card", "story"]
      create_card!(:name => 'card 1', :my_type => 'Card')
      create_card!(:name => 'card 2', :my_type => 'story')
      create_card!(:name => 'card 3', :my_type => 'story')

      assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE my_type = PROPERTY type").single_value
      assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE PROPERTY type != PROPERTY my_type").single_value

      assert_raise CardQuery::DomainException do CardQuery.parse("SELECT COUNT(*) WHERE PROPERTY type > PROPERTY my_type").single_value end
      assert_raise CardQuery::DomainException do CardQuery.parse("SELECT COUNT(*) WHERE PROPERTY type >= PROPERTY my_type").single_value end
      assert_raise CardQuery::DomainException do CardQuery.parse("SELECT COUNT(*) WHERE PROPERTY type < PROPERTY my_type").single_value end
      assert_raise CardQuery::DomainException do CardQuery.parse("SELECT COUNT(*) WHERE PROPERTY type <= PROPERTY my_type").single_value end
    end
  end

  def test_enum_value_named_property_should_work
    create_project.with_active_project do |project|
      setup_property_definitions :my_type => ["today", "property"], :property => ['today', 'property'], :today => ['today', 'property']
      create_card!(:name => 'card 1', :my_type => "today", :property => 'property', :today => 'property')
      create_card!(:name => 'card 2', :my_type => "property", :property => 'property', :today => 'property')
      create_card!(:name => 'card 3', :my_type => "today", :property => 'property', :today => 'property')
      create_card!(:name => 'card 4', :my_type => "property", :property => 'today', :today => 'property')

      assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE my_type = 'property'").single_value
      assert_equal "1", CardQuery.parse("SELECT COUNT(*) WHERE my_type = PROPERTY property").single_value
      assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE my_type != 'property'").single_value
      assert_equal "3", CardQuery.parse("SELECT COUNT(*) WHERE my_type != PROPERTY property").single_value
      assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE my_type != PROPERTY 'today'").single_value

      assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE my_type = 'today'").single_value
    end
  end

  def test_should_raise_error_when_compare_ordinal_operations_between_two_user_property
    create_project.with_active_project do |project|
      @member = User.find_by_login('member')
      @admin = User.find_by_login('admin')
      project.add_member(@member)
      project.add_member(@admin)

      setup_user_definition :dev
      setup_user_definition :owner

      create_card!(:name => 'card 1', :dev => @member.id, :owner => @admin.id)
      create_card!(:name => 'card 2', :dev => @member.id, :owner => @member.id)
      create_card!(:name => 'card 3', :dev => @admin.id, :owner => @admin.id)
      create_card!(:name => 'card 4', :dev => @admin.id, :owner => @member.id)

      assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE dev = PROPERTY owner").single_value
      assert_equal "2", CardQuery.parse("SELECT COUNT(*) WHERE dev != PROPERTY owner").single_value

      assert_raise CardQuery::DomainException do CardQuery.parse("SELECT COUNT(*) WHERE dev < PROPERTY owner").single_value end
      assert_raise CardQuery::DomainException do CardQuery.parse("SELECT COUNT(*) WHERE dev > PROPERTY owner").single_value end
      assert_raise CardQuery::DomainException do CardQuery.parse("SELECT COUNT(*) WHERE dev <= PROPERTY owner").single_value end
      assert_raise CardQuery::DomainException do CardQuery.parse("SELECT COUNT(*) WHERE dev >= PROPERTY owner").single_value end
    end
  end

  def test_property_keyword_works_for_specifying_property_everywhere
    create_project.with_active_project do |project|
      @member = User.find_by_login('member')
      @admin = User.find_by_login('admin')
      project.add_member(@member)
      project.add_member(@admin)

      setup_user_definition :dev
      setup_user_definition :owner

      card1 = create_card!(:name => 'card 1', :dev => @member.id, :owner => @admin.id)
      card2 = create_card!(:name => 'card 2', :dev => @admin.id, :owner => @admin.id)
      assert_equal "admin@email.com (admin)", CardQuery.parse("SELECT dev WHERE PROPERTY dev = PROPERTY owner").single_value
      assert_equal "admin@email.com (admin)", CardQuery.parse("SELECT PROPERTY dev WHERE PROPERTY dev != member").single_value
      assert_equal [card1], CardQuery.parse("PROPERTY dev != PROPERTY owner").find_cards
    end
  end

  def test_should_support_the_number_keyword_on_comparisons
    with_new_project do |project|
      init_planning_tree_types
      tree = create_planning_tree_with_duplicate_iteration_names
      r2_iteration1 = tree.find_node_by_name('release2').children.detect{ |node| node.name == 'iteration1' }
      query = "select name where 'planning iteration' = number #{r2_iteration1.number}"
      assert_equal ['story3'], CardQuery.parse(query).single_values
    end
  end

  def test_should_show_number_and_name_when_select_tree_property
    with_new_project do |project|
      init_planning_tree_types
      create_three_level_tree
      iteration1 = project.cards.find_by_name('iteration1')
      query = "select 'Planning iteration' where name = story1"
      assert_equal ["##{iteration1.number} iteration1"], CardQuery.parse(query).single_values
    end
  end

  def test_should_join_relationship_properties_on_card_number_rather_than_name_if_the_number_keyword_is_used
    with_three_level_tree_project do |project|
      release_1 = project.cards.find_by_name('release1')
      release_property = project.find_property_definition('planning release')
      mql = CardQuery.parse("SELECT name WHERE 'planning release' = NUMBER #{release_1.number}")
      assert_equal ['iteration1', 'iteration2', 'story1', 'story2'], mql.single_values.sort
    end
  end

  #for bug 2648
  def test_restrict_with_empty_conditions
    card_query_project_cards = ActiveRecord::Base.connection.quote_table_name('card_query_project_cards')
    query = CardQuery.parse("SELECT name WHERE name='for card query test'").restrict_with!("")
    assert_equal [{'Name' => 'for card query test'}], query.values
  end

  def test_enumerated_numbers_should_be_ordered_correctly
    create_project.with_active_project do |project|
      enumerated_values = ['0', '1', '2', '4', '8', '16']
      setup_numeric_property_definition 'estimate', enumerated_values

      create_card!(:name => "card", :estimate => '0')
      create_card!(:name => "card", :estimate => '1')
      create_card!(:name => "card", :estimate => '2')
      create_card!(:name => "card", :estimate => '4')
      create_card!(:name => "card", :estimate => '16')
      create_card!(:name => "card", :estimate => '8')
      create_card!(:name => "card", :estimate => nil)

      expected_values = ['0', '1', '2', '4', '8', '16', nil]
      assert_equal expected_values, CardQuery.parse("SELECT estimate").single_values
      assert_equal expected_values, CardQuery.parse("SELECT DISTINCT estimate").single_values
      assert_equal expected_values, CardQuery.parse("SELECT estimate ORDER BY estimate").single_values
      assert_equal expected_values, CardQuery.parse("SELECT DISTINCT estimate ORDER BY estimate").single_values
      expected_values = expected_values.reverse
      assert_equal expected_values, CardQuery.parse("SELECT estimate ORDER BY estimate DESC").single_values
      assert_equal expected_values, CardQuery.parse("SELECT DISTINCT estimate ORDER BY estimate DESC").single_values
    end
  end

  def test_non_enumerated_numbers_should_be_ordered_correctly
    create_project.with_active_project do |project|
      setup_numeric_text_property_definition 'estimate'

      create_card!(:name => "card", :estimate => '0')
      create_card!(:name => "card", :estimate => '1')
      create_card!(:name => "card", :estimate => '2')
      create_card!(:name => "card", :estimate => '4')
      create_card!(:name => "card", :estimate => '16')
      create_card!(:name => "card", :estimate => '8')
      create_card!(:name => "card", :estimate => nil)

      expected_values = ['0', '1', '2', '4', '8', '16', nil]
      assert_equal expected_values, CardQuery.parse("SELECT estimate").single_values
      assert_equal expected_values, CardQuery.parse("SELECT DISTINCT estimate").single_values
      assert_equal expected_values, CardQuery.parse("SELECT estimate ORDER BY estimate").single_values
      assert_equal expected_values, CardQuery.parse("SELECT DISTINCT estimate ORDER BY estimate").single_values

      expected_values = expected_values.reverse
      assert_equal expected_values.reject(&:blank?), CardQuery.parse("SELECT estimate ORDER BY estimate DESC").single_values.reject(&:blank?)
      assert_equal expected_values.reject(&:blank?), CardQuery.parse("SELECT DISTINCT estimate ORDER BY estimate DESC").single_values.reject(&:blank?)
    end
  end

  def test_should_be_able_to_get_pivot_values
    create_card!(:name => 'card', :priority => 'low', :size => 1, :status => 'Done')
    create_card!(:name => 'card', :priority => 'low', :size => 1, :status => 'Done')
    create_card!(:name => 'card', :priority => 'low', :size => 2, :status => 'Closed')
    create_card!(:name => 'card', :priority => 'low', :size => 2, :status => 'Closed')

    coordinates = CardQuery.parse('SELECT Status, Sum(Size) WHERE Priority = low GROUP BY Status ORDER BY Status ').values_as_coords
    assert_equal 2, coordinates['Done']
    assert_equal 4, coordinates['Closed']
  end

  def test_should_be_able_to_get_pivot_values_when_pivot_column_is_same_as_aggregation_column
    create_card!(:name => 'card', :priority => 'low', :size => 1)
    create_card!(:name => 'card', :priority => 'low', :size => 1)
    create_card!(:name => 'card', :priority => 'low', :size => 2)
    create_card!(:name => 'card', :priority => 'low', :size => 2)

    coordinates = CardQuery.parse('SELECT Size, Sum(Size) WHERE Priority = low GROUP BY Size ORDER BY Size ').values_as_coords
    assert_equal 2, coordinates['1']
    assert_equal 4, coordinates['2']
  end

  def test_and_with_nil_should_be_not_change_condition
    condition = CardQuery::Condition.comparison_between_column_and_value(CardQuery::Column.new('size'), Operator.equals, '1')
    condition_after_and = CardQuery::And.new(condition, nil, nil)
    assert_equal condition.to_sql, condition_after_and.to_sql
  end

  def test_cards_in_a_tree
    create_planning_tree_project do
      create_card!(:name => 'card not in the planning tree')
      assert_equal "8", CardQuery.parse("SELECT COUNT(*) FROM TREE planning").single_value
    end
  end

  def test_should_allow_aggregate_column_to_be_first_column
    query = CardQuery.parse('SELECT SUM(size), feature')
    assert query.values.first.keys.include?('Feature')
  end

  def test_values_works_with_multibyte_properties
    with_multibyte_project do |project|
      values = CardQuery.parse("SELECT '专题', Count(*)").values
      assert_equal 2, values.size
      assert values.any?{|record| record['专题'] == '用户管理' && record['Count'] = '2'}
      assert values.any?{|record| record['专题'] == 'Search' && record['Count'] = '1'}
    end
  end

  def test_values_as_pairs_works_with_multibyte_properties
    with_multibyte_project do |project|
      values_as_pairs = CardQuery.parse("SELECT '专题', Count(*)").values_as_pairs
      assert_equal 2, values_as_pairs.size
      assert values_as_pairs.any?{|pair| pair[0] == '用户管理' && pair[1] = '2'}
      assert values_as_pairs.any?{|pair| pair[0] == 'Search' && pair[1] = '1'}
    end
  end

  def test_values_as_coords_works_with_multibyte_properties
    with_multibyte_project do |project|
      assert_equal({'用户管理' => 2, 'Search' => 1}, CardQuery.parse("SELECT '专题', Count(*)").values_as_coords)
    end
  end

  def test_should_not_produce_any_columns_other_than_number_in_the_resul_set_for_card_numbers_sql
    card_numbers_sql = @project.card_list_views.find_or_construct(@project, :filters => ['[Type][is][Card]'], :columns => 'number,type', :sort => 'number', :order => 'DESC').as_card_query.find_card_numbers_sql
    assert ActiveRecord::Base.connection.select_all(card_numbers_sql).all? { |row| row.keys.size == 1 }
  end

  def test_parsing_asc_and_desc
    @project.cards.each(&:destroy)
    create_card!(:name => 'card 1', :size => 1, :status => 'New')
    create_card!(:name => 'card 2', :size => 1, :status => 'New')
    create_card!(:name => 'card 3', :size => 2, :status => 'Closed')
    assert_equal ['1', '2'], CardQuery.parse("SELECT size WHERE size >= 1 group by size order by size ASC").single_values
    assert_equal ['2', '1'], CardQuery.parse("SELECT size WHERE size >= 1 group by size order by size DESC").single_values
  end

  def test_should_work_with_words_which_are_started_with_keywords
    keywords = [
      "select", 'from', 'where', 'and', 'or', 'not', 'distinct', 'null', 'in', 'today', 'property', 'tree', 'asc', 'desc'
    ]
    prop_def_names = keywords.collect{|key| key + 'appand'}

    with_new_project do |project|
      prop_defs = prop_def_names.inject({}) {|map, key| map[key] = {}; map}
      setup_property_definitions prop_defs

      project.reload

      prop_def_names.each do |name|
        CardQuery.parse("SELECT #{name} WHERE #{name} is not null")
      end
    end
  end

  def test_numeric_property_should_work_for_the_condition_of_in
    create_card!(:name => 'I am card 99', :size => '6.00', :status => 'New')
    assert_equal "I am card 99", CardQuery.parse("SELECT name WHERE size IN (6)").single_values.first
    assert_equal "I am card 99", CardQuery.parse("SELECT name WHERE size IN ('6.0')").single_values.first
    assert_equal "I am card 99", CardQuery.parse("SELECT name WHERE size IN ('6.00')").single_values.first
    assert_equal "I am card 99", CardQuery.parse("SELECT name WHERE size IN ('6.0000')").single_values.first
  end

  def test_numbers_in_condition
    with_new_project do |project|
      init_planning_tree_types
      tree = create_planning_tree_with_duplicate_iteration_names
      r2_iteration1 = tree.find_node_by_name('release2').children.detect{ |node| node.name == 'iteration1' }
      r2_iteration2 = tree.find_node_by_name('release2').children.detect{ |node| node.name == 'iteration2' }
      query = "SELECT name WHERE 'planning iteration' NUMBERS IN (#{r2_iteration1.number}, #{r2_iteration2.number})"
      assert_equal ['story3', 'story4', 'story5'].sort, CardQuery.parse(query).single_values.sort
    end
  end

  def test_number_comparision_only_support_card_property_definition
    assert_raise(CardQuery::DomainException) { CardQuery.parse("size NUMBERS IN (1, 2)") }
    assert_raise(CardQuery::DomainException) { CardQuery.parse("size = NUMBER 25")}
  end

  def test_should_raise_nicer_message_when_not_enough_columns_for_values_as_pairs
    assert_raise CardQuery::DomainException do
      CardQuery.parse("SELECT name").values_as_pairs
    end
  end

  def test_aggregate_function_should_be_numeric
    assert CardQuery.parse("SELECT COUNT(*)").columns.first.numeric?
    assert CardQuery.parse("SELECT SUM(Size)").columns.first.numeric?
  end

  def test_order_by_user_property
    q = CardQuery.parse("SELECT 'assigned to', COUNT(*) ORDER BY 'assigned to'")
    assert_equal({"member@email.com (member)" => 1}, q.values_as_coords)
  end


  def test_order_by_user_property_should_first_order_by_name_then_order_by_login
    apple = create_user!(:name => 'apple', :login => 'apple')
    banana1 = create_user!(:name => 'banana', :login => '1banana' )
    banana2 = create_user!(:name => 'banana', :login => '2banana' )

    @project.add_member(apple)
    @project.add_member(banana1)
    @project.add_member(banana2)

    create_card!(:name => 'Blah', :owner => banana1.id)
    create_card!(:name => 'Blah', :owner => banana2.id)
    create_card!(:name => 'Blah', :owner => banana2.id)
    create_card!(:name => 'Blah', :owner => apple.id)


    q = CardQuery.parse("SELECT owner ORDER BY owner")
    assert_equal([apple, banana1, banana2, banana2].collect(&:name_and_login), q.single_values.compact)
  end

  # bug 3966
  def test_implicit_order_by_number_should_not_force_user_group_by_number
    assert !CardQuery.parse("SELECT Name WHERE type = 'Card' group by Name").values.empty?
  end

  def test_empty_string_should_be_treat_as_empty_condition
    assert_equal @project.cards.count, CardQuery.parse("").find_cards.size
    assert_equal @project.cards.count, CardQuery.parse("").card_count
  end

  def test_should_tell_non_conditional_parts
    assert_equal ['SELECT'], CardQuery.parse('select name').none_conditional_parts
    assert_equal ['SELECT', 'GROUP BY', 'ORDER BY'], CardQuery.parse("select size group by size order by size").none_conditional_parts
    assert_equal ['SELECT', 'ORDER BY'], CardQuery.parse("select name order by size").none_conditional_parts
    assert_equal ['SELECT', 'SUM'], CardQuery.parse("select sum(size)").none_conditional_parts
    assert_equal ['SELECT', 'AVG', 'GROUP BY', 'ORDER BY'], CardQuery.parse("select name, avg(size)").none_conditional_parts
    assert_equal ['SELECT'], CardQuery.parse("select distinct name").none_conditional_parts
  end

  def test_should_raise_on_non_condition_part_when_parsing_condition_query
    assert_has_invalid_parts_when_parse_as_condition 'select size where type = card group by size'
    assert_has_invalid_parts_when_parse_as_condition 'type = card order by size'
    assert_has_invalid_parts_when_parse_as_condition 'select name where type = story'
    assert_has_invalid_parts_when_parse_as_condition "SELECT name where Release = 'release 1' AND Type = 'story' ORDER BY status"
  end

  def test_should_support_non_english_character_are_values_of_relationship_properties
    create_project.with_active_project do |project|
      iteration = project.card_types.create(:name => '迭代')
      story = project.card_types.create(:name => '故事')

      tree = project.tree_configurations.create(:name => '迭代树')

      tree.update_card_types({
        iteration => {:position => 0, :relationship_name => '迭代树 － 迭代'},
        story => {:position => 1}
      })

      iteration1 = tree.add_child(project.cards.create!(:name => '迭代一', :card_type => iteration))
      iteration2 = tree.add_child(project.cards.create!(:name => '迭代二', :card_type => iteration))
      story1 = tree.add_child(project.cards.create!(:name => '故事一', :card_type => story), :to => iteration1)
      story2 = tree.add_child(project.cards.create!(:name => '故事二', :card_type => story), :to => iteration2)

      assert_equal({"Name"=>"故事二", "Number"=>"4", "迭代树 － 迭代"=>"#2 迭代二"}.keys.sort, CardQuery.parse("SELECT number, name, '迭代树 － 迭代'").values.first.keys.sort)
      assert_equal({"Name"=>"故事二", "Number"=>"4", "迭代树 － 迭代"=>"#2 迭代二"}.values.sort, CardQuery.parse("SELECT number, name, '迭代树 － 迭代'").values.first.values.sort)
    end
  end

  def test_should_allow_selection_of_card_relationship_property
    setting_first_card_as_value_of_card_property_on_first_card do |first_card|
      assert_equal [first_card], CardQuery.parse("SELECT 'related card'").find_cards
    end
  end

  def test_should_allow_comparison_of_card_relationship_property_with_card_name
    setting_first_card_as_value_of_card_property_on_first_card do |first_card|
      assert_equal([{"Number" => first_card.number.to_s}], CardQuery.parse("SELECT number WHERE 'related card' = '#{first_card.name}'").values)
    end
  end

  def test_should_allow_comparison_of_card_relationship_property_with_card_number
    setting_first_card_as_value_of_card_property_on_first_card do |first_card|
      assert_equal([{"Number" => first_card.number.to_s}], CardQuery.parse("SELECT number WHERE 'related card' = NUMBER #{first_card.number}").values)
    end
  end

  def test_should_allow_card_relationship_properties_in_a_group_by_clause
    first_card = @project.cards.first
    second_card = @project.cards.create!(:name => 'second card', :card_type_name => 'Card')

    first_card.cp_related_card = second_card
    first_card.save!

    second_card.cp_related_card = second_card
    second_card.save!

    expected_results = ["related card"=>"#2 second card", "Count "=>"2"]
    assert_equal expected_results, CardQuery.parse("SELECT 'related card', COUNT(*) GROUP BY 'related card'").values
  end

  def test_should_allow_card_relationship_properties_in_a_order_by_clause
    first_card = @project.cards.first
    second_card = @project.cards.create!(:name => 'second card', :card_type_name => 'Card')

    first_card.cp_related_card = second_card
    first_card.save!

    second_card.cp_related_card = first_card
    second_card.save!

    card_numbers_sorted_by_related_card = [first_card, second_card].sort_by { |c| c.cp_related_card.number }.collect(&:number)
    card_numbers_sorted_by_related_card_desc = card_numbers_sorted_by_related_card.reverse

    assert_equal card_numbers_sorted_by_related_card, CardQuery.parse("SELECT number ORDER BY 'related card'").values.collect { |r| r['Number'].to_i }
    assert_equal card_numbers_sorted_by_related_card_desc, CardQuery.parse("SELECT number ORDER BY 'related card' DESC").values.collect { |r| r['Number'].to_i }
  end

  def test_parsing_should_escape_mixed_single_double_quote_in_tree_name
    with_new_project do |project|
      setup_property_definitions "hello' world" => ['what', 'ever']
      CardQuery.parse(%{ SELECT Name WHERE "hello' world" = 'ever'})
    end
  end

  # bug 5699
  def test_should_be_fine_with_property_value_including_colon
    with_new_project do |project|
      setup_property_definitions "Defect Status" => ['Fix : in PROGRESS', 'done']
      CardQuery.parse(%{ SELECT name WHERE type = Card AND 'Defect Status' = "Fix : in PROGRESS" }).to_s
    end
  end

  def test_parser_should_allow_plv_names_with_hyphens
    related_card_property = @project.find_property_definition('related card')
    card_plv = create_plv!(@project, :name => 'favourite - card', :data_type => ProjectVariable::CARD_DATA_TYPE, :property_definition_ids => [related_card_property.id])
    CardQuery.parse(%{ SELECT Name WHERE 'related card' = (favourite - card) })
  end

  def test_parse_error_should_result_in_nice_error_message_suggesting_that_identifiers_need_to_be_quoted_if_they_contain_mql_tokens
    related_card_property = @project.find_property_definition('related card')
    card_plv = create_plv!(@project, :name => 'hello tree', :data_type => ProjectVariable::CARD_DATA_TYPE, :property_definition_ids => [related_card_property.id])

    assert_raise_message(CardQuery::DomainException, /You may have a project variable, property, or tag with a name shared by a MQL keyword.  If this is the case, you will need to surround the variable, property, or tags with quotes./) do
      CardQuery.parse(%{ SELECT Name WHERE 'related card' = (hello tree) })
    end
  end

  def test_should_throw_exception_when_tree_doesnt_exist
    assert_raise_message(CardQuery::Tree::TreeNotExistError, /Tree with name '#{'not exist tree'.bold}' does not exist/){
      CardQuery.parse(%{ SELECT Name FROM TREE 'not exist tree' })
    }
  end

  def test_should_throw_exception_when_property_doesnt_exist
    assert_raise_message(CardQuery::Column::PropertyNotExistError, /Card property '#{'status ddd'.bold}' does not exist/){
      CardQuery.parse(%{ SELECT Name WHERE 'status ddd' = (hello tree)  })
    }
  end

  def test_should_throw_exception_when_property_not_quoted
    assert_raise_message(CardQuery::Column::PropertyNotExistError,  /Card property '#{'Assigned'.bold}' does not exist./){
      CardQuery.parse(%{ SELECT COUNT(*) WHERE Assigned To = member })
    }
  end

  def test_property_name_starting_with_digits_should_be_need_be_quoted
    with_new_project do |project|
      setup_property_definitions "100x" => ['200Y'], "x100" => ['300Y']
      create_card! :name => 'uno', :"100x" => '200Y', :"x100" => '300Y'

      assert_equal [{"x100"=>"300Y"}], CardQuery.parse("SELECT x100").values
      assert_equal [{"100x"=>"200Y"}], CardQuery.parse("SELECT 100x").values
    end
  end

  def test_as_card_list_view_should_support_from_tree
    with_three_level_tree_project do |project|
      view = CardQuery.parse(%{FROM TREE 'three level tree' WHERE status=open}).as_card_list_view
      assert_equal %{FROM TREE 'three level tree' WHERE status = open}, view.to_params[:filters][:mql]
    end
  end

  def test_tree_condition_should_not_support_mutiple_trees_now
    with_three_level_tree_project do |project|
      project.tree_configurations.create(:name => 'another tree')
      assert_raise_message(CardQuery::Tree::MultipleTreesNotSupportedError, /FROM TREE condition does not support multiple trees/){
        CardQuery.parse("FROM TREE 'three level tree', 'another tree'")
      }
    end
  end

  # Bug 6166
  def test_text_property_definition_should_not_effected_by_project_numeric_precision
    with_new_project do |project|
      release = setup_managed_text_definition('release', [])
      create_card!(:name => 'card 1', :release => '2.11')
      create_card!(:name => 'card 2', :release => '2.111')
      assert_equal ['card 2'], CardQuery.parse("SELECT name WHERE release=2.111").single_values
    end
  end

  # bug 6212, chart part of bug 6236
  def test_can_use_long_property_definition_names_in_mql_with_oracle
    for_oracle do
      with_new_project do |project|
        long_property_name = "Development Completed In Iteration"
        type_card = project.card_types.first
        pd_planning_estimate = setup_numeric_property_definition('Planning Estimate', [1, 2, 3])
        pd_dev_completed_in_iteration = setup_card_relationship_property_definition('Development Completed in Iteration')
        type_card.property_definitions = [pd_planning_estimate, pd_dev_completed_in_iteration]

        iteration1 = project.cards.create!(:name => 'iteration1', :card_type_name => 'Card')

        card1 = project.cards.create!(:name => 'card one', :cp_planning_estimate => 1, :card_type_name => 'Card')
        pd_dev_completed_in_iteration.update_card(card1, iteration1)
        card1.save!

        card2 = project.cards.create!(:name => 'card two', :cp_planning_estimate => 3, :card_type_name => 'Card')
        pd_dev_completed_in_iteration.update_card(card2, iteration1)
        card2.save!

        card_query = CardQuery.parse("SELECT 'Development Completed in Iteration', SUM('Planning Estimate') WHERE 'Development Completed in Iteration' IS NOT NULL")
        assert_equal({ "#1 iteration1"=> 4 }, card_query.values_as_coords)
      end
    end
  end

  # Bug 6171
  def test_cast_numeric_columns_should_not_break_grouping_for_numeric_properties
    with_card_query_project do |project|
      cq = CardQuery.parse('SELECT DISTINCT numeric_free_text GROUP BY numeric_free_text')
      cq.cast_numeric_columns = true
      assert_equal [nil], cq.single_values
    end
  end

  # Bug 6171
  def test_cast_numeric_columns_should_not_break_grouping_for_forumlas
    with_card_query_project do |project|
      cq = CardQuery.parse('SELECT DISTINCT half GROUP BY half')
      cq.cast_numeric_columns = true
      assert_equal [nil], cq.single_values
    end
  end

  def test_can_escape_question_mark_in_property_names
    with_new_project do |project|
      property = setup_numeric_property_definition('why?', [1, 2, 3])
      card = project.cards.create!(:name => 'card', :card_type_name => 'Card')
      property.update_card(card, 1)
      card.save!

      cq = CardQuery.parse(%{SELECT 'why?' WHERE Type = 'Card'})
      assert_equal ['1'], cq.single_values
    end

  end

  def test_created_on_should_work_with_equal_operation
    Clock.fake_now(:year => 2008, :month => 4, :day => 25)
    with_new_project do |project|
      card = create_card!(:name => 'I am a card')
      mql = %{SELECT number WHERE 'created on'='2008-04-25'}
      cq = CardQuery.parse(mql)

      assert_equal [card.number.to_s], cq.single_values
    end
  end

  def test_should_support_project_as_predefinied_property_definition
    card = create_card!(:name => 'i am a card')
    mql = %{SELECT project WHERE number=#{card.number}}
    cq = CardQuery.parse(mql)
    assert_equal [@project.name], cq.single_values
    assert_equal [{"Project"=>@project.name}], cq.values  # bug 7737
  end

  # Bug 8091
  def test_number_works_with_operators_other_than_equals
    with_new_project do |project|
      card_number_1   = create_card!(:number => 1,   :name => 'one')
      card_number_20  = create_card!(:number => 20,  :name => 'twenty')
      card_number_100 = create_card!(:number => 100, :name => 'hundred')
      assert_equal ['one'],     CardQuery.parse(%{SELECT name WHERE number < 20}).single_values
      assert_equal ['hundred'], CardQuery.parse(%{SELECT name WHERE number > 20}).single_values
    end
  end

  def test_should_throw_exception_when_project_was_used_in_the_condition
    assert_raise_message(CardQuery::DomainException, "\'Project\' is only supported in SELECT statement") do
      CardQuery.parse(%{SELECT number,name WHERE name=xx AND project=XXXX})
    end
  end

  # Bug 6581
  def test_selecting_property_which_is_not_in_group_by_should_give_nice_error
    assert_raise_message(CardQuery::DomainException, "Use of GROUP BY is invalid. To GROUP BY a property you must also include this property in the SELECT statement.") do
      CardQuery.parse('SELECT Name, size GROUP BY size')
    end

    assert_equal ["for card query test"], CardQuery.parse('SELECT Name, sum(size) GROUP BY name').single_values
  end

  def test_created_on_should_be_group_by_in_card_query
    with_first_project do |project|
      query = CardQuery.parse(%{SELECT 'created on', count(*)})
      assert_equal 1,  query.values_as_pairs.size
      assert_equal project.cards.size,  query.values_as_pairs.first.last
    end
  end

  def test_values_for_macro_should_return_count_without_space_for_v2
    result = CardQuery.parse('SELECT count(*)').values_for_macro(:api_version => 'v2')
    assert_equal ['count'], result.first.keys
  end

  def test_values_for_macro_should_return_count_with_underscore_for_v1
    result = CardQuery.parse('SELECT count(*)').values_for_macro(:api_version => 'v1')
    assert_equal ['count_'], result.first.keys
  end

  def test_values_for_macro_should_only_return_the_distinct_column_for_select_distinct_with_enumerated_numeric_properties
    result = CardQuery.parse('SELECT DISTINCT size').values_for_macro(:api_version => 'v2')
    assert_equal ['size'], result.first.keys
  end

  def test_values_for_macro_should_be_sanitized
    result = CardQuery.parse("SELECT Size, 'Created On'").values_for_macro(:api_version => 'v2')
    assert_equal ['created_on', 'size'].sort, result.first.keys.sort
  end

  #bug 6787
  def test_should_be_able_to_diferentiate_two_properties_with_very_long_names
    first = @project.find_property_definition('iteration')
    first.update_attributes(:name => 'did you check for related pending tests?')
    first.save!
    second = @project.find_property_definition('Release')
    second.update_attributes(:name => 'did you check for related pending tests!')
    second.save!

    card = @project.cards.create!(:name => 'card', :card_type_name => 'Card')
    first.update_card(card, 1)
    second.update_card(card, 2)
    card.save!

    mql = "SELECT \"did you check for related pending tests?\", \"did you check for related pending tests!\" where name = card"
    result = CardQuery.parse(mql).values
    assert_equal ["1", "2"], result.first.values
  end

  # bug #7788
  def test_mql_with_question_marks_in_it_should_not_make_the_query_blow_up
    card = @project.cards.create!(:name => 'hi', :card_type_name => 'Card', :cp_status => 'new')

    pd_status = @project.find_property_definition('status')
    value_new = pd_status.find_enumeration_value('New')
    value_new.value = 'New?'
    value_new.save!

    assert_equal ["hi"], CardQuery.parse("select name where 'Status' IN ('closed', 'done', 'new?')").single_values
    assert_equal ["hi"], CardQuery.parse("select name where 'Status' = 'new?'").single_values
  end

  # bug 7636
  def test_comparason_of_card_created_on_and_a_date_property_should_work
    @project.cards.destroy_all
    card = create_card!(:name => 'card')
    card.update_attribute(:cp_date_deleted, card.created_on)
    query = CardQuery.parse("\"created on\" = PROPERTY date_deleted")
    assert_equal [card.number], query.find_card_numbers
  end

  # bug 8151
  def test_can_make_date_comparisons_using_in_clause
    expected_card_one = create_card! :name => 'One', :date_created => 'May 02 2009'
    expected_card_two = create_card! :name => 'Two', :date_created => 'May 03 2009'
    expected_cards = [expected_card_one, expected_card_two].map { |card| { "Number" => card.number.to_s } }
    assert_equal [{ "Number" => expected_card_one.number.to_s }], CardQuery.parse("SELECT number WHERE date_created IN ('May 02 2009', 'May 10 2009')", :content_provider => expected_card_one).values
    assert_equal expected_cards, CardQuery.parse("SELECT number WHERE date_created IN ('2009-05-02', '2009-05-03')", :content_provider => expected_card_one).values
  end

  def test_should_remove_any_additional_columns_not_selected_by_the_user
      result = CardQuery.parse('SELECT DISTINCT size').values
      assert_equal 1, result.first.keys.size
      assert_equal "Size", result.first.keys.first
  end

  def test_should_query_card_versions_for_as_of_date
    set_project_timezone_to_utc
    Clock.now_is(:year => 2000, :month => 2, :day => 1) { |now| @card = create_card!(:name => 'One') }
    Clock.now_is(:year => 2000, :month => 2, :day => 3) { |now| @card.update_attribute :name, 'Three' }
    assert_equal ['One'], CardQuery.parse('SELECT name AS OF "02 Feb 2000"').single_values
  end

  def test_should_be_able_to_query_card_versions_with_simple_sub_query_for_as_of_date
    set_project_timezone_to_utc
    Clock.now_is(:year => 2000, :month => 2, :day => 1) { |now| @card = create_card!(:name => 'One') }
    Clock.now_is(:year => 2000, :month => 2, :day => 3) { |now| @card.update_attribute :name, 'Two' }
    assert_equal ['One'], CardQuery.parse(%Q{SELECT name AS OF "2000-02-02" WHERE number IN (SELECT number WHERE number = #{@card.number})}).single_values
  end

  def test_should_be_able_to_use_this_card_and_as_of_together
    set_project_timezone_to_utc
    with_new_project do |project|
      Clock.fake_now(:year => 2009, :month => 6, :day => 2)
      type_release, type_iteration, type_story = init_planning_tree_types
      create_three_level_tree
      iteration1 = project.cards.find_by_name('iteration1')

      query = CardQuery.parse(%Q{ SELECT name AS OF "2009-06-02" }, :content_provider => iteration1).restrict_with("").restrict_with("WHERE 'Planning iteration' = THIS CARD")
      assert_equal ['story1', 'story2'], query.single_values.sort
    end
  end

  def test_should_convert_different_project_timezone_to_utc_for_as_of_date
    set_project_timezone_to_beijing
    query = CardQuery.parse('SELECT name AS OF "02 Feb 2000"')
    assert_equal ActiveSupport::TimeZone.new('UTC').parse('01 Feb 2000 16:00:00'), query.as_of
    assert_equal "SELECT Name AS OF \"2000-02-02\" ORDER BY Number DESC", query.to_s.strip
  end

  def test_should_convert_different_project_timezone_to_utc_for_as_of_date_when_select_values
    set_project_timezone_to_beijing
    Clock.now_is(:year => 2000, :month => 2, :day => 1, :hour => 16) { |now| @card = create_card!(:name => 'One') }
    Clock.now_is(:year => 2000, :month => 2, :day => 3, :hour => 16) { |now| @card.update_attribute :name, 'Two' }
    assert_equal [], CardQuery.parse(%Q{SELECT name AS OF "2000-02-01"}).single_values
    assert_equal ['One'], CardQuery.parse(%Q{SELECT name AS OF "2000-02-02"}).single_values
  end

  def test_should_raise_property_not_exist_error_when_select_version_with_as_of_and_there_is_not_a_property_named_version
    assert_raise CardQuery::Column::PropertyNotExistError do
      CardQuery.parse(%Q{SELECT version AS OF "2000-05-02"}).single_values
    end
  end

  def test_as_of_respects_daylight_saving_at_the_as_of_date
    set_project_timezone_to_london_which_is_at_utc_only_during_the_winter
    Clock.now_is(:year => 2004, :month => 1, :day => 1, :hour => 23) { |now| @card = create_card!(:name => 'One') }
    Clock.now_is(:year => 2004, :month => 1, :day => 2, :hour => 23, :minute => 59, :second => 59) { |now| @card = create_card!(:name => 'Two') }
    Clock.now_is(:year => 2004, :month => 1, :day => 3) { |now| @card = create_card!(:name => 'Three') }
    assert_equal ['One', 'Two'].sort, CardQuery.parse(%Q{SELECT name AS OF "2004-01-02"}).single_values.sort
  end

  def test_as_of_respects_daylight_saving_at_the_as_of_date_during_summer
    set_project_timezone_to_london_which_is_at_utc_only_during_the_winter
    Clock.now_is(:year => 2004, :month => 5, :day => 1, :hour => 23) { |now| @card = create_card!(:name => 'One') }
    Clock.now_is(:year => 2004, :month => 5, :day => 2, :hour => 23, :minute => 59, :second => 59) { |now| @card = create_card!(:name => 'Two') }
    Clock.now_is(:year => 2004, :month => 5, :day => 3) { |now| @card = create_card!(:name => 'Three') }
    assert_equal ['One'].sort, CardQuery.parse(%Q{SELECT name AS OF "2004-05-02"}).single_values.sort
  end

  def test_as_of_takes_value_of_last_card_versions_on_same_day
    set_project_timezone_to_utc
    Clock.now_is(:year => 2000, :month => 5, :day => 1, :hour => 1) { |now| @card = create_card!(:name => 'first') }
    Clock.now_is(:year => 2000, :month => 5, :day => 1, :hour => 2) { |now| @card.update_attribute :name, 'later' }
    assert_equal ['later'], CardQuery.parse(%Q{SELECT name AS OF "2000-05-01"}).single_values.sort
  end

  def test_to_s_for_as_of_date
    set_project_timezone_to_utc
    assert_equal "SELECT Name AS OF \"2000-05-02\" ORDER BY Number DESC ", CardQuery.parse('SELECT name AS OF "2000-05-02"').to_s
  end

  def test_as_of_should_use_a_utc_time_relative_to_the_projects_time_zone
    @project.update_attributes! :time_zone => ActiveSupport::TimeZone.new('Hawaii').name
    t = january_31st_3pm_hawaian_time = @project.utc_to_local(Time.utc(2010, "Feb", 1, 1))
    Clock.now_is(:year => t.year, :month => t.month, :day => t.day, :hour => t.hour) do |now|
      @card = create_card! :name => 'One'
    end
    assert_equal ['One'], CardQuery.parse(%Q{SELECT name AS OF "2010-01-31"}).single_values.sort
  end

  def test_should_raise_a_domain_exception_when_using_from_tree_in_conjunction_with_as_of
    with_three_level_tree_project do |project|
      assert_raise(CardQuery::DomainException) do
        CardQuery.parse('SELECT name AS OF "2000-01-01" FROM TREE "three level tree"')
      end
    end
  end

  def test_should_raise_a_domain_exception_when_using_tagged_with_in_conjunction_with_as_of
    with_three_level_tree_project do |project|
      assert_raise(CardQuery::DomainException) do
        CardQuery.parse('SELECT name AS OF "2000-01-01" WHERE TAGGED WITH "foo"')
      end
    end
  end

  def test_should_give_date_format_error_when_given_unexpected_date_value
    assert_raise_message(CardQuery::DomainException, /dd mmm yyyy/) do
      CardQuery.parse('SELECT name AS OF "Foobuary-second-2000"')
    end
  end

  def test_should_fetch_card_numbers_and_name_ordered_by_card_property
    with_new_project do |project|
      setup_property_definitions 'status' => ['new', 'in-progress', 'done']
      setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
      setup_card_type(project, 'story', :properties => ['status', 'estimate'])
      create_card!(:name => 'first', :card_type => 'story',:status => 'new', :estimate => 2)
      create_card!(:name => 'second', :card_type => 'story',:status => 'done', :estimate => 16)

      query = CardQuery.parse('SELECT status, count(*) WHERE type=story')
      expected = {'new' => [{:name => 'first', :number => '1'}], 'done' => [{:name => 'second', :number => '2'}]}
      assert_equal expected, query.find_cards_ordered_by_property

      query = CardQuery.parse('SELECT estimate, sum(estimate) WHERE type=story')
      expected = {'2' => [{:name => 'first', :number => '1'}], '16' => [{:name => 'second', :number => '2'}]}
      assert_equal expected, query.find_cards_ordered_by_property
    end
  end

  def test_should_fetch_cards_ordered_by_property_for_given_limit
    with_new_project do |project|
      setup_property_definitions 'status' => ['new', 'in-progress', 'done']
      setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
      setup_card_type(project, 'story', :properties => ['status', 'estimate'])
      create_card_in_future(2.seconds, :name => 'first', :card_type => 'story',:status => 'new', :estimate => 2)
      create_card_in_future(3.seconds, :name => 'second', :card_type => 'story',:status => 'new', :estimate => 2)
      create_card_in_future(4.seconds, :name => 'third', :card_type => 'story',:status => 'new', :estimate => 4)
      create_card_in_future(5.seconds, :name => 'fourth', :card_type => 'story',:status => 'done', :estimate => 4)
      create_card_in_future(6.seconds, :name => 'fifth', :card_type => 'story',:status => 'done', :estimate => 4)
      create_card_in_future(7.seconds, :name => 'sixth', :card_type => 'story',:status => 'done', :estimate => 4)
      create_card_in_future(8.seconds, :name => 'seventh', :card_type => 'story',:status => 'done', :estimate => 4)

      query = CardQuery.parse('SELECT status, count(*) WHERE type=story')
      new_cards = query.find_cards_ordered_by_property(:limit => 2)['new']
      assert_equal 3, new_cards[:count]
      assert_equal 2, new_cards[:cards].size
      assert_equal ['third', 'second'], new_cards[:cards].map {|c| c[:name]}

      query = CardQuery.parse('SELECT status, count(*) WHERE type=story')
      done_cards = query.find_cards_ordered_by_property(:limit => 1)['done']

      assert_equal 4, done_cards[:count]
      assert_equal 1, done_cards[:cards].size
      assert_equal ['seventh'], done_cards[:cards].map {|c| c[:name]}
    end
  end

  def test_find_cards_ordered_by_property_should_throw_exception_when_property_not_selected
    with_new_project do |project|
      setup_property_definitions 'status' => ['new', 'in-progress', 'done']
      setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
      setup_card_type(project, 'story', :properties => ['status', 'estimate'])
      create_card!(:name => 'first', :card_type => 'story',:status => 'new', :estimate => 2)
      create_card!(:name => 'second', :card_type => 'story',:status => 'done', :estimate => 16)

      query = CardQuery.parse('SELECT count(*) WHERE type=story')
      assert_raise (CardQuery::DomainException) { query.find_cards_ordered_by_property }
    end
  end

  def test_find_cards_ordered_by_property_should_order_cards_by_last_modified_stamp
    with_new_project do |project|
      setup_property_definitions 'status' => ['new', 'in-progress', 'done']
      setup_numeric_property_definition 'estimate', [2, 4, 8, 16]
      setup_card_type(project, 'story', :properties => ['status', 'estimate'])
      card1 = create_card!(:name => 'first', :card_type => 'story', :status => 'new', :estimate => 2)
      create_card!(:name => 'second', :card_type => 'story',:status => 'new', :estimate => 4)
      create_card_in_future(2.seconds, :name => 'third', :card_type => 'story',:status => 'new', :estimate => 8)
      create_card!(:name => 'fourth', :card_type => 'story',:status => 'in-progress', :estimate => 16)
      Timecop.travel(DateTime.now + 10.seconds)  do
        card1.update_attribute(:name, 'first modified')
      end

      query = CardQuery.parse('SELECT status, count(*) WHERE type=story')
      card_names = query.find_cards_ordered_by_property['new'].map {|c| c[:name]}
      assert_equal(['first modified', 'third', 'second'], card_names)
    end
  end

  #bug 9156
  def test_order_by_and_distinct_same_user_property_definition
    query = CardQuery.parse('SELECT DISTINCT owner ORDER BY owner DESC')
    assert query.values
  end

  def test_should_be_able_to_fetch_complete_branch_name_for_cards
    with_three_level_tree_project do |project|
      tree_config = project.tree_configurations.first
      base_query = CardQuery.new(:columns => tree_config.relationship_map.mql_columns)
      story_condition = CardQuery.parse_as_condition_query('where type=story')
      expanded_column_names = base_query.restrict_with(story_condition).values_as_expanded_card_names
      story1 = project.cards.find_by_name('story1')
      story2 = project.cards.find_by_name('story2')
      assert_equal "release1 > iteration1 > story1", expanded_column_names[story1.id]
      assert_equal "release1 > iteration1 > story2", expanded_column_names[story2.id]
    end
  end

  def test_should_be_able_to_fetch_abbreviated_branch_name_for_cards
    with_three_level_tree_project do |project|
      tree_config = project.tree_configurations.first
      base_query = CardQuery.new(:columns => tree_config.relationship_map.mql_columns)
      story_condition = CardQuery.parse_as_condition_query('where type=story')
      abbreviated_column_names = base_query.restrict_with(story_condition).values_as_abbreviated_card_names
      story1 = project.cards.find_by_name('story1')
      story2 = project.cards.find_by_name('story2')
      assert_equal "story1", abbreviated_column_names[story1.id]
      assert_equal "story2", abbreviated_column_names[story2.id]
    end
  end

  def test_select_uppercase_card_relationship_property_name_should_work
    login_as_admin
    with_new_project do |project|
      UnitTestDataLoader.setup_card_relationship_property_definition('BUC')
      buc = create_card! :name => 'business use case'
      story = create_card! :name => 'blah', :BUC => buc.id
      q = CardQuery.parse("SELECT Number, BUC WHERE number is #{story.number}")
      assert_equal "##{buc.number} business use case", q.values.first['BUC']
    end
  end

  # bug 12462
  def test_select_tree_relationship_property_with_number
    with_three_level_tree_project do |project|
      mql = CardQuery.parse("SELECT 'planning iteration', number ORDER BY 'planning iteration'")

      expected = [
        {"Number"=>"1", "Planning iteration"=>nil},
        {"Number"=>"2", "Planning iteration"=>nil},
        {"Number"=>"3", "Planning iteration"=>nil},
        {"Number"=>"4", "Planning iteration"=>"#2 iteration1"},
        {"Number"=>"5", "Planning iteration"=>"#2 iteration1"}
      ]
      assert_equal expected, mql.values.sort_by {|r| r['Number'].to_i }
    end
  end

  def test_umlauts_in_card_query_identifiers
    with_new_project do |project|
      setup_property_definitions "Umlàut"  => ['òne']
      assert CardQuery.parse(%{ SELECT Umlàut})
    end
  end

  def test_card_queries_with_unicode_characters_should_match
    with_new_project do |project|
      card_type = project.card_types.first
      card = project.cards.create! :name => 'blah', :card_type_name => card_type.name
      property_definition = project.create_any_text_definition!(:name => "áÈß", :is_numeric  =>  false)
      card_type.add_property_definition property_definition
      property_definition.update_card(card, "some value")
      card.save!
      values = CardQuery.parse(%{ SELECT áÈß}).values
      assert_equal "some value", values.first['áÈß']
    end
  end


  def test_mql_name_returns_quoted_name
    with_new_project do |_|
      setup_property_definitions 'name_without_space' => ['new', 'in-progress', 'done']
      setup_property_definitions 'name with   spaces' => ['new', 'in-progress', 'done']

      column = CardQuery::Column.new('name_without_space', 'desc')
      assert_equal "'#{column.name}'", column.mql_name

      column = CardQuery::Column.new('name with   spaces', 'desc')
      assert_equal "'#{column.name}'", column.mql_name
    end
  end

  private

  def assert_has_invalid_parts_when_parse_as_condition(mql)
    assert_raise(CardQuery::NonConditionalPartsExists) { CardQuery.parse_as_condition_query(mql)}
  end

  def quote_column_name(column)
    Project.connection.quote_column_name(column)
  end

  def quote_value(value)
    Project.connection.quote_value(value)
  end

  def setting_first_card_as_value_of_card_property_on_first_card
    first_card = @project.cards.first
    first_card.cp_related_card = first_card
    first_card.save!

    yield(first_card)
  end

  def set_project_timezone_to_london_which_is_at_utc_only_during_the_winter
    # London is at UTC. *Only* during the winter. In summer, its offset is +0100.
    @project.update_attributes! :time_zone => ActiveSupport::TimeZone.new('London').name
  end

  def set_project_timezone_to_beijing
    @project.update_attributes! :time_zone => ActiveSupport::TimeZone.new('Beijing').name
  end

  def set_project_timezone_to_utc
    @project.update_attributes! :time_zone => ActiveSupport::TimeZone.new('UTC').name
  end

end
