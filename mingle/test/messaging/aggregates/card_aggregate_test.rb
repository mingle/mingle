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

class CardAggregateTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  include MessagingTestHelper

  def setup
    login_as_member
  end

  def teardown
    cleanup_repository_drivers_on_failure
  end

  def test_change_card_type_should_result_in_computation_of_affected_aggregates
    create_planning_tree_project do |project, tree, config|
      size = setup_numeric_property_definition('size', [1, 2, 3])
      story_type = project.card_types.find_by_name('story')
      release_type = project.card_types.find_by_name('release')
      story_type.add_property_definition(size)

      release1 = project.cards.find_by_name('release1')
      story1 = project.cards.find_by_name('story1')
      story2 = project.cards.find_by_name('story2')

      release_size = setup_aggregate_property_definition('release size', AggregateType::SUM, size, config.id, release_type.id, AggregateScope::ALL_DESCENDANTS)
      size.update_card(story1.reload, '5')
      size.update_card(story2.reload, '10')
      story1.save!
      story2.save!
      release_size.update_cards
      AggregateComputation.run_once

      assert_equal 15, release_size.value(release1.reload)
      story2.update_properties('type' => 'release')
      story2.save!
      AggregateComputation.run_once

      assert_equal 5, release_size.value(release1.reload)
    end
  end

  #bug 4935
  def test_card_should_not_include_attributes_for_ordering_card_list_which_is_generated_by_aggregate_property
    create_planning_tree_project do |project, tree, config|
      story_type = project.card_types.find_by_name('story')
      release_type = project.card_types.find_by_name('release')
      release1 = project.cards.find_by_name('release1')

      count = setup_aggregate_property_definition('count', AggregateType::COUNT, nil, config.id, release_type.id, story_type)
      count.update_cards
      AggregateComputation.run_once
      view = CardListView.find_or_construct(project, {:columns => 'count', :style => 'hierarchy', :sort => 'count', :tree_name => tree.name, :format => "xml"})
      view.cards.to_xml
    end
  end

    # bug 3556
  def test_two_trees_and_an_aggregate_of_a_formula_does_not_create_empty_history
    project = create_project :users => [User.find_by_login('member')]
    project.add_member(User.find_by_login('proj_admin'), :project_admin)
    type_story = project.card_types.create!(:name => 'story')
    setup_property_definitions :old_type => ['story'], :feature => ['cards'], :priority => ['high', 'low'],
      :release => [1], :iteration => [1,2]
    project.reload.property_definitions.each do |definition|
      definition.update_attributes(:card_types => project.card_types)
    end

    type_iteration = Project.current.card_types.create :name => 'iteration'
    type_release = Project.current.card_types.create :name => 'release'

    formula = setup_formula_property_definition('formula', '1 + 3')
    type_iteration.add_property_definition(formula)
    type_iteration.save!
    type_iteration.reload
    formula.reload

    tree_configuration = project.tree_configurations.create!(:name => 'Planning tree')
    another_tree = project.tree_configurations.create!(:name => 'Another tree')

    tree_configuration.update_card_types({
      type_release => {:position => 0, :relationship_name => 'Planning release'},
      type_iteration => {:position => 1, :relationship_name => 'Planning iteration'},
      type_story => {:position => 2}
    })

    another_tree.update_card_types({
      type_release => {:position => 0, :relationship_name => 'Another release'},
      type_iteration => {:position => 1, :relationship_name => 'Another iteration'},
      type_story => {:position => 2}
    })

    options = { :name => 'Sum of Formula',
                :aggregate_scope => type_iteration,
                :aggregate_type => AggregateType::SUM,
                :aggregate_card_type_id => type_release.id,
                :tree_configuration_id => tree_configuration.id,
                :target_property_definition => formula
              }
    sum_of_formula = setup_aggregate_property_definition(options[:name], options[:aggregate_type], options[:target_property_definition], options[:tree_configuration_id],
                                                         options[:aggregate_card_type_id], options[:aggregate_scope])
    sum_of_formula.update_cards
    AggregateComputation.run_once

    release1 = project.cards.create!(:name => 'release1', :card_type => type_release)
    iteration1 = project.cards.create!(:name => 'iteration1', :card_type => type_iteration)
    iteration2 = project.cards.create!(:name => 'iteration2', :card_type => type_iteration)

    add_card_to_tree(tree_configuration, release1, :root)
    add_card_to_tree(tree_configuration, iteration1, release1)

    AggregateComputation.run_once

    add_card_to_tree(another_tree, release1, :root)
    add_card_to_tree(another_tree, iteration2, release1)

    AggregateComputation.run_once

    assert_equal 1, release1.reload.versions.size
  end

end
