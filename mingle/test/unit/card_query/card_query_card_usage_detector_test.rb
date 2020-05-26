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

class CardQueryCardUsageDetectorTest < ActiveSupport::TestCase
  
  def setup
    login_as_admin
    @project = card_query_project
    @project.activate
    @card = @project.cards.first
    @the_other_card = @project.cards.create!(:name => 'the other card', :card_type_name => 'Card')
  end
  
  def teardown
    logout_as_nil
  end
  
  def test_should_be_able_to_find_card_in_where_clause_when_equals_name
    assert_usages_of_card @card, "SELECT COUNT(*) WHERE 'related card' = '#{@card.name}'"
    assert_no_usages_of_card @the_other_card, "SELECT COUNT(*) WHERE 'related card' = '#{@card.name}'"
  end
  
  def test_should_be_able_to_find_card_in_where_clause_with_equality_comparison_based_on_number
    assert_usages_of_card @card, "SELECT COUNT(*) WHERE 'related card' = NUMBER #{@card.number}"
    assert_no_usages_of_card @the_other_card, "SELECT COUNT(*) WHERE 'related card' = NUMBER #{@card.number}"
  end

  def test_should_be_able_to_find_card_in_where_clause_with_an_explicit_in_clause
    assert_usages_of_card @card, "SELECT COUNT(*) WHERE 'related card' IN ('#{@card.name}')"
    assert_no_usages_of_card @the_other_card, "SELECT COUNT(*) WHERE 'related card' IN ('#{@card.name}')"
  end
  
  def test_should_be_able_to_find_card_in_where_clause_with_an_explicit_numbers_in_clause
    assert_usages_of_card @card, "SELECT COUNT(*) WHERE 'related card' NUMBERS IN (#{@card.number})"
    assert_no_usages_of_card @the_other_card, "SELECT COUNT(*) WHERE 'related card' NUMBERS IN (#{@card.number})"
  end
  
  def test_should_be_able_to_find_card_in_where_clause_with_complex_and_condition_that_uses_the_card_name_in_one_of_its_legs
    assert_usages_of_card @card, "SELECT COUNT(*) WHERE Type='Card' AND 'related card' = '#{@card.name}'"
    assert_no_usages_of_card @the_other_card, "SELECT COUNT(*) WHERE Type='Card' AND 'related card' = '#{@card.name}'"
  end
  
  def test_should_be_able_to_find_card_in_where_clause_with_complex_and_condition_that_uses_the_card_name_in_one_of_its_legs_and_another_card_in_other_legs
    assert_usages_of_card @card, "SELECT COUNT(*) WHERE 'related card' = '#{@the_other_card.name}' AND 'related card' = '#{@card.name}'"
    assert_usages_of_card @the_other_card, "SELECT COUNT(*) WHERE 'related card' = '#{@the_other_card.name}' AND 'related card' = '#{@card.name}'"
  end
  
  def test_should_be_able_to_find_card_in_where_clause_with_complex_or_condition_that_uses_the_card_name_in_one_of_its_legs
    assert_usages_of_card @card, "SELECT COUNT(*) WHERE Type = 'Card' OR 'related card' = '#{@card.name}'"
    assert_no_usages_of_card @the_other_card, "SELECT COUNT(*) WHERE Type = 'Card' OR 'related card' = '#{@card.name}'"
  end

  def test_should_be_able_to_find_card_in_where_clause_with_complex_or_condition_that_does_not_use_the_card_ever
    assert_no_usages_of_card @card, "SELECT COUNT(*) WHERE 'related card' = NUMBER #{@the_other_card.number} OR 'related card' = '#{@the_other_card.name}'"
  end

  def test_should_be_able_to_find_card_usage_in_very_simple_cases
    assert_no_usages_of_card @card, "SELECT COUNT(*) WHERE Type = 'Card'"
  end

  def test_should_be_able_to_find_card_usage_using_only_card_type_agnostic_conditions
    assert_no_usages_of_card @card, "SELECT COUNT(*) WHERE owner = CURRENT USER and 'Assigned To' = CURRENT USER"
  end

  def test_should_be_able_to_find_card_in_where_not_clause
    assert_usages_of_card @card, "SELECT COUNT(*) WHERE NOT 'related card' IN ('#{@card.name}')"
    assert_usages_of_card @card, "SELECT COUNT(*) WHERE NOT 'related card' NUMBERS IN (#{@card.number})"

    assert_no_usages_of_card @the_other_card, "SELECT COUNT(*) WHERE NOT 'related card' IN ('#{@card.name}')"
    assert_no_usages_of_card @the_other_card, "SELECT COUNT(*) WHERE NOT 'related card' NUMBERS IN (#{@card.number})"
  end
  
  def test_should_ignore_null_values
    assert_no_usages_of_card @card, "SELECT COUNT(*) WHERE 'related card' IS NULL"
  end
  
  def test_should_ignore_empty_values
    assert_no_usages_of_card @card, "SELECT COUNT(*) WHERE 'related card' = ''"
  end

  def test_uses_any_card_should_not_include_not_set_conditions
    assert !uses_any_card?("SELECT COUNT(*) WHERE 'related card' IS NULL")
  end
  
  def test_uses_any_card_should_find_card_equality
    assert uses_any_card?("SELECT COUNT(*) WHERE 'related card' = '#{@card.name}'")
  end
  
  def test_uses_any_card_should_find_cards_in
    assert uses_any_card?("SELECT COUNT(*) WHERE 'related card' IN ('#{@card.name}')")
  end
  
  def test_should_include_number_column
    assert_usages_of_card @card, "SELECT COUNT(*) WHERE NUMBER = #{@card.number}"
    assert_no_usages_of_card @the_other_card, "SELECT COUNT(*) WHERE NUMBER = #{@card.number}"
  end
  
  # bug 6976
  def test_card_detector_should_not_crash_when_card_query_have_a_compare_condition_for_the_relationshipp_property
    @card.update_attribute(:name, "I_am_a_card_name")
    assert_usages_of_card @card, "SELECT COUNT(*) WHERE 'related card' > #{@card.name}"
    assert_usages_of_card @card, "SELECT COUNT(*) WHERE 'related card' > '#{@card.name}'"
  end
  
  
  private
  def detector(mql)
    CardQuery::CardUsageDetector.new(CardQuery.parse(mql))
  end

  def uses_any_card?(mql)
    detector(mql).uses_any_card?
  end
  
  def assert_usages_of_card(card, mql)
    assert detector(mql).uses?(card)
  end  

  def assert_no_usages_of_card(card, mql)
    assert !detector(mql).uses?(card)
  end  
end
