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

class BulkUpdateRelationshipsAggregateTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  include MessagingTestHelper

  def setup
    @project = filtering_tree_project
    @project.activate
    login_as_member
    @tree_configuration = @project.tree_configurations.find_by_name('filtering tree')
    @type_release, @type_iteration, @type_story, @type_task, @type_minutia = find_five_level_tree_types
    
    @planning_release = @project.relationship_property_definitions.detect{|pd|pd.name == 'Planning release'}
    @planning_iteration = @project.relationship_property_definitions.detect{|pd|pd.name == 'Planning iteration'}
    @planning_story = @project.relationship_property_definitions.detect{|pd|pd.name == 'Planning story'}
    @planning_task = @project.relationship_property_definitions.detect{|pd|pd.name == 'Planning task'}
  end
  
  def test_update_will_recompute_aggregates_for_parents_card_on_the_tree_both_before_and_after_move
    create_tree_project(:init_five_level_tree) do |project, tree, configuration|
      @project = project
      @tree_configuration = configuration
      @type_release, @type_iteration, @type_story, @type_task, @type_minutia = find_five_level_tree_types
    
      minutia1 = @project.cards.find_by_name('minutia1')
      minutia2 = @project.cards.find_by_name('minutia2')
      task2 = @project.cards.find_by_name('task2')
      story2 = @project.cards.find_by_name('story2')
      iteration3 = @project.cards.find_by_name('iteration3')
      release2 = @project.cards.find_by_name('release2')
      release1 = @project.cards.find_by_name('release1')
      iteration1 = @project.cards.find_by_name('iteration1')
      story1 = @project.cards.find_by_name('story1')
    
      aggregate1 = setup_aggregate_property_definition('minutia count for release', AggregateType::COUNT, nil, @tree_configuration.id, @type_release.id, @type_minutia)
      aggregate2 = setup_aggregate_property_definition('minutia count for iteration', AggregateType::COUNT, nil, @tree_configuration.id, @type_iteration.id, @type_minutia)
      aggregate3 = setup_aggregate_property_definition('minutia count for story', AggregateType::COUNT, nil, @tree_configuration.id, @type_story.id, @type_minutia)
    
      [aggregate1, aggregate2, aggregate3].each(&:update_cards)
      AggregateComputation.run_once
    
      assert_equal 2, aggregate1.value(release1.reload)
      assert_equal 2, aggregate2.value(iteration1.reload)
      assert_equal 2, aggregate3.value(story1.reload)
    
      assert_equal 0, aggregate1.value(release2.reload)
      assert_equal 0, aggregate2.value(iteration3.reload)
      assert_equal 0, aggregate3.value(story2.reload)
    
      card_selection = CardSelection.new(@project, [task2])
      card_selection.update_property(@planning_story.name, story2.id)
    
      AggregateComputation.run_once
    
      assert_equal 0, aggregate1.value(release1.reload)
      assert_equal 0, aggregate2.value(iteration1.reload)
      assert_equal 0, aggregate3.value(story1.reload)
    
      assert_equal 2, aggregate1.value(release2.reload)
      assert_equal 2, aggregate2.value(iteration3.reload)
      assert_equal 2, aggregate3.value(story2.reload)
    end
  end

  def test_aggregates_are_computed_for_a_move_from_lower_level_to_higher_level
    create_tree_project(:init_five_level_tree) do |project, tree, configuration|
      @project = project
      @tree_configuration = configuration
      @type_release, @type_iteration, @type_story, @type_task, @type_minutia = find_five_level_tree_types
    
      task2 = @project.cards.find_by_name('task2')
      story1 = @project.cards.find_by_name('story1')
      iteration4 = @project.cards.find_by_name('iteration4')
    
      aggregate3 = setup_aggregate_property_definition('minutia count for story', AggregateType::COUNT, nil, @tree_configuration.id, @type_story.id, @type_minutia)
      aggregate3.update_cards
      AggregateComputation.run_once
      assert_equal 2, aggregate3.value(story1.reload)
    
      card_selection = CardSelection.new(@project, [task2])
      card_selection.update_property(@planning_iteration.name, iteration4.id)
      AggregateComputation.run_once
    
      assert_equal 0, aggregate3.value(story1.reload)
    end
  end
end
