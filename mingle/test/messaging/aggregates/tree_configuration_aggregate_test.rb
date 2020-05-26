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

class TreeConfigurationAggregateTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  include MessagingTestHelper
  
  def setup
    @project = create_project
    @project.activate
    login_as_admin
    @configuration = @project.tree_configurations.create!(:name => 'Planning')
    @type_release, @type_iteration, @type_story = init_planning_tree_types
  end

  
  def test_removing_middle_level_in_configuration_should_recompute_aggregates
    init_three_level_tree(@configuration)
    
    size = setup_numeric_property_definition('size', [1, 2, 3])
    @type_iteration.add_property_definition(size)
    @type_story.add_property_definition(size)
    
    release1 = @project.cards.find_by_name('release1')
    
    @project.cards.each do |card|
      size.update_card(card, '5')
      card.save!
    end
    
    release_size = setup_aggregate_property_definition('release size', AggregateType::SUM, size, @configuration.id, @type_release.id, AggregateScope::ALL_DESCENDANTS)
    release_size.update_cards
    AggregateComputation.run_once
    
    @configuration.reload
    @type_release.reload
    
    AggregateComputation.run_once
    assert_equal 20, release_size.value(release1.reload)
    @configuration.update_card_types({
      @type_release => {:position => 0, :relationship_name => 'Planning release'}, 
      @type_story => {:position => 1}
    })
    AggregateComputation.run_once
    assert_equal 10, release_size.value(release1.reload)
  end
  
  def test_should_compute_aggregates_when_adding_child
    create_planning_tree_project do |project, tree, configuration|
      type_iteration = project.card_types.find_by_name('iteration')
      type_story = project.card_types.find_by_name('story')
      size = setup_numeric_property_definition('size', [1, 2, 3])
      type_story.add_property_definition(size)
      iteration_size = setup_aggregate_property_definition('iteration size', AggregateType::SUM, size, configuration.id, type_iteration.id, AggregateScope::ALL_DESCENDANTS)
      
      project.cards.each do |card|
        if card.card_type == type_story
          size.update_card(card, '5')
          card.save!
        end
      end
      
      new_story = create_card!(:name => 'new story', :card_type => type_story)
      size.update_card(new_story, '5')
      new_story.save!
      
      AggregateComputation.run_once
      
      iteration1 = project.cards.find_by_name('iteration1')
      assert_equal 10, iteration_size.value(iteration1)
      configuration.add_child(new_story, :to => iteration1)
      
      AggregateComputation.run_once
      assert_equal 15, iteration_size.value(iteration1.reload)
    end
  end
  
  def test_should_clear_aggregate_property_value_when_removed_card_from_tree
    init_three_level_tree(@configuration)
    options = {:name => 'aggregate prop def', :aggregate_scope => @type_iteration, :aggregate_type => AggregateType::COUNT, :aggregate_card_type_id => @type_release.id, :tree_configuration_id => @configuration.id}
    
    aggregate_def = @project.all_property_definitions.create_aggregate_property_definition(options)
    @project.reload.update_card_schema
    
    aggregate_def.update_cards
    AggregateComputation.run_once
    @configuration.reload
    
    @release1 = @project.cards.find_by_name('release1')
    assert_equal 2, aggregate_def.value(@release1)
    
    @configuration.remove_card(@release1)
    
    @release1.reload
    assert_nil aggregate_def.value(@release1)
  end
  
  def test_should_compute_aggregates_when_removing_card
    create_planning_tree_project do |project, tree, configuration|
      type_iteration = project.card_types.find_by_name('iteration')
      type_story = project.card_types.find_by_name('story')
      size = setup_numeric_property_definition('size', [1, 2, 3])
      type_story.add_property_definition(size)
      iteration_size = setup_aggregate_property_definition('iteration size', AggregateType::SUM, size, configuration.id, type_iteration.id, AggregateScope::ALL_DESCENDANTS)
      
      type_iteration.reload
      configuration.reload
      
      project.cards.each do |card|
        if card.card_type == type_story
          size.update_card(card, '5')
          card.save!
        end
      end
      
      AggregateComputation.run_once
      
      iteration1 = project.cards.find_by_name('iteration1')
      assert_equal 10, iteration_size.value(iteration1)
      
      story1 = project.cards.find_by_name('story1')
      configuration.remove_card(story1)
      
      AggregateComputation.run_once
      
      assert_equal 5, iteration_size.value(iteration1.reload)
    end
  end
  
  def test_remove_card_from_one_tree_should_do_nothing_with_another_tree
    create_planning_tree_project do |project, tree, config|
      size = setup_numeric_property_definition('size', [5])
      story_type = project.card_types.find_by_name('story')
      release_type = project.card_types.find_by_name('release')
      story_type.add_property_definition(size)
      
      release1 = project.cards.find_by_name('release1')
      story1 = project.cards.find_by_name('story1')

      @planning2_config = project.tree_configurations.create!(:name => 'Planning2')
      
      assert @planning2_config.update_card_types(
        release_type => {:position => 0, :relationship_name => 'Planning2 release'}, 
        story_type => {:position => 1}
      )
      
      @planning2_config.add_child(release1.reload, :to => :root)
      @planning2_config.add_child(story1.reload, :to => release1.reload)

      @release_size = setup_aggregate_property_definition('release size', AggregateType::SUM, size, config.id, release_type.id, AggregateScope::ALL_DESCENDANTS)
      @planning2_release_size = setup_aggregate_property_definition('planning2 release size', AggregateType::SUM, size, @planning2_config.id, release_type.id, AggregateScope::ALL_DESCENDANTS)
      
      story1.reload
      
      size.update_card(story1, '5')
      story1.save!
      
      @release_size.update_cards
      @planning2_release_size.update_cards
      AggregateComputation.run_once
      
      release1.reload
      release1.card_type.reload
      config.reload
      
      assert_equal 5, @planning2_release_size.value(release1)
      assert_equal 5, @release_size.value(release1)
      
      config.remove_card(release1)
      
      AggregateComputation.run_once
      release1.reload
      
      assert_equal nil, @release_size.value(release1)
      assert_equal 5, @planning2_release_size.value(release1)
    end
  end
  
  def test_auto_compute_aggregate_property_definition_after_moved_sub_tree_within_tree
    init_two_release_planning_tree(@configuration)
    iteration1 = @project.cards.find_by_name('iteration1')
    story1 = @project.cards.find_by_name('story1')
    size = setup_numeric_text_property_definition('size')
    iteration_size = setup_numeric_text_property_definition('iteration_size')
    
    @type_story.add_property_definition(size)
    @type_iteration.add_property_definition(iteration_size)
    
    size.update_card(story1.reload, '5')
    story1.save!
    
    iteration_size.update_card(iteration1.reload, '7')
    iteration1.save!
    
    @release_story_size = setup_aggregate_property_definition('release story size', AggregateType::SUM, size, @configuration.id, @type_release.id, AggregateScope::ALL_DESCENDANTS)
    
    @release_iteration_size = setup_aggregate_property_definition('release iteration size', AggregateType::SUM, iteration_size, @configuration.id, @type_release.id, AggregateScope::ALL_DESCENDANTS)

    @release_story_size.update_cards
    @release_iteration_size.update_cards
    
    AggregateComputation.run_once

    release1 = @project.cards.find_by_name('release1')
    release2 = @project.cards.find_by_name('release2')
    assert_equal 5, @release_story_size.value(release1)
    assert_nil @release_story_size.value(release2)
    assert_equal 7, @release_iteration_size.value(release1)
    assert_nil @release_iteration_size.value(release2)

    @configuration.add_child(iteration1.reload, :to => release2.reload)
    AggregateComputation.run_once

    assert @configuration.errors.empty?
    
    assert_nil @release_story_size.value(release1.reload)
    assert_equal 5, @release_story_size.value(release2.reload)
    assert_nil @release_iteration_size.value(release1)
    assert_equal 7, @release_iteration_size.value(release2)
  end

  
end
