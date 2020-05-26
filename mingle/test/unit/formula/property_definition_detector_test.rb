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

class PropertyDefinitionDetectorTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  
  def setup
    first_project.activate
  end
  
  def teardown
    logout_as_nil
    Project.current.deactivate rescue nil
  end
  
  def test_detect_single_property_definition_formula
    assert_equal ['Release'], directly_related_property_definitions('Release')
  end
  
  def test_detect_property_definition_in_addition
    assert_equal ['Release'], directly_related_property_definitions('Release + 1')
    assert_equal ['Release'], directly_related_property_definitions('1 + Release')
  end
  
  def test_detect_property_definition_in_subtraction
    assert_equal ['Release'], directly_related_property_definitions('Release - 1')
    assert_equal ['Release'], directly_related_property_definitions('1 - Release')
  end
  
  def test_detect_property_definition_in_multiplication
    assert_equal ['Release'], directly_related_property_definitions('Release * 1')
    assert_equal ['Release'], directly_related_property_definitions('1 * Release')
  end
  
  def test_detect_property_definition_in_division
    assert_equal ['Release'], directly_related_property_definitions('Release / 1')
    assert_equal ['Release'], directly_related_property_definitions('1 / Release')
  end
  
  def test_detect_property_definition_in_negation
    assert_equal ['Release'], directly_related_property_definitions('-Release')
  end
  
  def test_should_not_detect_same_property_definition_more_than_once
    assert_equal ['Release'], directly_related_property_definitions('Release + Release')
  end
  
  def test_detect_property_definition_in_sub_expression
    assert_equal ['Release'], directly_related_property_definitions('1 + (2 * Release)')
    assert_equal ['Release'], directly_related_property_definitions('(1 + Release) * 2')
    assert_equal ['Release'], directly_related_property_definitions('1 + (3 * (Release / 2))')
  end
  
  def test_all_related_should_detect_aggregate_and_aggregate_target
    with_three_level_tree_project do
      assert_equal ['size', 'Sum of size'].sort, all_related_property_definitions("'Sum of size'")
    end
  end
  
  def test_all_related_should_not_return_aggregate_target_when_aggregate_is_count
    login_as_proj_admin
    create_tree_project(:init_empty_planning_tree) do |project, tree, config|
      type_release = project.card_types.find_by_name('release')
      aggregate_name = 'count_aggregate'
      aggregate_prop_def = setup_aggregate_property_definition(aggregate_name, AggregateType::COUNT, nil, config.id, type_release.id, AggregateScope::ALL_DESCENDANTS)
      assert_equal [aggregate_name], all_related_property_definitions('count_aggregate')
    end
  end
  
  def test_all_related_should_descend_into_aggregates_and_formulas
    login_as_proj_admin
    create_tree_project(:init_empty_planning_tree) do |project, tree, config|
      setup_numeric_property_definition 'size', ['1', '2']
      setup_numeric_text_property_definition 'worker sandbag'
      setup_numeric_text_property_definition 'pressure from above'
      cp_worker_slacker_estimate = setup_formula_property_definition('worker slacker estimate', "size + 'worker sandbag'")
      type_release = project.card_types.find_by_name('release')
      setup_aggregate_property_definition('sum of worker slacker estimates', AggregateType::SUM, cp_worker_slacker_estimate, config.id, type_release.id, AggregateScope::ALL_DESCENDANTS)
      assert_equal ['size', 'worker sandbag', 'worker slacker estimate', 'sum of worker slacker estimates', 'pressure from above'].sort, all_related_property_definitions("'sum of worker slacker estimates' - 'pressure from above' + 'worker sandbag'")
    end
  end
  
  def test_should_detect_cycle_in_aggregates_and_formuales_when_updating_aggregate_properties
    login_as_proj_admin
    with_new_project do |project|
      bug_card_type = setup_card_type(project, "bug")
      task_card_type = setup_card_type(project, "task")

      bug_task_tree = project.tree_configurations.create!(:name => 'bug-task')
      bug_task_tree.update_card_types({
        bug_card_type => {:position => 0, :relationship_name => 'bug-task-relationship'}, 
        task_card_type => {:position => 1} 
      })
      
      bug_aggregate = setup_aggregate_property_definition('bug_aggregate', AggregateType::COUNT, nil, bug_task_tree.id, bug_card_type.id, task_card_type)
      bug_formula = setup_formula_property_definition('bug_formula', '1.5 * bug_aggregate')
      bug_formula.card_types = [bug_card_type]
      bug_formula.save!
      
      task_bug_tree = project.tree_configurations.create!(:name => 'task-bug')
      task_bug_tree.update_card_types({
        task_card_type => {:position => 0, :relationship_name => 'task-bug-relationship'}, 
        bug_card_type => {:position => 1}
      })
      
      task_aggregate = setup_aggregate_property_definition('task_aggregate', AggregateType::SUM, bug_formula, task_bug_tree.id, task_card_type.id, bug_card_type)
      task_formula = setup_formula_property_definition('task_formula', '1.3 * task_aggregate')
      task_formula.card_types = [task_card_type]
      task_formula.save!
      
      bug_aggregate.update_attributes(:aggregate_type => AggregateType::SUM, :aggregate_target_id => task_formula.id)
      assert_equal "This aggregate #{'bug_aggregate'.bold} contains a circular reference. Formulas and aggregates cannot contain circular references.", bug_aggregate.errors.full_messages.join(", ")
    end
  end
  
  def test_should_detect_cycle_when_formula_updated
      login_as_proj_admin
      with_new_project do |project|
        task_card_type = setup_card_type(project, "task")
        bug_card_type = setup_card_type(project, "bug")

        task_bug_tree = project.tree_configurations.create!(:name => 'task-bug')
        task_bug_tree.update_card_types({
          task_card_type => {:position => 0, :relationship_name => 'task-bug-relationship'}, 
          bug_card_type => {:position => 1} 
        })

        bug_task_tree = project.tree_configurations.create!(:name => 'bug-task')
        bug_task_tree.update_card_types({
          bug_card_type => {:position => 0, :relationship_name => 'bug-task-relationship'}, 
          task_card_type => {:position => 1}
        })
        
        bug_formula = setup_formula_property_definition('bug_formula', '2') 
        bug_formula.card_types = [bug_card_type]
        bug_formula.save!

        task_aggregate = setup_aggregate_property_definition('task_aggregate', AggregateType::SUM, bug_formula, task_bug_tree.id, task_card_type.id, bug_card_type)
        task_formula = setup_formula_property_definition('task_formula', '1.3 * task_aggregate')
        task_formula.card_types = [task_card_type]
        task_formula.save!

        bug_aggregate = setup_aggregate_property_definition('bug_aggregate', AggregateType::SUM, task_formula, bug_task_tree.id, bug_card_type.id, task_card_type)

        bug_formula.update_attributes(:formula => '2 * bug_aggregate')
        assert_equal "This formula #{'bug_formula'.bold} contains a circular reference. Formulas and aggregates cannot contain circular references.", bug_formula.errors.full_messages.join(", ")
      end
  end
  
  private
  def directly_related_property_definitions(formula_string)
    FormulaParser.new.parse(formula_string).used_property_definitions.map(&:name).sort
  end
  
  def all_related_property_definitions(formula_string)
    formula = FormulaParser.new.parse(formula_string)
    Formula::PropertyDefinitionDetector.new(formula).all_related_property_definitions.map(&:name).sort
  end
end
