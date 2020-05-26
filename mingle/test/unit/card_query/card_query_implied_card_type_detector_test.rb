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

class CardQueryImpliedCardTypeDetectorTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  
  def setup
    @project = three_level_tree_project
    @project.activate
    login_as_member
    @card = @project.cards.find_by_number(1)
  end
  
  def test_should_answer_all_card_types_when_none_specified
    assert_card_types ['Card', 'iteration', 'release', 'story'], "SELECT Number"
  end
  
  def test_should_answer_exact_card_type_when_specified_in_equals_condition
    assert_card_types ['Card'], "SELECT Number WHERE type=Card"
  end  
  
  def test_should_answer_everything_but_the_exact_card_type_when_specified_in_not_equals_condition
    assert_card_types ["iteration", "release", "story"], "SELECT Number WHERE NOT type=Card"
  end  
  
  def test_should_answer_the_exact_card_type_when_specified_in_not_equals_condition_and_operator_is_not_equals
    assert_card_types ["Card"], "SELECT Number WHERE NOT type!=Card"
  end  

  def test_should_answer_card_types_with_higher_position_than_specified_one_in_a_greater_than_condition
    assert_card_types ["iteration", "release", "story"], "SELECT Number WHERE type > Card"
  end  
    
  def test_should_answer_card_types_with_higher_position_than_specified_one_in_a_less_than_condition
    assert_card_types ['Card', "iteration", "release"], "SELECT Number WHERE type < story"
  end  
    
  def test_should_answer_card_types_which_are_not_specified_in_a_not_equals_condition
    assert_card_types ['Card', "release", 'story'], "SELECT Number WHERE type != iteration"
  end  
    
  def test_should_answer_card_types_which_are_specified_in_a_in_condition
    assert_card_types ['Card', 'iteration'], "SELECT Number WHERE type IN (Card, iteration)"
  end  
    
  def test_should_answer_valid_card_types_when_comparing_with_a_relationship_property
    assert_card_types ['story'], "SELECT Number WHERE 'Planning iteration' IN ('Foo')"
  end  
  
  def test_should_answer_all_card_types_when_a_property_other_than_type_is_specified
    assert_card_types ['Card', 'iteration', 'release', 'story'], "SELECT Number WHERE Status = Open"
  end
  
  def test_should_answer_card_types_applicable_to_both_conditions_of_an_and_clause
    assert_card_types ['story'], "SELECT Number WHERE type = Story AND Status = Open"
  end

  def test_should_answer_card_types_even_when_only_a_card_type_agnostic_condition_is_used
    with_first_project do
      assert_card_types ['Card'], "SELECT Number WHERE Assigned = CURRENT USER"
    end
  end

  # Bug 6569
  def test_should_answer_card_types_when_multiple_card_type_agnostic_conditions_are_used_in_conjunction_with_an_and
    with_first_project do
      assert_card_types ['Card'], "SELECT Number WHERE Assigned = CURRENT USER AND Assigned = CURRENT USER"
    end
  end

  # Bug 6569
  def test_should_answer_card_types_when_multiple_card_type_agnostic_conditions_are_used_in_conjunction_with_an_or
    with_first_project do
      assert_card_types ['Card'], "SELECT Number WHERE Assigned = CURRENT USER OR Assigned = CURRENT USER"
    end
  end

  def test_should_answer_card_types_when_multiple_card_type_agnostic_conditions_are_used_in_conjunction_with_an_not
    with_first_project do
      assert_card_types ['Card'], "SELECT Number WHERE Assigned = CURRENT USER OR NOT Assigned = CURRENT USER"
    end
  end
  
  def test_should_answer_card_types_applicable_to_either_condition_of_an_and_clause
    assert_card_types ['iteration', 'story'], "SELECT Number WHERE type = Story OR type = iteration"
  end
  
  def test_should_answer_all_card_types_whose_names_are_any_of_the_values_for_a_particular_property_when_comparing_type_with_a_property
    assert_card_types [], "SELECT Number WHERE type = PROPERTY Status"
  end
  
  def test_should_answer_all_card_types_when_comparing_with_a_tagging_condition
    assert_card_types ['Card', 'iteration', 'release', 'story'], "SELECT Number WHERE TAGGED WITH foo"
  end
  
  def test_should_answer_all_card_types_when_comparing_with_a_tagging_condition_in_an_compound_condition
    assert_card_types ['Card', 'iteration', 'release', 'story'], "SELECT Number WHERE type = Story OR TAGGED WITH foo"
    assert_card_types ['story'], "SELECT Number WHERE type = Story AND TAGGED WITH foo"
  end
  
  def test_should_answer_all_card_types_when_comparing_with_a_relationship_property
    assert_card_types ['iteration', 'story'], "SELECT Number WHERE 'Planning release' = 'Release1'"
    assert_card_types ['release', 'iteration', 'story'], "SELECT Number WHERE type=release OR 'Planning release' = 'Release1'"
  end
  
  def test_should_answer_available_card_types_based_on_tree_configuration_when_comparing_with_a_relationship_property_in_a_number_comparison_clause
    release_1_number = @project.cards.find_by_name('release1').number
    assert_card_types ['iteration', 'story'], "SELECT Number WHERE 'Planning release' = NUMBER #{release_1_number}"
  end
  
  def test_should_answer_available_card_types_based_on_tree_configuration_when_comparing_with_a_relationship_property_in_a_number_comparison_clause_as_a_part_of_a_complex_clause
    release_1_number = @project.cards.find_by_name('release1').number
    assert_card_types [], "SELECT Number WHERE Type=Release AND 'Planning release' = NUMBER #{release_1_number}"
    assert_card_types ['release', 'iteration', 'story'], "SELECT Number WHERE Type=Release OR 'Planning release' = NUMBER #{release_1_number}"
  end
  
  def test_should_answer_all_card_types_when_comparing_with_a_relationship_property_in_a_numbers_in_clause
    release_1_number = @project.cards.find_by_name('release1').number
    assert_card_types ['iteration', 'story'], "SELECT Number WHERE 'Planning release' NUMBERS IN (#{release_1_number})"
  end
  
  def test_should_answer_all_card_types_when_comparing_with_a_relationship_property_in_a_numbers_in_clause_as_a_part_of_a_complex_clause
    release_1_number = @project.cards.find_by_name('release1').number
    assert_card_types [], "SELECT Number WHERE Type=Release AND 'Planning release' NUMBERS IN (#{release_1_number})"
    assert_card_types ['release', 'iteration', 'story'], "SELECT Number WHERE Type=Release OR 'Planning release' NUMBERS IN (#{release_1_number})"
  end
  
  def test_should_answer_correct_card_types_for_complex_mql
    assert_card_types ['iteration', 'story'], "SELECT Number WHERE (type = Story OR type = iteration) AND (Status = Open OR Type = iteration)"
    assert_card_types ['Card', 'iteration', 'release', 'story'], "SELECT Number WHERE (type = Story OR type = iteration) OR (Status = Open OR Type = iteration)"
    assert_card_types ['Card', 'iteration', 'release', 'story'], "SELECT Number WHERE (type = Story AND type = iteration) OR (Status = Open OR Type = iteration)"
    assert_card_types ['iteration'], "SELECT Number WHERE (type = Story AND type = iteration) OR (Status = Open AND Type = iteration)"
  end
  
  def test_should_answer_correct_card_types_for_from_tree_condition
    tree_name = @project.tree_configurations.first.name
    assert_card_types ["iteration", "release", "story"], "SELECT Number FROM TREE #{tree_name.inspect}"
    assert_card_types ['release'], "SELECT Number FROM TREE #{tree_name.inspect} WHERE TYPE = release"
  end
  
  # Bug 4729
  def test_should_handle_multiple_not_type_conditions
    assert_card_types ['release', 'story'], "SELECT Number WHERE NOT type=card AND NOT type=iteration"
  end
  
  # Bug 4729
  def test_should_not_flip_implied_card_types_on_properties_using_not
    assert_card_types ['Card'], "SELECT Number WHERE type=Card AND Status is not null"
    assert_card_types ['Card'], "SELECT Number WHERE type=Card AND NOT Status=Open"
  end
  
  # Bug 4729
  def test_should_not_negate_card_types_allowed_when_using_not_on_a_property
    assert_card_types ['Card', 'iteration', 'release', 'story'], "SELECT Number WHERE               NOT Status = Open"
    assert_card_types ['Card'                                 ], "SELECT Number WHERE type=Card AND NOT Status = Open"
    assert_card_types ['Card', 'iteration', 'release', 'story'], "SELECT Number WHERE type=Card OR  NOT Status = Open"
  end
  
  protected
  
  def assert_card_types(expected_card_type_names, mql)  
    assert_equal expected_card_type_names.sort, CardQuery::ImpliedCardTypeDetector.new(CardQuery::parse(mql)).execute.collect(&:name).sort
  end  
end
