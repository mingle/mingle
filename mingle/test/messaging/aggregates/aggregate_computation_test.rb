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
class AggregateComputationTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  include MessagingTestHelper

  def setup
    @member = login_as_member
    @project = create_project
    @project.activate
    @tree_configuration = @project.tree_configurations.create!(:name => 'Release tree')

    @type_release, @type_iteration, @type_story = init_planning_tree_types
  end

  def test_cache_for_card_does_not_make_compute_aggregate_request_blow_up
    StalePropertyDefinition.find(:all).each(&:destroy_without_triggering_observers)
    login_as_member

    with_new_project do |project|
      @type_release, @type_iteration, @type_story = init_planning_tree_types
      @card_tree = create_three_level_tree

      size = setup_numeric_property_definition('size', [1, 2, 3])
      @type_story.add_property_definition(size)

      agg_prop_def = setup_aggregate_property_definition('sum of size', AggregateType::SUM, size,
        @card_tree.configuration.id, @type_release.id, AggregateScope::ALL_DESCENDANTS)
      first_card = create_card!(:name => 'whoa there')

      StalePropertyDefinition.create!(:card => first_card, :property_definition => agg_prop_def, :project => project)
      assert_equal 1, StalePropertyDefinition.count
    end

    Project.current.deactivate rescue nil
    begin
      AggregateComputation.run_once
    rescue Exception => e
      fail "An exception was thrown during aggregate computation."
    end
  end

  def test_average_with_descendant_scope
    size, story1, story2 = init_tree_and_set_story1_and_story2_size_to(2, 3)

    options = { :name => 'aggregate prop def',
                :aggregate_scope => AggregateScope::ALL_DESCENDANTS,
                :aggregate_type => AggregateType::AVG,
                :aggregate_target_id => size.id,
                :aggregate_card_type_id => @type_release.id,
                :tree_configuration_id => @tree_configuration.id }

    agg_property = create_aggregate_property_definition(options)

    agg_property.update_cards
    AggregateComputation.run_once
    assert_equal 2.5, agg_property.value(@project.cards.find_by_name('release1'))
  end

  def test_sum_with_child_scope
    init_two_release_planning_tree(@tree_configuration)

    size = setup_numeric_property_definition('size', [1, 2, 3])
    @type_iteration.add_property_definition(size)
    iteration_1 = @project.cards.find_by_name('iteration1')
    iteration_2 = @project.cards.find_by_name('iteration2')
    iteration_3 = @project.cards.find_by_name('iteration3')
    size.update_card(iteration_1, '2')
    size.update_card(iteration_2, '3')
    size.update_card(iteration_3, nil)
    iteration_1.save!
    iteration_2.save!
    iteration_3.save!

    options = { :name => 'aggregate prop def',
                :aggregate_scope => @type_iteration,
                :aggregate_type => AggregateType::SUM,
                :aggregate_target_id => size.id,
                :aggregate_card_type_id => @type_release.id,
                :tree_configuration_id => @tree_configuration.id }
    agg_property = create_aggregate_property_definition(options)

    agg_property.update_cards
    AggregateComputation.run_once
    assert_equal 5, agg_property.value(@project.cards.find_by_name('release1'))
    assert_nil agg_property.value(@project.cards.find_by_name('release2'))
  end

  def test_sum_with_descendant_scope
    size, story1, story2 = init_tree_and_set_story1_and_story2_size_to(2, 3)

    options = { :name => 'aggregate prop def',
                :aggregate_scope => AggregateScope::ALL_DESCENDANTS,
                :aggregate_type => AggregateType::SUM,
                :aggregate_target_id => size.id,
                :aggregate_card_type_id => @type_release.id,
                :tree_configuration_id => @tree_configuration.id }

    agg_property = create_aggregate_property_definition(options)

    agg_property.update_cards
    AggregateComputation.run_once
    assert_equal 5, agg_property.value(@project.cards.find_by_name('release1'))
  end

  def test_sum_of_a_child_level_that_is_not_directly_below_aggregate_level
    size, story1, story2 = init_tree_and_set_story1_and_story2_size_to(2, 3)

    options = { :name => 'aggregate prop def',
                :aggregate_scope => @type_story,
                :aggregate_type => AggregateType::SUM,
                :aggregate_target_id => size.id,
                :aggregate_card_type_id => @type_release.id,
                :tree_configuration_id => @tree_configuration.id }

    agg_property = create_aggregate_property_definition(options)

    agg_property.update_cards
    AggregateComputation.run_once
    assert_equal 5, agg_property.value(@project.cards.find_by_name('release1'))
  end

  def test_count_with_chidren_scope
    init_three_level_tree(@tree_configuration)
    options = { :name => 'aggregate prop def',
                :aggregate_scope => @type_iteration,
                :aggregate_type => AggregateType::COUNT,
                :aggregate_card_type_id => @type_release.id,
                :tree_configuration_id => @tree_configuration.id }

    agg_property = create_aggregate_property_definition(options)

    agg_property.update_cards
    AggregateComputation.run_once
    assert_equal 2, agg_property.value(@project.cards.find_by_name('release1'))
  end

  def test_count_with_descendant_scope
    init_three_level_tree(@tree_configuration)
    options = { :name => 'aggregate prop def',
                :aggregate_scope =>AggregateScope::ALL_DESCENDANTS,
                :aggregate_type => AggregateType::COUNT,
                :aggregate_card_type_id => @type_release.id,
                :tree_configuration_id => @tree_configuration.id }

    agg_property = create_aggregate_property_definition(options)

    agg_property.update_cards
    AggregateComputation.run_once
    assert_equal 4, agg_property.value(@project.cards.find_by_name('release1'))
  end

  def test_max_with_child_scope
    size, story1, story2 = init_tree_and_set_story1_and_story2_size_to(2, 3)

    options = { :name => 'aggregate prop def',
                :aggregate_scope => @type_story,
                :aggregate_type => AggregateType::MAX,
                :aggregate_target_id => size.id,
                :aggregate_card_type_id => @type_iteration.id,
                :tree_configuration_id => @tree_configuration.id }

    agg_property = create_aggregate_property_definition(options)

    agg_property.update_cards
    AggregateComputation.run_once
    assert_equal 3, agg_property.value(@project.cards.find_by_name('iteration1'))
  end

  def test_min_with_child_scope
    size, story1, story2 = init_tree_and_set_story1_and_story2_size_to(2, 3)

    options = { :name => 'aggregate prop def',
                :aggregate_scope => @type_story,
                :aggregate_type => AggregateType::MIN,
                :aggregate_target_id => size.id,
                :aggregate_card_type_id => @type_iteration.id,
                :tree_configuration_id => @tree_configuration.id }

    agg_property = create_aggregate_property_definition(options)

    agg_property.update_cards
    AggregateComputation.run_once
    assert_equal 2, agg_property.value(@project.cards.find_by_name('iteration1'))
  end

  def test_change_in_target_property_results_in_computation_of_aggregate_with_child_scope
    size, story1, story2 = init_tree_and_set_story1_and_story2_size_to(2, 3)

    options = { :name => 'aggregate prop def',
                :aggregate_scope => @type_story,
                :aggregate_type => AggregateType::SUM,
                :aggregate_target_id => size.id,
                :aggregate_card_type_id => @type_iteration.id,
                :tree_configuration_id => @tree_configuration.id }

    agg_property = create_aggregate_property_definition(options)

    agg_property.update_cards
    AggregateComputation.run_once
    assert_equal 5, agg_property.value(@project.cards.find_by_name('iteration1'))

    story1.reload
    size.update_card(story1, '10')
    story1.save!
    AggregateComputation.run_once
    assert_equal 13, agg_property.value(@project.cards.find_by_name('iteration1'))
  end

  def test_change_in_target_property_results_in_computation_of_aggregate_with_descendant_scope
    size, story1, story2 = init_tree_and_set_story1_and_story2_size_to(2, 3)
    options = { :name => 'aggregate prop def',
                :aggregate_scope => AggregateScope::ALL_DESCENDANTS,
                :aggregate_type => AggregateType::SUM,
                :aggregate_target_id => size.id,
                :aggregate_card_type_id => @type_release.id,
                :tree_configuration_id => @tree_configuration.id }

    agg_property = create_aggregate_property_definition(options)

    agg_property.update_cards
    AggregateComputation.run_once
    assert_equal 5, agg_property.value(@project.cards.find_by_name('release1'))

    story1.reload
    size.update_card(story1, '10')

    story1.save!
    AggregateComputation.run_once
    assert_equal 13, agg_property.value(@project.cards.find_by_name('release1'))
  end

  def test_bulk_cards_change_in_target_property_results_in_computation_of_aggregates
    size, story1, story2 = init_tree_and_set_story1_and_story2_size_to(2, 3)
    options = { :name => 'aggregate prop def',
                :aggregate_scope => @type_story,
                :aggregate_type => AggregateType::SUM,
                :aggregate_target_id => size.id,
                :aggregate_card_type_id => @type_iteration.id,
                :tree_configuration_id => @tree_configuration.id }

    agg_property = create_aggregate_property_definition(options)

    card_selection = CardSelection.new(@project, [story1, story2])
    card_selection.update_properties({:size => '6'})
    AggregateComputation.run_once
    assert_equal 12, agg_property.value(@project.cards.find_by_name('iteration1'))
  end

  # bug 12546
  def test_bulk_update_property_when_changing_card_type_on_card
    size, story1, story2 = init_tree_and_set_story1_and_story2_size_to(2, 3)
    formula = setup_formula_property_definition('my formula', 'size + 1')
    @type_story.add_property_definition(formula)
    options = { :name => 'aggregate prop def',
                :aggregate_scope => @type_story,
                :aggregate_type => AggregateType::SUM,
                :aggregate_target_id => formula.id,
                :aggregate_card_type_id => @type_iteration.id,
                :tree_configuration_id => @tree_configuration.id }

    agg_property = create_aggregate_property_definition(options)
    agg_property.update_cards

    iteration1 = @project.cards.find_by_name('iteration1')
    iteration1.update_properties('Type' => 'story')
    iteration1.save!
    iteration1.reload
    assert_equal 'story', story1.card_type_name
  end

  # bug 4742
  def test_bulk_changing_a_property_that_an_aggregated_formula_uses_will_result_in_computation_of_aggregate
    size, story1, story2 = init_tree_and_set_story1_and_story2_size_to(2, 3)
    formula = setup_formula_property_definition('my formula', 'size + 1')
    @type_story.add_property_definition(formula)

    options = { :name => 'aggregate prop def',
                :aggregate_scope => @type_story,
                :aggregate_type => AggregateType::SUM,
                :aggregate_target_id => formula.id,
                :aggregate_card_type_id => @type_iteration.id,
                :tree_configuration_id => @tree_configuration.id }
    agg_property = create_aggregate_property_definition(options)
    agg_property.update_cards
    AggregateComputation.run_once
    assert_equal 7, agg_property.value(@project.cards.find_by_name('iteration1'))

    card_selection = CardSelection.new(@project, [story1, story2])
    card_selection.update_properties({:size => '10'})
    AggregateComputation.run_once
    assert_equal 22, agg_property.value(@project.cards.find_by_name('iteration1'))
  end

  def test_that_no_history_is_generated_for_aggregate_properties
    size, story1, story2 = init_tree_and_set_story1_and_story2_size_to(2, 3)
    options = { :name => 'aggregate prop def',
                :aggregate_scope => AggregateScope::ALL_DESCENDANTS,
                :aggregate_type => AggregateType::SUM,
                :aggregate_target_id => size.id,
                :aggregate_card_type_id => @type_release.id,
                :tree_configuration_id => @tree_configuration.id }

    release1 = @project.cards.find_by_name('release1')
    original_number_of_versions = release1.versions.size
    original_card_version = release1.version

    agg_property = create_aggregate_property_definition(options)
    agg_property.update_cards
    AggregateComputation.run_once
    assert_equal 5, agg_property.value(release1.reload)

    story1.reload
    size.update_card(story1, '10')
    story1.save!

    AggregateComputation.run_once
    assert_equal 13, agg_property.value(release1.reload)

    assert_equal original_number_of_versions, release1.reload.versions.size
    assert_equal original_card_version, release1.reload.version
  end

  def test_that_no_changes_are_generated_for_aggregate_properties
    init_two_release_planning_tree(@tree_configuration)

    size = setup_numeric_property_definition('size', [1, 2, 3])
    story1 = @project.cards.find_by_name('story1')
    iteration1 = @project.cards.find_by_name('iteration1')
    release1 = @project.cards.find_by_name('release1')
    release2 = @project.cards.find_by_name('release2')

    type_iteration = @project.card_types.find_by_name('iteration')
    type_story = @project.card_types.find_by_name('story')

    type_story.add_property_definition(size)

    iteration_size = setup_aggregate_property_definition('iteration size',
                                                          AggregateType::SUM,
                                                          size,
                                                          @tree_configuration.id,
                                                          type_iteration.id,
                                                          AggregateScope::ALL_DESCENDANTS)
    size.update_card(story1.reload, '3')
    story1.save!
    iteration_size.update_cards
    AggregateComputation.run_once

    size.update_card(story1.reload, '5')
    story1.save!
    AggregateComputation.run_once

    relationship = @tree_configuration.find_relationship(@project.card_types.find_by_name('release'))
    assert_equal release1, relationship.value(iteration1)
    relationship.update_card(iteration1.reload, release2)
    iteration1.save!
    HistoryGeneration.run_once

    assert_equal ["Planning release changed from ##{release1.number} release1 to ##{release2.number} release2"], iteration1.reload.versions.last.describe_changes
  end

  def test_that_moving_card_between_two_releases_computes_aggregate_on_both_releases
    init_two_release_planning_tree(@tree_configuration)

    size = setup_numeric_property_definition('size', [1, 2, 3])
    release1 = @project.cards.find_by_name('release1')
    release2 = @project.cards.find_by_name('release2')
    iteration3 = @project.cards.find_by_name('iteration3')
    story2 = @project.cards.find_by_name('story2')

    story2.card_type.add_property_definition(size)

    release_size = setup_aggregate_property_definition('release size', AggregateType::SUM, size, @tree_configuration.id, release1.card_type.id, AggregateScope::ALL_DESCENDANTS)
    size.update_card(story2.reload, '10')
    story2.save!
    release_size.update_cards
    AggregateComputation.run_once

    assert_equal 10, release_size.value(release1.reload)
    assert_nil release_size.value(release2.reload)
    @tree_configuration.add_child(story2, :to => iteration3)

    AggregateComputation.run_once
    assert_nil release_size.value(release1.reload)
    assert_equal 10, release_size.value(release2.reload)
  end

  def test_that_moving_card_by_update_tree_prop_between_two_releases_computes_aggregate_on_both_releases
    init_two_release_planning_tree(@tree_configuration)

    size = setup_numeric_property_definition('size', [1, 2, 3])
    release1 = @project.cards.find_by_name('release1')
    release2 = @project.cards.find_by_name('release2')
    iteration3 = @project.cards.find_by_name('iteration3')
    story2 = @project.cards.find_by_name('story2')

    story2.card_type.add_property_definition(size)

    release_size = setup_aggregate_property_definition('release size', AggregateType::SUM, size, @tree_configuration.id, release1.card_type.id, AggregateScope::ALL_DESCENDANTS)
    size.update_card(story2.reload, '10')
    story2.save!
    release_size.update_cards
    AggregateComputation.run_once

    assert_equal 10, release_size.value(release1.reload)
    assert_nil release_size.value(release2.reload)
    story2.update_properties('Planning iteration' => iteration3.id)
    story2.save!

    AggregateComputation.run_once
    assert_equal 10, release_size.value(release2.reload)
    assert_nil release_size.value(release1.reload)
  end

  def test_that_child_only_scope_refers_only_to_cards_with_child_card_type
    init_planning_tree_with_multi_types_in_levels(@tree_configuration)

    size = setup_numeric_property_definition('size', [1, 2, 3])

    release1 = @project.cards.find_by_name('release1')
    iteration1 = @project.cards.find_by_name('iteration1')
    story3 = @project.cards.find_by_name('story3')

    @type_iteration.add_property_definition(size)
    @type_story.add_property_definition(size)

    aggregate = setup_aggregate_property_definition('iteration size', AggregateType::SUM, size, @tree_configuration.id, @type_release.id, @type_iteration)
    size.update_card(iteration1.reload, '5')
    size.update_card(story3.reload, '3')
    iteration1.save!
    story3.save!
    aggregate.update_cards
    AggregateComputation.run_once

    assert_equal 5, aggregate.value(release1.reload)
  end

  def test_should_store_results_of_calculation_with_project_precision_number_of_decimal_digits_at_most
    init_planning_tree_with_multi_types_in_levels(@tree_configuration)

    size = setup_numeric_text_property_definition('size')

    iteration1 = @project.cards.find_by_name('iteration1')
    story1 = @project.cards.find_by_name('story1')
    story2 = @project.cards.find_by_name('story2')

    @type_story.add_property_definition(size)

    aggregate = setup_aggregate_property_definition('iteration size', AggregateType::SUM, size, @tree_configuration.id, @type_iteration.id, @type_story)
    size.update_card(story1.reload, '3.234')
    size.update_card(story2.reload, '2.456')
    story1.save!
    story2.save!
    aggregate.update_cards
    AggregateComputation.run_once

    assert_equal 2, @project.precision
    assert_equal "5.69", iteration1.reload.cp_iteration_size

    @project.update_attributes(:precision => 4)
    assert_equal "5.6900", iteration1.reload.cp_iteration_size

    @project.update_attributes(:precision => 1)
    assert_equal "5.7", iteration1.reload.cp_iteration_size

    @project.update_attributes(:precision => 0)
    assert_equal "6", iteration1.reload.cp_iteration_size

    @project.update_attributes(:precision => 1)
    assert_equal "6.0", iteration1.reload.cp_iteration_size
  end

  # bug 3199
  def test_card_added_beneath_root_should_have_its_count_properties_computed
    init_three_level_tree(@tree_configuration)
    options = { :name => 'number of iterations',
                :aggregate_scope => @type_iteration,
                :aggregate_type => AggregateType::COUNT,
                :aggregate_card_type_id => @type_release.id,
                :tree_configuration_id => @tree_configuration.id }

    number_of_iterations = create_aggregate_property_definition(options)
    number_of_iterations.update_cards

    release2 = @project.cards.create!(:name => 'release2', :card_type => @type_release)
    @tree_configuration.add_child(release2)
    AggregateComputation.run_once
    assert_equal 0, number_of_iterations.value(release2.reload)
  end

  def test_remove_property_definition_from_card_type_should_compute_aggregate_property_definition_if_it_use_it_and_scope_is_all_descendants
    init_three_level_tree(@tree_configuration)
    size = setup_numeric_property_definition('size', ['1', '2', '5'])
    size.card_types = [@type_story, @type_iteration]
    size.save!

    @project.reload

    story1 = @project.cards.find_by_name('story1')
    size.update_card(story1, '5')
    story1.save
    options = { :name => 'Size of iteration',
                :aggregate_scope => AggregateScope::ALL_DESCENDANTS,
                :aggregate_type => AggregateType::SUM,
                :aggregate_card_type_id => @type_release.id,
                :tree_configuration_id => @tree_configuration.id,
                :target_property_definition => size
              }
    size_of_release = create_aggregate_property_definition(options)
    size_of_release.update_cards
    AggregateComputation.run_once

    size_of_release.reload
    release1 = @project.cards.find_by_name('release1')
    assert_equal 5, size_of_release.value(release1)

    size.card_types = [@type_iteration]
    size.save!
    @project.reload
    AggregateComputation.run_once
    assert_nil size_of_release.value(release1.reload)
  end

  # bug 3200
  def test_bulk_card_type_change_will_recompute_aggregates
    init_three_level_tree(@tree_configuration)

    options = { :name => 'Number of Iterations',
                :aggregate_scope => @type_iteration,
                :aggregate_type => AggregateType::COUNT,
                :aggregate_card_type_id => @type_release.id,
                :tree_configuration_id => @tree_configuration.id
              }

    number_of_iterations = create_aggregate_property_definition(options)
    number_of_iterations.update_cards
    AggregateComputation.run_once

    release1 = @project.cards.find_by_name('release1')
    assert_equal 2, number_of_iterations.value(release1)

    iteration2 = @project.cards.find_by_name('iteration2')

    card_selection = CardSelection.new(@project, [iteration2])
    card_selection.update_property('Type', 'Card')

    AggregateComputation.run_once
    assert_equal 1, number_of_iterations.value(release1.reload)
  end

  # bug 7217
  def test_card_type_change_will_recompute_aggregates
    change_card_type_and_assert_aggregate_updated do |card, card_type|
      card.card_type = card_type
    end
  end

  # bug 7217
  def test_card_type_name_change_will_recompute_aggregates
    change_card_type_and_assert_aggregate_updated do |card, card_type|
      card.card_type_name = card_type.name
    end
  end

  def change_card_type_and_assert_aggregate_updated(&block)
    init_three_level_tree(@tree_configuration)

    options = { :name => 'Number of Iterations',
                :aggregate_scope => @type_iteration,
                :aggregate_type => AggregateType::COUNT,
                :aggregate_card_type_id => @type_release.id,
                :tree_configuration_id => @tree_configuration.id
              }

    number_of_iterations = create_aggregate_property_definition(options)
    number_of_iterations.update_cards
    AggregateComputation.run_once

    release1 = @project.cards.find_by_name('release1')
    assert_equal 2, number_of_iterations.value(release1)

    iteration2 = @project.cards.find_by_name('iteration2')
    yield(iteration2, @project.card_types.find_by_name('Card'))
    iteration2.save!

    AggregateComputation.run_once
    assert_equal 1, number_of_iterations.value(release1.reload)
  end

  def test_tagging_a_card_can_cause_aggregates_to_be_recomputed
    init_three_level_tree(@tree_configuration)

    options = { :name => 'Number of Iterations',
                :aggregate_scope => AggregateScope::ALL_DESCENDANTS,
                :aggregate_type => AggregateType::COUNT,
                :aggregate_card_type_id => @type_release.id,
                :tree_configuration_id => @tree_configuration.id,
                :aggregate_condition => "Type = Iteration AND TAGGED WITH dangerzone"
              }

    number_of_iterations = create_aggregate_property_definition(options)
    number_of_iterations.update_cards
    AggregateComputation.run_once

    release1 = @project.cards.find_by_name('release1')
    assert_equal 0, number_of_iterations.value(release1)

    iteration1 = @project.cards.find_by_name('iteration1')
    iteration1.add_tag('dangerzone')
    iteration1.save!

    AggregateComputation.run_once
    assert_equal 1, number_of_iterations.value(release1.reload)

    iteration1.remove_tag('dangerzone')
    iteration1.save!

    AggregateComputation.run_once
    assert_equal 0, number_of_iterations.value(release1.reload)
  end

  def test_bulk_tagging_cards_can_cause_aggregates_to_be_recomputed
    init_three_level_tree(@tree_configuration)

    options = { :name => 'Number of Iterations',
                :aggregate_scope => AggregateScope::ALL_DESCENDANTS,
                :aggregate_type => AggregateType::COUNT,
                :aggregate_card_type_id => @type_release.id,
                :tree_configuration_id => @tree_configuration.id,
                :aggregate_condition => "Type = Iteration AND TAGGED WITH dangerzone"
              }

    number_of_iterations = create_aggregate_property_definition(options)
    number_of_iterations.update_cards
    AggregateComputation.run_once

    release1 = @project.cards.find_by_name('release1')
    assert_equal 0, number_of_iterations.value(release1)

    iteration1 = @project.cards.find_by_name('iteration1')
    card_selection = CardSelection.new(@project, [iteration1])
    card_selection.tag_with("dangerzone")

    AggregateComputation.run_once
    assert_equal 1, number_of_iterations.value(release1.reload)

    card_selection.remove_tag('dangerzone')

    AggregateComputation.run_once
    assert_equal 0, number_of_iterations.value(release1.reload)
  end

  def test_bulk_tagging_cards_only_causes_aggregates_with_conditions_to_be_recomputed
    init_three_level_tree(@tree_configuration)

    options = { :name => 'Number of Iterations',
                :aggregate_scope => AggregateScope::ALL_DESCENDANTS,
                :aggregate_type => AggregateType::COUNT,
                :aggregate_card_type_id => @type_release.id,
                :tree_configuration_id => @tree_configuration.id,
                :aggregate_condition => "Type = Iteration AND TAGGED WITH dangerzone"
              }

    options_two = { :name => 'Number of Iterations Without Condition',
                :aggregate_scope => @type_iteration,
                :aggregate_type => AggregateType::COUNT,
                :aggregate_card_type_id => @type_release.id,
                :tree_configuration_id => @tree_configuration.id
              }

    number_of_iterations = create_aggregate_property_definition(options)
    number_of_iterations_without_condition = create_aggregate_property_definition(options_two)
    [number_of_iterations, number_of_iterations_without_condition].each(&:update_cards)
    AggregateComputation.run_once

    release1 = @project.cards.find_by_name('release1')
    assert_equal 0, number_of_iterations.value(release1)
    assert_equal 2, number_of_iterations_without_condition.value(release1)

    StalePropertyDefinition.find(:all).each(&:destroy_without_triggering_observers)

    iteration1 = @project.cards.find_by_name('iteration1')
    card_selection = CardSelection.new(@project, [iteration1])
    card_selection.tag_with("dangerzone")

    assert_equal 1, StalePropertyDefinition.count
    AggregateComputation.run_once
    assert_equal 1, number_of_iterations.value(release1.reload)
    assert_equal 2, number_of_iterations_without_condition.value(release1)

    card_selection.remove_tag('dangerzone')
    assert_equal 1, StalePropertyDefinition.count
    AggregateComputation.run_once
    assert_equal 0, number_of_iterations.value(release1.reload)
  end

  def test_updating_a_plv_causes_aggregates_using_that_plv_to_be_recomputed
    init_three_level_tree(@tree_configuration)

    priority = setup_numeric_property_definition('priority', [1, 2, 3])
    priority.card_types = [@type_iteration]
    priority.save!

    highest_priority = create_plv!(@project, :name => 'highest priority', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '1', :property_definition_ids =>[priority.id])

    # set priority of iterations to 2 (e.g., not value of plv)
    iteration1 = @project.cards.find_by_name('iteration1')
    iteration2 = @project.cards.find_by_name('iteration2')
    [iteration1, iteration2].each do |iteration|
      priority.update_card(iteration, '2')
      iteration.save!
    end

    options = { :name => 'Num of Iterations With Highest Priority',
                :aggregate_scope => AggregateScope::ALL_DESCENDANTS,
                :aggregate_type => AggregateType::COUNT,
                :aggregate_card_type_id => @type_release.id,
                :tree_configuration_id => @tree_configuration.id,
                :aggregate_condition => "Type = Iteration AND priority = ('highest priority')"
              }

    options_two = { :name => 'Num of Iterations With Priority Set to 2',
                :aggregate_scope => AggregateScope::ALL_DESCENDANTS,
                :aggregate_type => AggregateType::COUNT,
                :aggregate_card_type_id => @type_release.id,
                :tree_configuration_id => @tree_configuration.id,
                :aggregate_condition => "Type = Iteration AND priority = 2"
              }

    number_of_iterations_with_highest_priority = create_aggregate_property_definition(options)
    number_of_iterations_with_priority_two = create_aggregate_property_definition(options_two)

    [number_of_iterations_with_priority_two, number_of_iterations_with_highest_priority].each(&:update_cards)
    AggregateComputation.run_once

    highest_priority.reload

    release1 = @project.cards.find_by_name('release1')
    assert_equal 2, number_of_iterations_with_priority_two.value(release1)
    assert_equal 0, number_of_iterations_with_highest_priority.value(release1)

    StalePropertyDefinition.find(:all).each(&:destroy_without_triggering_observers)

    highest_priority.value = '2'
    highest_priority.save!

    assert_equal 1, StalePropertyDefinition.count
    AggregateComputation.run_once
    assert_equal 2, number_of_iterations_with_priority_two.value(release1.reload)
    assert_equal 2, number_of_iterations_with_highest_priority.value(release1.reload)
  end

  def test_deleting_a_plv_should_recompute_aggregates_that_depend_on_that_plv
    init_three_level_tree(@tree_configuration)

    priority = setup_numeric_property_definition('priority', [1, 2, 3])
    priority.card_types = [@type_iteration]
    priority.save!

    highest_priority = create_plv!(@project, :name => 'highest priority', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '1', :property_definition_ids =>[priority.id])

    iteration1 = @project.cards.find_by_name('iteration1')
    priority.update_card(iteration1, highest_priority.value)
    iteration1.save!

    options = { :name => 'Num of Iterations With Highest Priority',
                :aggregate_scope => AggregateScope::ALL_DESCENDANTS,
                :aggregate_type => AggregateType::COUNT,
                :aggregate_card_type_id => @type_release.id,
                :tree_configuration_id => @tree_configuration.id,
                :aggregate_condition => "Type = Iteration AND priority = ('highest priority')"
              }

    number_of_iterations_with_highest_priority = create_aggregate_property_definition(options)
    number_of_iterations_with_highest_priority.update_cards
    AggregateComputation.run_once

    highest_priority.reload

    release1 = @project.cards.find_by_name('release1')
    assert_equal 1, number_of_iterations_with_highest_priority.value(release1)

    StalePropertyDefinition.find(:all).each(&:destroy_without_triggering_observers)
    highest_priority.destroy

    assert_equal 1, StalePropertyDefinition.count
    AggregateComputation.run_once
    assert_nil number_of_iterations_with_highest_priority.value(release1.reload)
  end

  def test_updating_an_enum_property_value_causes_aggregate_that_depend_on_it_to_be_recomputed
    StalePropertyDefinition.delete_all
    init_three_level_tree(@tree_configuration)
    enum_property = setup_managed_text_definition 'enum', ['one', 'two']
    enum_property.card_types = [@type_story]
    enum_property.save!

    @project.reload

    options = { :name => 'counting enum one cards',
                :aggregate_scope => AggregateScope::ALL_DESCENDANTS,
                :aggregate_type => AggregateType::COUNT,
                :aggregate_card_type_id => @type_release.id,
                :tree_configuration_id => @tree_configuration.id,
                :aggregate_condition => "enum > 'one'"
              }

    options_two = { :name => 'counting iterations',
                :aggregate_type => AggregateType::COUNT,
                :aggregate_card_type_id => @type_release.id,
                :tree_configuration_id => @tree_configuration.id,
                :aggregate_condition => "Type = Iteration"
              }

    story1 = @project.cards.find_by_name('story1')
    release1 = @project.cards.find_by_name('release1')
    enum_property.update_card(story1, 'two')
    story1.save!

    counting_enum_one_cards = create_aggregate_property_definition(options)
    counting_iterations     = create_aggregate_property_definition(options_two)

    [counting_enum_one_cards, counting_iterations].each(&:update_cards)
    AggregateComputation.run_once
    assert_equal 1, counting_enum_one_cards.value(release1.reload)
    assert_difference 'StalePropertyDefinition.count', 1 do
      enum_property.values.detect { |property_value| property_value.value == 'one' }.update_attribute :value, 'zzz'
    end

    AggregateComputation.run_once
    assert_equal 0, counting_enum_one_cards.value(release1.reload)
    assert_equal 0, StalePropertyDefinition.count
  end

  def test_deleting_an_enum_property_value_causes_aggregates_that_depend_on_it_to_be_recomputed
    StalePropertyDefinition.delete_all
    init_three_level_tree(@tree_configuration)
    enum_property = setup_managed_text_definition 'enum', ['one', 'two']
    enum_property.card_types = [@type_story]
    enum_property.save!

    @project.reload

    options = { :name => 'counting enum one cards',
                :aggregate_scope => AggregateScope::ALL_DESCENDANTS,
                :aggregate_type => AggregateType::COUNT,
                :aggregate_card_type_id => @type_release.id,
                :tree_configuration_id => @tree_configuration.id,
                :aggregate_condition => "enum > 'one'"
              }

    story1 = @project.cards.find_by_name('story1')
    release1 = @project.cards.find_by_name('release1')
    enum_property.update_card(story1, 'two')
    story1.save!

    counting_enum_one_cards = create_aggregate_property_definition(options)

    counting_enum_one_cards.update_cards
    AggregateComputation.run_once
    assert_equal 1, counting_enum_one_cards.value(release1.reload)
    assert_difference 'StalePropertyDefinition.count', 1 do
      enum_property.values.detect { |property_value| property_value.value == 'one' }.destroy
    end

    AggregateComputation.run_once
    assert_nil counting_enum_one_cards.value(release1.reload)
    assert_equal 0, StalePropertyDefinition.count
  end

  # bug 3617
  def test_sum_of_nulls_should_be_null
    init_three_level_tree(@tree_configuration)

    size = setup_numeric_property_definition('size', [1, 2, 3])
    @type_story.add_property_definition(size)

    options = { :name => 'Sum of Story Sizes',
                :aggregate_scope => @type_story,
                :aggregate_type => AggregateType::SUM,
                :aggregate_card_type_id => @type_iteration.id,
                :tree_configuration_id => @tree_configuration.id,
                :aggregate_target_id => size.id
              }

    story1 = @project.cards.find_by_name('story1')
    story2 = @project.cards.find_by_name('story2')

    sum_of_story_sizes = create_aggregate_property_definition(options)
    sum_of_story_sizes.update_cards
    AggregateComputation.run_once

    iteration1 = @project.cards.find_by_name('iteration1')
    assert_nil sum_of_story_sizes.value(iteration1)
  end

  # bug 4161
  def test_aggregates_are_not_computed_for_card_types_they_do_not_belong_to
    init_three_level_tree(@tree_configuration)
    release1 = @project.cards.find_by_name('release1')

    options1 = { :name => 'iteration - count of stories',
                :aggregate_scope => @type_story,
                :aggregate_type => AggregateType::COUNT,
                :aggregate_card_type_id => @type_iteration.id,
                :tree_configuration_id => @tree_configuration.id
              }

    iteration_count_of_stories = create_aggregate_property_definition(options1)
    @tree_configuration.reload

    AggregateComputation.run_once
    iteration_count_of_stories.compute_aggregate(release1)
    AggregateComputation.run_once

    assert_nil iteration_count_of_stories.value(release1.reload)
  end

  # bug 4161
  def test_removing_card_from_tree_does_not_result_in_count_aggregates_on_invalid_card_types_being_set_to_zero
    init_three_level_tree(@tree_configuration)

    options1 = { :name => 'iteration - count of stories',
                :aggregate_scope => @type_story,
                :aggregate_type => AggregateType::COUNT,
                :aggregate_card_type_id => @type_iteration.id,
                :tree_configuration_id => @tree_configuration.id
              }

    options2 = { :name => 'release - count of stories',
                :aggregate_scope => @type_story,
                :aggregate_type => AggregateType::COUNT,
                :aggregate_card_type_id => @type_release.id,
                :tree_configuration_id => @tree_configuration.id
              }

    iteration_count_of_stories = create_aggregate_property_definition(options1)
    release_count_of_stories = create_aggregate_property_definition(options2)
    @tree_configuration.reload

    [iteration_count_of_stories, release_count_of_stories].each(&:update_cards)
    AggregateComputation.run_once

    iteration1 = @project.cards.find_by_name('iteration1')
    release1 = @project.cards.find_by_name('release1')
    story2 = @project.cards.find_by_name('story2')

    assert_equal 2, iteration_count_of_stories.value(iteration1)
    assert_nil release_count_of_stories.value(iteration1)
    assert_equal 2, release_count_of_stories.value(release1)
    assert_nil iteration_count_of_stories.value(release1)

    @tree_configuration.remove_card(story2)
    AggregateComputation.run_once

    assert_equal 1, iteration_count_of_stories.value(iteration1.reload)
    assert_nil release_count_of_stories.value(iteration1)
    assert_equal 1, release_count_of_stories.value(release1.reload)
    assert_nil iteration_count_of_stories.value(release1)
  end

  # bug 5366
  def test_bulk_deleting_cards_in_tree_will_recompute_aggregates
    init_five_level_tree(@tree_configuration)
    type_release, type_iteration, type_story, type_task, type_minutia = find_five_level_tree_types
    iteration1 = @project.cards.find_by_name('iteration1')
    story1 = @project.cards.find_by_name('story1')
    minutia1 = @project.cards.find_by_name('minutia1')

    story_count_of_desc = create_aggregate_property_definition(:name => 'story count of desc',
                                                               :aggregate_scope => AggregateScope::ALL_DESCENDANTS,
                                                               :aggregate_type => AggregateType::COUNT,
                                                               :aggregate_card_type_id => type_story.id,
                                                               :tree_configuration_id => @tree_configuration.id)

    story_count_of_desc.update_cards
    AggregateComputation.run_once
    assert_equal 4, story_count_of_desc.value(story1.reload)

    CardSelection.new(@project, [iteration1, minutia1]).destroy
    AggregateComputation.run_once
    assert_equal 3, story_count_of_desc.value(story1.reload)
  end

  def test_stale
    @card_tree = create_two_release_planning_tree
    size = setup_numeric_property_definition('size', [1, 2, 3])
    story2 = @project.cards.find_by_name('story2')
    story2.card_type.add_property_definition(size)
    release_size = setup_aggregate_property_definition('release size', AggregateType::SUM, size, @card_tree.configuration.id,
        @type_release.id, AggregateScope::ALL_DESCENDANTS)
    publisher = AggregatePublisher.new(release_size, @member)
    publisher.publish_card_message(story2)

    story2.reload
    assert release_size.stale?(story2)

    assert release_size.property_value_on(story2).stale?
    assert !release_size.property_value_on(story2.versions.last).stale?
    AggregateComputation.run_once
    story2 = @project.cards.find_by_name('story2') # A performance enhancement requires that we find the card again.
    assert !release_size.stale?(story2)
  end

  def test_computing_aggregates_across_entire_project
    with_new_project do |project|
      StalePropertyDefinition.find(:all).each(&:destroy_without_triggering_observers)

      type_release, type_iteration, type_story = init_planning_tree_types
      tree = create_three_level_tree

      size = setup_numeric_property_definition('size', [1, 2, 3])
      type_story.add_property_definition(size)

      release1, iteration1, iteration2, story1, story2 = ['release1', 'iteration1', 'iteration2', 'story1', 'story2'].collect { |card_name| project.cards.find_by_name(card_name) }

      size.update_card(story1, '1')
      story1.save!
      size.update_card(story2, '2')
      story2.save!

      project.compute_aggregates
      assert_equal 0, StalePropertyDefinition.count

      release_story_size = setup_aggregate_property_definition('release story size', AggregateType::SUM, size, tree.configuration.id, type_release.id, AggregateScope::ALL_DESCENDANTS)
      project.reload.compute_aggregates
      assert_equal 1, StalePropertyDefinition.count
      requests = StalePropertyDefinition.find(:all)
      assert_stale_aggregate_exists(requests, project, release1, release_story_size)
      AggregateComputation.run_once
      assert_equal 3, release_story_size.value(release1.reload)
      assert_equal 0, StalePropertyDefinition.count

      release_minimum_story_size = setup_aggregate_property_definition('release minimum story size', AggregateType::MIN, size, tree.configuration.id, type_release.id, AggregateScope::ALL_DESCENDANTS)
      project.reload.compute_aggregates
      assert_equal 2, StalePropertyDefinition.count
      requests = StalePropertyDefinition.find(:all)
      assert_stale_aggregate_exists(requests, project, release1, release_story_size)
      assert_stale_aggregate_exists(requests, project, release1, release_minimum_story_size)
      release_story_size.update_card(release1.reload, nil)
      release1.save!
      AggregateComputation.run_once
      assert_equal 3, release_story_size.value(release1.reload)
      assert_equal 1, release_minimum_story_size.value(release1.reload)
      assert_equal 0, StalePropertyDefinition.count

      iteration_minimum_story_size = setup_aggregate_property_definition('iteration minimum story size', AggregateType::MIN, size, tree.configuration.id, type_iteration.id, AggregateScope::ALL_DESCENDANTS)
      project.reload.compute_aggregates
      assert_equal 4, StalePropertyDefinition.count
      requests = StalePropertyDefinition.find(:all)
      assert_stale_aggregate_exists(requests, project, release1, release_story_size)
      assert_stale_aggregate_exists(requests, project, release1, release_minimum_story_size)
      assert_stale_aggregate_exists(requests, project, iteration1, iteration_minimum_story_size)
      assert_stale_aggregate_exists(requests, project, iteration2, iteration_minimum_story_size)
      release_story_size.update_card(release1.reload, nil)
      release_minimum_story_size.update_card(release1, nil)
      release1.save!
      AggregateComputation.run_once
      assert_equal 3, release_story_size.value(release1.reload)
      assert_equal 1, release_minimum_story_size.value(release1.reload)
      assert_equal 1, iteration_minimum_story_size.value(iteration1.reload)
      assert_equal nil, iteration_minimum_story_size.value(iteration2.reload)
    end
  end

  # Tech task #5185
  def test_recompute_project_aggregates_first_inserts_message_for_entire_project_then_that_is_split_into_card_messages_which_update_the_cards
    size, story1, story2 = init_tree_and_set_story1_and_story2_size_to(2, 3)

    options = { :name => 'aggregate prop def',
                :aggregate_scope => AggregateScope::ALL_DESCENDANTS,
                :aggregate_type => AggregateType::AVG,
                :aggregate_target_id => size.id,
                :aggregate_card_type_id => @type_release.id,
                :tree_configuration_id => @tree_configuration.id }

    agg_property = create_aggregate_property_definition(options)

    @project.compute_aggregates
    ::AggregateComputation::ProjectsProcessor.run_once # Push project messages into cards queue.
    assert_equal nil, agg_property.value(@project.cards.find_by_name('release1'))
    ::AggregateComputation::CardsProcessor.run_once
    assert_equal 2.5, agg_property.value(@project.cards.find_by_name('release1'))
  end

  def test_message_is_republished_if_lock_wait_timeout_exception_occurs
    ::AggregateComputation::CardsProcessor.class_eval do
      private
      def update_aggregates_with_exception(project, card, property_names_and_values)
        raise "this is a Lock wait timeout exceeded exception, yo"
      end
      alias_method_chain :update_aggregates, :exception
    end

    begin
      get_all_messages_in_queue(AggregatePublisher::CARD_QUEUE)   # flush queue
      get_all_messages_in_queue(AggregatePublisher::PROJECT_QUEUE)   # flush queue

      size, story1, story2 = init_tree_and_set_story1_and_story2_size_to(2, 3)
      options = { :name => 'aggregate prop def',
                  :aggregate_scope => AggregateScope::ALL_DESCENDANTS,
                  :aggregate_type => AggregateType::AVG,
                  :aggregate_target_id => size.id,
                  :aggregate_card_type_id => @type_release.id,
                  :tree_configuration_id => @tree_configuration.id }
      agg_property = create_aggregate_property_definition(options)
      agg_property.update_cards

      expected_messages = get_all_messages_in_queue(AggregatePublisher::CARD_QUEUE)

      agg_property.update_cards
      AggregateComputation.run_once(:batch_size => expected_messages.size)
      after_processing_messages = get_all_messages_in_queue(AggregatePublisher::CARD_QUEUE)

      assert_messages_equal expected_messages, after_processing_messages
    ensure
      ::AggregateComputation::CardsProcessor.class_eval do
        alias :update_aggregates :update_aggregates_without_exception
      end
    end
  end

  # bug 7860
  def test_message_is_republished_if_timeout_exception_occurs
    ::AggregateComputation::CardsProcessor.class_eval do
      private
      def update_aggregates_with_exception(project, card, property_names_and_values)
        raise ::TimeoutError.new('execution expired, buddy')
      end
      alias_method_chain :update_aggregates, :exception
    end

    begin
      get_all_messages_in_queue(AggregatePublisher::CARD_QUEUE)   # flush queue
      get_all_messages_in_queue(AggregatePublisher::PROJECT_QUEUE)   # flush queue

      size, story1, story2 = init_tree_and_set_story1_and_story2_size_to(2, 3)
      options = { :name => 'aggregate prop def',
                  :aggregate_scope => AggregateScope::ALL_DESCENDANTS,
                  :aggregate_type => AggregateType::AVG,
                  :aggregate_target_id => size.id,
                  :aggregate_card_type_id => @type_release.id,
                  :tree_configuration_id => @tree_configuration.id }
      agg_property = create_aggregate_property_definition(options)
      agg_property.update_cards

      expected_messages = get_all_messages_in_queue(AggregatePublisher::CARD_QUEUE)
      agg_property.update_cards
      AggregateComputation.run_once(:batch_size => expected_messages.size)
      after_processing_messages = get_all_messages_in_queue(AggregatePublisher::CARD_QUEUE)

      assert_messages_equal expected_messages, after_processing_messages
    ensure
      ::AggregateComputation::CardsProcessor.class_eval do
        alias :update_aggregates :update_aggregates_without_exception
      end
    end
  end

  def test_aggregate_computation_should_recalculate_formulas_that_depend_upon_the_aggregate
    with_new_project do |project|
      task_card_type = setup_card_type(project, "task")
      bug_card_type = setup_card_type(project, "bug")

      task_bug_tree = project.tree_configurations.create!(:name => 'task-bug')
      task_bug_tree.update_card_types({
        task_card_type => {:position => 0, :relationship_name => 'task-bug-relationship'},
        bug_card_type => {:position => 1}
      })

      task_aggregate = setup_aggregate_property_definition('task_aggregate', AggregateType::COUNT, nil, task_bug_tree.id, task_card_type.id, bug_card_type)
      task_formula = setup_formula_property_definition('task_formula', '2 * task_aggregate')
      task_formula.card_types = [task_card_type]
      task_formula.save!

      longbob = login_as_longbob
      bug_card = project.cards.create(:name => "bug", :card_type_name => bug_card_type.name)
      task_card = project.cards.create(:name => "task", :card_type_name => task_card_type.name)
      task_bug_tree.add_child(task_card)
      task_bug_tree.add_child(bug_card, :to => task_card)

      login_as_member

      original_task_card_version = task_card.version
      original_task_number_of_versions = task_card.versions.size


      AggregateComputation.run_once

      assert_equal 1, task_aggregate.value(task_card.reload)
      assert_equal 2, task_formula.value(task_card)

      assert_equal original_task_card_version + 1, task_card.version
      assert_equal original_task_number_of_versions + 1, task_card.versions.size
      assert_equal longbob, task_card.versions.last.created_by
      assert_equal longbob, task_card.modified_by
    end
  end

  def test_aggregate_computation_should_put_recompute_aggregate_message_in_queue_when_updating_formulas_that_the_aggregate_depends_on
    with_new_project do |project|
      bug_card_type = setup_card_type(project, "bug")
      task_card_type = setup_card_type(project, "task")

      size = setup_numeric_property_definition('size', [1, 2, 3])
      size.card_types = [task_card_type]
      size.save!

      bug_task_tree = project.tree_configurations.create!(:name => 'bug-task')
      bug_task_tree.update_card_types({
        bug_card_type => {:position => 0, :relationship_name => 'bug-task-relationship'},
        task_card_type => {:position => 1}
      })

      bug_aggregate = setup_aggregate_property_definition('bug_aggregate', AggregateType::SUM, size, bug_task_tree.id, bug_card_type.id, task_card_type)
      bug_formula = setup_formula_property_definition('bug_formula', '100 + bug_aggregate')
      bug_formula.card_types = [bug_card_type]
      bug_formula.save!

      task_bug_tree = project.tree_configurations.create!(:name => 'task-bug')
      task_bug_tree.update_card_types({
        task_card_type => {:position => 0, :relationship_name => 'task-bug-relationship'},
        bug_card_type => {:position => 1}
      })

      task_aggregate = setup_aggregate_property_definition('task_aggregate', AggregateType::SUM, bug_formula, task_bug_tree.id, task_card_type.id, bug_card_type)
      task_formula = setup_formula_property_definition('task_formula', '200 + task_aggregate')
      task_formula.card_types = [task_card_type]
      task_formula.save!

      bug_card = project.cards.create(:name => "bug", :card_type_name => bug_card_type.name)
      task_card = project.cards.create(:name => "task", :card_type_name => task_card_type.name)

      task_bug_tree.add_child(task_card)
      task_bug_tree.add_child(bug_card, :to => task_card)

      bug_task_tree.add_child(bug_card)
      bug_task_tree.add_child(task_card, :to => bug_card)

      size.update_card(task_card, 1)
      task_card.save!

      AggregateComputation.run_once

      assert_equal 1, bug_aggregate.value(bug_card.reload)
      assert_equal 101, bug_formula.value(bug_card)

      AggregateComputation.run_once

      assert_equal 101, task_aggregate.value(task_card.reload)
      assert_equal 301, task_formula.value(task_card)
    end
  end

  def test_aggregate_computation_should_delete_stale_formula_properties_when_computing_aggregates_in_that_formula
    with_new_project do |project|
      @type_release, @type_iteration, @type_story = init_planning_tree_types
      @card_tree = create_three_level_tree
      aggregate_property_definition = setup_aggregate_property_definition('aggregate name', AggregateType::COUNT, nil, @card_tree.configuration.id, @type_release.id, @type_iteration)
      @card_tree.configuration.reload
      john_formula = setup_formula_property_definition('john', "'#{aggregate_property_definition.name}' + 1")

      aggregate_property_definition.update_cards

      @release_card = project.cards.find_by_name('release1')
      @iteration_card = project.cards.find_by_name('iteration1')

      stales = StalePropertyDefinition.find(:all)
      assert_stale_aggregate_exists(stales, project, @release_card, aggregate_property_definition)
      assert_stale_aggregate_exists(stales, project, @release_card, john_formula)

      AggregateComputation.run_once

      stales = StalePropertyDefinition.find(:all)
      stale_prop_defs = stales.collect { |stale| PropertyDefinition.find_by_id(stale.prop_def_id) }
      assert_equal [], stale_prop_defs.select { |pd| pd.id == aggregate_property_definition.id }.collect(&:name)
      assert_equal [], stale_prop_defs.select { |pd| pd.id == john_formula.id }.collect(&:name)
    end
  end

  # bug 7032
  def test_new_version_should_not_be_created_if_change_in_aggregates_does_not_result_in_change_in_formula
    with_new_project do |project|
      @type_release, @type_iteration, @type_story = init_planning_tree_types
      card_tree = create_three_level_tree
      tree_configuration = card_tree.configuration

      pd_num = setup_numeric_property_definition('num', [1, 2, 3])
      pd_num.card_types = [@type_iteration, @type_story]
      pd_num.save!

      pd_sum_of_num_on_iterations = setup_aggregate_property_definition('sum_of_num_on_iterations', AggregateType::SUM, pd_num, tree_configuration.id, @type_release.id, @type_iteration)
      pd_sum_of_num_on_stories = setup_aggregate_property_definition('sum_of_num_on_stories', AggregateType::SUM, pd_num, tree_configuration.id, @type_release.id, @type_story)
      tree_configuration.reload

      pd_formula = setup_formula_property_definition('formula', "#{pd_sum_of_num_on_iterations.name} + #{pd_sum_of_num_on_stories.name}")
      pd_formula.card_types = [@type_release]
      pd_formula.save!

      release1 = project.cards.find_by_name('release1')
      iteration1 = project.cards.find_by_name('iteration1')

      original_release1_version = release1.version
      original_number_of_release1_versions = release1.versions.size

      # set num on iteration1 to 5 so that one aggregate changes, but the other remains nil
      pd_num.update_card(iteration1, 5)
      iteration1.save!

      pd_sum_of_num_on_iterations.update_cards
      pd_sum_of_num_on_stories.update_cards
      AggregateComputation.run_once

      # aggregates changed but don't affect history, and the formula value stayed the same (it was nil + nil = nil, and now is 5 + nil = nil), so shouldn't have a new version
      assert_equal original_number_of_release1_versions, release1.reload.versions.size
      assert_equal 5, pd_sum_of_num_on_iterations.value(release1.reload)
      assert_equal original_release1_version, release1.reload.version
    end
  end

  def test_processor_should_not_publish_aggregate_messages_for_cards_that_are_not_ancestors_of_computed_card
    with_new_project do |project|
      type_release, type_iteration, type_story = init_planning_tree_types
      tree = create_two_release_planning_tree
      tree_configuration = tree.configuration

      count_of_stories = setup_aggregate_property_definition('story count', AggregateType::COUNT, nil, tree_configuration.id, type_iteration.id, type_story)

      pd_formula = setup_formula_property_definition('formula', "'story count' + 20")
      pd_formula.card_types = [type_iteration]
      pd_formula.save!

      sum_of_formula = setup_aggregate_property_definition('sum of formula', AggregateType::SUM, pd_formula, tree_configuration.id, type_release.id, type_iteration)

      release1 = project.cards.find_by_name('release1')
      story2 = project.cards.find_by_name('story2')
      iteration2 = project.cards.find_by_name('iteration2')

      tree_configuration.add_children_to([story2], iteration2)
      # Add story2 to iteration2 should cause 2 aggregate message sent out for iteration1 and iteration2
      # and 1 message for release1
      # Process these 3 messages
      AggregateComputation.run_once(:batch_size => 3)
      # After processed iteration1 and iteration2, should have 2 messages sent out for release1 card
      all_messages = get_all_messages_in_queue(AggregatePublisher::CARD_QUEUE)
      assert_equal 2, all_messages.length
      assert_equal [[release1.id, sum_of_formula.id]] * 2, all_messages.map { |message| [message.body_hash[:card_id], message.body_hash[:aggregate_property_definition_id]] }
    end
  end

  def test_processor_should_not_publish_aggregate_messages_for_trees_that_the_aggregate_does_not_apply_to
    with_new_project do |project|
      type_release, type_iteration, type_story = init_planning_tree_types
      tree = create_two_release_planning_tree
      tree_configuration = tree.configuration

      # set up tree one's aggregates/formulas
      count_of_stories = setup_aggregate_property_definition('story count', AggregateType::COUNT, nil, tree_configuration.id, type_iteration.id, type_story)

      pd_formula = setup_formula_property_definition('formula', "'story count' + 20")
      pd_formula.card_types = [type_iteration]
      pd_formula.save!

      sum_of_formula = setup_aggregate_property_definition('sum of formula', AggregateType::SUM, pd_formula, tree_configuration.id, type_release.id, type_iteration)

      # find cards for tree one
      release1 = project.cards.find_by_name('release1')
      story2 = project.cards.find_by_name('story2')
      iteration2 = project.cards.find_by_name('iteration2')

      # create tree two
      tree_two_configuration = project.tree_configurations.create!(:name => 'two_release_planning_tree_two')
      init_two_release_planning_tree(tree_two_configuration)
      assert_receive_nil_from_queue(AggregatePublisher::CARD_QUEUE) # check that creating tree two did not publish aggregates, as it has no aggregates yet anyway

      setup_aggregate_property_definition('sum of formula on tree two', AggregateType::SUM, pd_formula, tree_two_configuration.id, type_release.id, type_iteration)

      tree_configuration.add_children_to([story2.reload], iteration2.reload)

      # Add story2 to iteration2 should cause 2 aggregate message sent out for iteration1 and iteration2
      # Process these 2 messages
      AggregateComputation.run_once(:batch_size => number_of_messages_in_aggregate_queue)

      all_messages = get_all_messages_in_queue(AggregatePublisher::CARD_QUEUE)
      # After processed iteration1 and iteration2, should have 2 messages sent out for release1 card
      assert_equal 2, all_messages.length
      assert_equal [[release1.id, sum_of_formula.id]] * 2, all_messages.map { |message| [message.body_hash[:card_id], message.body_hash[:aggregate_property_definition_id]] }
    end
  end

  private

  def number_of_messages_in_aggregate_queue
    count_of_messages_in_queue = 0
    bridge_messages(AggregatePublisher::CARD_QUEUE, AggregatePublisher::CARD_QUEUE) do
      count_of_messages_in_queue += 1
    end
    count_of_messages_in_queue
  end

  def assert_stale_aggregate_exists(stale_aggregates, project, card, aggregate_property)
    assert(stale_aggregates.any? do |stale_aggregate|
      project.id == stale_aggregate.project_id &&
      card.id == stale_aggregate.card_id &&
      aggregate_property.id == stale_aggregate.prop_def_id
    end)
  end

  def create_aggregate_property_definition(options)
    aggregate_def = @project.property_definitions_with_hidden.create_aggregate_property_definition(options)
    @project.reload.update_card_schema
    aggregate_def
  end

  def init_tree_and_set_story1_and_story2_size_to(size_of_story1 = 2, size_of_story2 = 3)
    init_three_level_tree(@tree_configuration)
    size = setup_numeric_property_definition('size', [1, 2, 3])
    @type_story.add_property_definition(size)

    story1 = @project.cards.find_by_name('story1')
    story2 = @project.cards.find_by_name('story2')

    size.update_card(story1, size_of_story1.to_s)
    size.update_card(story2, size_of_story2.to_s)

    story1.save!
    story2.save!
    [size, story1, story2]
  end

end
