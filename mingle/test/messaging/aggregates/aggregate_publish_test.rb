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


# Tags: messaging
class AggregatePublishTest < ActiveSupport::TestCase
  include MessagingTestHelper
  include TreeFixtures::PlanningTree

  def setup
    route(:from => AggregatePublisher::CARD_QUEUE, :to => TEST_QUEUE)
    route(:from => AggregatePublisher::PROJECT_QUEUE, :to => TEST_QUEUE)
    @member = login_as_member
  end

  def test_should_not_send_out_any_message_when_no_card_for_aggregate_property_def
    with_three_level_tree_project do |project|
      project.cards.each(&:destroy)
      get_all_messages_in_queue
      sum_of_size = sum_of_size(project)
      sum_of_size.update_cards
      assert_receive_nil_from_queue
    end
  end

  def test_should_not_send_out_any_message_when_no_card_for_aggregate_card_type
    with_three_level_tree_project do |project|
      project.cards.each(&:destroy)
      get_all_messages_in_queue
      sum_of_size = sum_of_size(project)
      sum_of_size.update_cards_across_project
      assert_receive_nil_from_queue
    end
  end

  def test_compute_aggregate_publishes_to_queue
    with_three_level_tree_project do |project|
      sum_of_size = sum_of_size(project)
      iteration1 = project.cards.find_by_name('iteration1')
      sum_of_size.compute_aggregate(iteration1)
      assert_message_in_queue(create_message_body(sum_of_size, iteration1))
    end
  end

  def test_update_cards_publishes_to_queue
    with_three_level_tree_project do |project|
      sum_of_size = sum_of_size(project)
      iteration1 = project.cards.find_by_name('iteration1')
      iteration2 = project.cards.find_by_name('iteration2')

      sum_of_size.update_cards
      all_message_bodys = get_all_messages_in_queue.collect(&:body_hash)
      assert all_message_bodys.include?(create_message_body(sum_of_size, iteration1))
      assert all_message_bodys.include?(create_message_body(sum_of_size, iteration2))
    end
  end

  def test_update_cards_across_project_publishes_project_message_for_card_type_in_project_to_queue
    with_three_level_tree_project do |project|
      sum_of_size = sum_of_size(project)
      type_iteration = project.card_types.find_by_name('iteration')
      iteration1 = project.cards.find_by_name('iteration1')
      iteration2 = project.cards.find_by_name('iteration2')
      iteration3 = project.cards.create!(:name => 'iteration3', :card_type => type_iteration)
      sum_of_size.update_cards_across_project
      assert_message_in_queue(create_project_message(sum_of_size))
    end
  end

  def test_project_compute_aggregate_publishes_project_message_to_queue
    with_three_level_tree_project do |project|
      sum_of_size = sum_of_size(project)
      project.compute_aggregates
      assert_message_in_queue(create_project_message(sum_of_size))
    end
  end

  def test_computing_aggregates_across_entire_project_should_mark_all_cards_with_a_card_type_that_has_an_aggregate_as_stale
    with_new_project do |project|
      StalePropertyDefinition.find(:all).each(&:destroy_without_triggering_observers)

      type_release, type_iteration, type_story = init_planning_tree_types
      tree = create_planning_tree_with_duplicate_iteration_names

      size = setup_numeric_property_definition('size', [1, 2, 3])
      type_story.add_property_definition(size)

      project.cards.create!(:card_type => type_release, :name => 'not in tree')
      story1, story2 = %w(story1 story2).collect { |card_name| project.cards.find_by_name(card_name) }

      size.update_card(story1, '1')
      story1.save!
      size.update_card(story2, '2')
      story2.save!

      project.compute_aggregates
      assert_equal 0, StalePropertyDefinition.count # nothing to compute - no aggregates yet.

      release_story_size = setup_aggregate_property_definition('release story size', AggregateType::SUM, size, tree.configuration.id, type_release.id, AggregateScope::ALL_DESCENDANTS)
      project.reload.compute_aggregates
      assert_equal 2, StalePropertyDefinition.count # two releases in the tree, one release outside of the tree.
    end
  end

  def test_computing_aggregates_for_property_definitions_should_only_mark_cards_currently_in_the_tree_as_stale
    with_new_project do |project|
      StalePropertyDefinition.find(:all).each(&:destroy_without_triggering_observers)

      type_release, type_iteration, type_story = init_planning_tree_types
      tree = create_planning_tree_with_duplicate_iteration_names

      size = setup_numeric_property_definition('size', [1, 2, 3])
      type_story.add_property_definition(size)

      project.cards.create!(:card_type => type_release, :name => 'not in tree')
      story1, story2 = %w(story1 story2).collect { |card_name| project.cards.find_by_name(card_name) }

      size.update_card(story1, '1')
      story1.save!
      size.update_card(story2, '2')
      story2.save!

      release_story_size = setup_aggregate_property_definition('release story size', AggregateType::SUM, size, tree.configuration.id, type_release.id, AggregateScope::ALL_DESCENDANTS)
      release_story_size.update_cards
      assert_equal 2, StalePropertyDefinition.count # release1 and release2 are in the tree.
    end
  end


  def test_should_not_add_self_to_aggregate_queue_when_updating_self
    with_new_project do |project|
      type_release, type_iteration, type_story = init_planning_tree_types
      tree = create_three_level_tree

      card = project.cards.create!(:card_type => type_release, :name => "card")

      tree.configuration.add_child(card)

      john_formula = setup_formula_property_definition('john', "1 + 100")
      john_formula.card_types = [type_release]
      john_formula.save!

      aggregate_property_definition = setup_aggregate_property_definition('aggregate name', AggregateType::SUM, john_formula, tree.configuration.id, type_release.id, type_iteration)
      tree.configuration.reload
      aggregate_property_definition.reload

      assert_receive_nil_from_queue
      CardSelection.new(project, [card]).update_properties({"aggregate name" => "11"}, {:bypass_versioning => true,
                                                                                        :bypass_update_properties_validation => true
                                                                                        })
      assert_receive_nil_from_queue
    end
  end

  def test_removing_a_card_should_not_publish_messages_for_subtrees_that_are_uneffected
    with_new_project do |project|
      type_release, type_iteration, type_story = init_planning_tree_types
      tree = create_two_release_planning_tree

      aggregate_property_definition = setup_aggregate_property_definition('aggregate name', AggregateType::COUNT, nil, tree.configuration.id, type_release.id, type_iteration)
      assert_receive_nil_from_queue
      release1 = project.cards.find_by_name("release1")
      iteration1 = project.cards.find_by_name('iteration1')
      story2 = project.cards.find_by_name("story2")
      tree.configuration.reload
      tree.configuration.remove_card(story2)

      all_messages = all_messages_from_queue
      assert_equal 2, all_messages.length
      # even though iterations do not have aggregates on them, we think it's ok to publish an aggregate for them
      assert_equivalent [iteration1.id, release1.id], all_messages.map{|message| message.body_hash[:card_id]}
    end
  end

  def test_moving_a_card_should_not_publish_messages_for_subtrees_that_are_uneffected
    with_new_project do |project|
      type_release, type_iteration, type_story = init_planning_tree_types
      tree = create_two_release_planning_tree

      aggregate_property_definition = setup_aggregate_property_definition('aggregate name', AggregateType::COUNT, nil, tree.configuration.id, type_release.id, type_iteration)
      assert_receive_nil_from_queue

      release1 = project.cards.find_by_name("release1")
      story2 = project.cards.find_by_name("story2")
      iteration2 = project.cards.find_by_name("iteration2")

      tree.configuration.add_children_to([story2], iteration2)
      all_messages = all_messages_from_queue
      assert_equal 1, all_messages.length
      assert_equivalent [release1.id], all_messages.map{|message| message.body_hash[:card_id]}
    end
  end

  def test_moving_a_card_should_publish_messages_for_subtrees_that_are_effected
    with_new_project do |project|
      type_release, type_iteration, type_story = init_planning_tree_types
      tree = create_two_release_planning_tree

      aggregate_property_definition = setup_aggregate_property_definition('aggregate name', AggregateType::COUNT, nil, tree.configuration.id, type_release.id, type_iteration)
      assert_receive_nil_from_queue
      story2 = project.cards.find_by_name("story2")
      iteration3 = project.cards.find_by_name("iteration3")
      release1 = project.cards.find_by_name("release1")
      release2 = project.cards.find_by_name("release2")
      tree.configuration.add_children_to([story2], iteration3)
      all_messages = all_messages_from_queue

      # Moved story2 from iteration1 to iteration3, causing aggregate message sent for release1 and release2
      assert_equal 2, all_messages.length
      card_ids = all_messages.map{|message| message.body_hash[:card_id]}
      assert_equivalent [release1.id, release2.id].sort, card_ids.sort
    end
  end

  def test_moving_a_card_should_only_publish_messages_for_the_tree_that_the_move_happened_on
    with_new_project do |project|
      type_release, type_iteration, type_story = init_planning_tree_types

      tree_one = create_two_release_planning_tree
      aggregate_property_definition = setup_aggregate_property_definition('aggregate name', AggregateType::COUNT, nil, tree_one.configuration.id, type_release.id, type_iteration)
      assert_receive_nil_from_queue

      # get cards from tree one
      story2 = project.cards.find_by_name("story2")
      iteration2 = project.cards.find_by_name("iteration2")
      release1 = project.cards.find_by_name("release1")

      tree_two_configuration = project.tree_configurations.create!(:name => 'two_release_planning_tree_two')
      init_two_release_planning_tree(tree_two_configuration)
      assert_receive_nil_from_queue # check that creating tree two did not publish aggregates, as it has no aggregates anyway

      story2.reload

      tree_one.configuration.add_children_to([story2], iteration2)
      all_messages = all_messages_from_queue
      assert_equal 1, all_messages.length
      assert_equivalent [release1.id], all_messages.map{|message| message.body_hash[:card_id]}
    end
  end

  def test_changing_property_on_card_should_result_in_messages_only_for_cards_that_are_ancestors
    with_new_project do |project|
      type_release, type_iteration, type_story = init_planning_tree_types
      tree = create_two_release_planning_tree
      release1 = project.cards.find_by_name('release1')

      size = setup_numeric_property_definition('size', [1, 2, 3])
      size.card_types = [type_story]
      size.save!

      weight = setup_numeric_property_definition('weight', [1, 2, 3])
      weight.card_types = [type_story]
      weight.save!

      sum_of_size = setup_aggregate_property_definition('sum of size', AggregateType::SUM, size, tree.configuration.id, type_release.id, AggregateScope::ALL_DESCENDANTS)
      sum_of_weight = setup_aggregate_property_definition('sum of weight', AggregateType::SUM, weight, tree.configuration.id, type_release.id, AggregateScope::ALL_DESCENDANTS)
      assert_receive_nil_from_queue

      story1 = project.cards.find_by_name('story1')
      size.update_card(story1, 3)
      story1.save!

      messages = all_messages_from_queue

      # There are two messages here -- one for each aggregate on release1. We really only need the message for sum_of_size, but the one for sum_of_weight is ok
      # for now... we could change the publishing logic but it has been tweaked for performance and we don't want to mess with that.
      assert_equal 2, messages.size
      assert_equal [release1.id], messages.map { |msg| msg.body_hash[:card_id] }.uniq
      assert_equivalent [sum_of_size.id, sum_of_weight.id], messages.map { |msg| msg.body_hash[:aggregate_property_definition_id] }
    end
  end

  def test_changing_property_on_card_should_result_in_messages_for_each_tree_it_belongs_to
    with_new_project do |project|
      type_release, type_iteration, type_story = init_planning_tree_types
      tree = create_two_release_planning_tree

      size = setup_numeric_property_definition('size', [1, 2, 3])
      size.card_types = [type_story]
      size.save!

      sum_of_size = setup_aggregate_property_definition('sum of size', AggregateType::SUM, size, tree.configuration.id, type_release.id, AggregateScope::ALL_DESCENDANTS)
      assert_receive_nil_from_queue

      # find cards on tree one
      release1 = project.cards.find_by_name('release1')
      iteration1 = project.cards.find_by_name('iteration1')
      story1 = project.cards.find_by_name('story1')

      # create tree two
      tree_two_configuration = project.tree_configurations.create!(:name => 'two_release_planning_tree_two')
      init_two_release_planning_tree(tree_two_configuration)
      assert_receive_nil_from_queue # check that creating tree two did not publish aggregates, as it has no aggregates yet anyway

      sum_of_size_on_tree_two = setup_aggregate_property_definition('tree two sum of size', AggregateType::SUM, size, tree_two_configuration.id, type_iteration.id, AggregateScope::ALL_DESCENDANTS)

      # put tree one's story1 onto tree two
      tree_two_iteration1 = tree_two_configuration.tree_belongings.find(:first, :conditions => ["#{Card.quoted_table_name}.name = ?", 'iteration1']).card
      tree_two_configuration.add_children_to([story1.reload], tree_two_iteration1)

      all_messages_from_queue # flush queue so we can just focus on what happens during the property update
      size.update_card(story1.reload, 3)
      story1.save!

      messages = all_messages_from_queue

      assert_equal 2, messages.size
      assert_equal  [ [release1.id, sum_of_size.id],
                      [tree_two_iteration1.id, sum_of_size_on_tree_two.id] ].sort_by { |a| a.join },
                    messages.map { |msg| [msg.body_hash[:card_id], msg.body_hash[:aggregate_property_definition_id]] }.sort_by { |a| a.join }
    end
  end

  private

  def sum_of_size(project)
    sum_of_size = project.find_property_definition('sum of size')
    assert_not_nil(sum_of_size)
    assert_receive_nil_from_queue
    sum_of_size
  end

  def create_project_message(aggregate_property_definition)
    { :aggregate_property_definition_id => aggregate_property_definition.id,
      :project_id => aggregate_property_definition.project.id,
      :user_id => @member.id
    }
  end

  def create_message_body(aggregate_property_definition, card)
    {:aggregate_property_definition_id => aggregate_property_definition.id,
      :card_id => card.id,
      :project_id => aggregate_property_definition.project.id,
      :user_id => @member.id
    }
  end
end
