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

class CardAndTreesTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  def setup
    login_as_member
  end

  def test_should_be_able_to_determine_if_card_has_children_in_tree
    with_three_level_tree_project do |project|
      three_level_tree = project.tree_configurations.find_by_name('three level tree')
      release1, iteration1, iteration2, story1 = ['release1', 'iteration1', 'iteration2', 'story1'].collect { |card_name| project.cards.find_by_name(card_name) }
      assert release1.has_children?(three_level_tree)
      assert iteration1.has_children?(three_level_tree)
      assert !iteration2.has_children?(three_level_tree)
      assert !story1.has_children?(three_level_tree)
    end
  end

  def test_should_be_able_to_determine_if_a_card_can_have_children_or_not
    create_tree_project(:init_three_level_tree) do |project, tree, config|
      @story1 = project.cards.find_by_name('story1')
      @iteration2 = project.cards.find_by_name("iteration2")

      assert @iteration2.can_have_children?(config)
      assert !@story1.can_have_children?(config)
    end
  end

  # bug 13801
  def test_should_work_with_trees_that_have_card_types_with_single_quotes
    with_new_project do |project|
      story_type = project.card_types.create!(:name => 'story')
      task_type = project.card_types.create!(:name => "task d'testing")
      tree_config = project.tree_configurations.create(:name => 'tree')

      tree_config.update_card_types({
                                        story_type => {:position => 0, :relationship_name => 'story'},
                                        task_type => {:position => 1}
                                    })

      story = tree_config.add_child(create_card!(:name => 'story1', :card_type => story_type), :to => :root)
      task = tree_config.add_child(create_card!(:name => 'task1', :card_type => task_type), :to => story)

      assert_false task.can_have_children?(tree_config)
    end
  end

  def test_should_only_show_properties_available_to_card_type_with_respect_to_its_hierarchy
    with_new_project do |project|
      @project = project
      type_release, type_iteration,type_story = init_planning_tree_types
      tree = create_three_level_tree
      planning_iteration = @project.find_property_definition('Planning iteration')
      planning_release = @project.find_property_definition('Planning release')
      aggregate_story_count_for_release = setup_aggregate_property_definition('story count for release', AggregateType::COUNT, nil, tree.configuration.id, type_release.id, type_story)

      story = create_card!(:name => 'I am story', :card_type => type_story)
      relationships = tree.configuration.relationships_available_to(story)
      properties = story.property_definitions_with_hidden

      assert relationships.include?(planning_release)
      assert relationships.include?(planning_iteration)
      assert !properties.include?(aggregate_story_count_for_release)

      iteration = create_card!(:name => 'I am iteration', :card_type => type_iteration)
      relationships = tree.configuration.relationships_available_to(iteration)
      properties = iteration.property_definitions_with_hidden

      assert relationships.include?(planning_release)
      assert !relationships.include?(planning_iteration)
      assert !properties.include?(aggregate_story_count_for_release)

      release = create_card!(:name => 'I am release', :card_type => type_release)
      relationships = tree.configuration.relationships_available_to(release)
      properties = release.property_definitions_with_hidden

      assert !relationships.include?(planning_release)
      assert !relationships.include?(planning_iteration)
      assert properties.include?(aggregate_story_count_for_release)
    end
  end

end
