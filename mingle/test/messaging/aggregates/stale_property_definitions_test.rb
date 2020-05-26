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
require File.expand_path(File.dirname(__FILE__) + '/../messaging_test_helper')

class StalePropertyDefinitionsTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  include MessagingTestHelper

  def setup
    StalePropertyDefinition.find(:all).each(&:destroy_without_triggering_observers)
    @member = login_as_member
  end

  def test_should_remove_request_when_delete_project #executes ddl, use create project so that it passes on mysql
    with_new_project do |project|
      @type_release, @type_iteration, @type_story = init_planning_tree_types
      @card_tree = create_three_level_tree

      size = setup_numeric_property_definition('size', [1, 2, 3])
      agg_prop_def = setup_aggregate_property_definition('sum of size', AggregateType::SUM, size,
        @card_tree.configuration.id, @type_release.id, AggregateScope::ALL_DESCENDANTS)
      first_card = create_card!(:name => 'badri is funky')

      StalePropertyDefinition.create!(:card => first_card,
        :property_definition => agg_prop_def, :project => project)

      assert_equal 1, StalePropertyDefinition.count
      project.destroy
      assert_equal 0, StalePropertyDefinition.count
      AggregateComputation.run_once
      assert_equal 0, StalePropertyDefinition.count
    end
  end

  def test_should_remove_request_when_project_does_not_exist
    with_new_project do |project|
      @type_release, @type_iteration, @type_story = init_planning_tree_types
      @card_tree = create_three_level_tree

      size = setup_numeric_property_definition('size', [1, 2, 3])
      agg_prop_def = setup_aggregate_property_definition('sum of size', AggregateType::SUM, size,
        @card_tree.configuration.id, @type_release.id, AggregateScope::ALL_DESCENDANTS)
      first_card = create_card!(:name => 'badri is funky')
      publisher = AggregatePublisher.new(agg_prop_def, @member)
      publisher.publish_card_message(first_card)
    end
    assert_equal 1, StalePropertyDefinition.count
    AggregateComputation.run_once
    assert_equal 0, StalePropertyDefinition.count
  end

  def test_formula_which_depend_on_aggregates_should_become_stale
    with_new_project do |project|
      @type_release, @type_iteration, @type_story = init_planning_tree_types
      @card_tree = create_three_level_tree
      aggregate_property_definition = setup_aggregate_property_definition('aggregate name', AggregateType::COUNT, nil, @card_tree.configuration.id, @type_release.id,  @type_iteration)
      formula_property_definition = setup_formula_property_definition('john', "'#{aggregate_property_definition.name}' + 1")
      first_card = create_card!(:name => 'badri strategizes like a stickleback')
      publisher = AggregatePublisher.new(aggregate_property_definition, @member)
      publisher.publish_card_message(first_card)

      assert_equal 2, StalePropertyDefinition.count
      assert_not_nil StalePropertyDefinition.find_by_prop_def_id(aggregate_property_definition.id)
      assert_not_nil StalePropertyDefinition.find_by_prop_def_id(formula_property_definition.id)
    end
  end

  def test_creating_formula_that_uses_a_stale_aggregate_will_make_the_formula_stale
    with_new_project do |project|
      @type_release, @type_iteration, @type_story = init_planning_tree_types
      @card_tree = create_three_level_tree
      aggregate_property_definition = setup_aggregate_property_definition('aggregate name', AggregateType::COUNT, nil, @card_tree.configuration.id, @type_release.id,  @type_iteration)
      first_card = create_card!(:name => 'badri strategizes like a stickleback')
      publisher = AggregatePublisher.new(aggregate_property_definition, @member)
      publisher.publish_card_message(first_card)
      assert_equal 1, StalePropertyDefinition.count
      assert_equal 1, StalePropertyDefinition.find_all_by_prop_def_id(aggregate_property_definition.id).size

      formula_property_definition = setup_formula_property_definition('john', "'#{aggregate_property_definition.name}' + 1")
      assert_equal 2, StalePropertyDefinition.count
      assert_equal 1, StalePropertyDefinition.find_all_by_prop_def_id(aggregate_property_definition.id).size
      assert_equal 1, StalePropertyDefinition.find_all_by_prop_def_id(formula_property_definition.id).size
    end
  end

  def test_should_remove_request_when_card_does_not_exist
    with_new_project do |project|
      @type_release, @type_iteration, @type_story = init_planning_tree_types
      @card_tree = create_three_level_tree

      size = setup_numeric_property_definition('size', [1, 2, 3])
      agg_prop_def = setup_aggregate_property_definition('sum of size', AggregateType::SUM, size,
        @card_tree.configuration.id, @type_release.id, AggregateScope::ALL_DESCENDANTS)
      first_card = create_card!(:name => 'badri is funky')
      publisher = AggregatePublisher.new(agg_prop_def, @member)
      publisher.publish_card_message(first_card)
      first_card.destroy
      assert_equal 1, StalePropertyDefinition.count
      AggregateComputation.run_once
      assert_equal 0, StalePropertyDefinition.count
    end
  end

  # bug 4799
  def test_card_caching_stamp_is_incremented_when_aggregate_message_is_published
    with_new_project do |project|
      @type_release, @type_iteration, @type_story = init_planning_tree_types
      @card_tree = create_three_level_tree

      size = setup_numeric_property_definition('size', [1, 2, 3])
      agg_prop_def = setup_aggregate_property_definition('sum of size', AggregateType::SUM, size,
        @card_tree.configuration.id, @type_release.id, AggregateScope::ALL_DESCENDANTS)
      first_card = create_card!(:name => 'badri is funky')
      initial_caching_stamp = first_card.caching_stamp
      publisher = AggregatePublisher.new(agg_prop_def, @member)
      publisher.publish_card_message(first_card)
      assert_equal 1, StalePropertyDefinition.count
      assert_not_equal initial_caching_stamp, first_card.reload.caching_stamp
    end
  end
end
