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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

#Tags: bulk_update
class BulkUpdateRelationshipsTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

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

  def test_bulk_update_relationship_property_with_card_type_name_containing_quote_does_not_break_sql
    with_new_project do |project|
      configuration = project.tree_configurations.create(:name => 'planning')
      init_planning_tree_types
      init_two_release_planning_tree(configuration)

      type_story = project.card_types.find_by_name("story")
      type_story.name = "Qu'oted"
      type_story.save!

      iteration_card = project.cards.find_by_name('iteration1')
      different_release = project.cards.find_by_name('release2')
      release_tree_property = project.find_property_definition('planning release')
      card_selection = CardSelection.new(project, [iteration_card])
      card_selection.update_property('planning release', different_release.id)
      assert_equal different_release, release_tree_property.value(iteration_card.reload)
    end
  end

  # basic scenario: move one card and all its children
  def test_move_task2_to_story2
    minutia1 = @project.cards.find_by_name('minutia1')
    minutia2 = @project.cards.find_by_name('minutia2')
    task2 = @project.cards.find_by_name('task2')
    story2 = @project.cards.find_by_name('story2')
    iteration3 = @project.cards.find_by_name('iteration3')
    release2 = @project.cards.find_by_name('release2')

    card_selection = CardSelection.new(@project, [task2])
    card_selection.update_property(@planning_story.name, story2.id)

    assert_equal story2.name, @planning_story.value(task2.reload).name
    assert_equal story2.name, @planning_story.value(minutia1.reload).name
    assert_equal story2.name, @planning_story.value(minutia2.reload).name

    assert_equal task2.name, @planning_task.value(minutia1).name
    assert_equal task2.name, @planning_task.value(minutia2).name

    assert_equal iteration3.name, @planning_iteration.value(minutia1).name
    assert_equal iteration3.name, @planning_iteration.value(minutia2).name
    assert_equal iteration3.name, @planning_iteration.value(task2).name

    assert_equal release2.name, @planning_release.value(minutia1).name
    assert_equal release2.name, @planning_release.value(minutia1).name
    assert_equal release2.name, @planning_release.value(task2).name
  end

  # scenario: selected card is descendant of another selected card
  def test_move_task2_and_minutia2_to_story2
    minutia1 = @project.cards.find_by_name('minutia1')
    minutia2 = @project.cards.find_by_name('minutia2')
    task2 = @project.cards.find_by_name('task2')
    story2 = @project.cards.find_by_name('story2')
    iteration3 = @project.cards.find_by_name('iteration3')
    release2 = @project.cards.find_by_name('release2')

    card_selection = CardSelection.new(@project, [task2, minutia2])
    card_selection.update_property(@planning_story.name, story2.id)

    assert_equal story2.name, @planning_story.value(task2.reload).name
    assert_equal story2.name, @planning_story.value(minutia1.reload).name
    assert_equal story2.name, @planning_story.value(minutia2.reload).name

    assert_equal task2.name, @planning_task.value(minutia1).name
    assert_equal nil, @planning_task.value(minutia2)

    assert_equal iteration3.name, @planning_iteration.value(minutia1).name
    assert_equal iteration3.name, @planning_iteration.value(minutia2).name
    assert_equal iteration3.name, @planning_iteration.value(task2).name

    assert_equal release2.name, @planning_release.value(minutia1).name
    assert_equal release2.name, @planning_release.value(minutia1).name
    assert_equal release2.name, @planning_release.value(task2).name
  end

  # scenario: one of the selected cards isn't on a tree
  def test_move_task1_and_non_tree_story_to_iteration4
    task1 = @project.cards.find_by_name('task1')
    iteration4 = @project.cards.find_by_name('iteration4')
    release2 = @project.cards.find_by_name('release2')
    non_tree_story = @project.cards.create!(:name => 'non_tree', :card_type => @type_story)

    card_selection = CardSelection.new(@project, [task1, non_tree_story])
    card_selection.update_property(@planning_iteration.name, iteration4.id)

    assert_equal iteration4.name, @planning_iteration.value(non_tree_story.reload).name
    assert_equal iteration4.name, @planning_iteration.value(task1.reload).name

    assert_equal release2.name, @planning_release.value(non_tree_story).name
    assert_equal release2.name, @planning_release.value(task1).name

    assert_equal nil, @planning_story.value(non_tree_story)
    assert_equal nil, @planning_story.value(task1)

    assert_equal nil, @planning_task.value(non_tree_story)
    assert_equal nil, @planning_task.value(task1)

    assert @tree_configuration.include_card?(non_tree_story)
  end

  # scenario: can set cards with children to have a 'not set' release
  def test_setting_release_to_not_set_will_move_card_under_root_and_take_its_children_with_it
    iteration3 = @project.cards.find_by_name('iteration3')
    story2 = @project.cards.find_by_name('story2')

    card_selection = CardSelection.new(@project, [iteration3])
    card_selection.update_property(@planning_release.name, '')

    iteration3.reload
    story2.reload

    assert_nil @planning_release.value(iteration3)
    assert_nil @planning_iteration.value(iteration3)
    assert_nil @planning_story.value(iteration3)
    assert_nil @planning_task.value(iteration3)

    assert_nil @planning_release.value(story2)
    assert_equal iteration3.name, @planning_iteration.value(story2).name
    assert_nil @planning_story.value(story2)
    assert_nil @planning_task.value(story2)

    assert_equal 1, @tree_configuration.reload.level_in_complete_tree(iteration3)
    assert_equal 2, @tree_configuration.level_in_complete_tree(story2)
  end

  # scenario: can set cards at bottom level to have a 'not set' parent
  def test_setting_task_of_minutia1_to_not_set_will_move_it_to_be_direct_child_of_story1
    minutia2 = @project.cards.find_by_name('minutia2')
    release1 = @project.cards.find_by_name('release1')
    iteration1 = @project.cards.find_by_name('iteration1')
    story1 = @project.cards.find_by_name('story1')

    card_selection = CardSelection.new(@project, [minutia2])
    card_selection.update_property(@planning_task.name, '')

    assert_equal release1.name, @planning_release.value(minutia2.reload).name
    assert_equal iteration1.name, @planning_iteration.value(minutia2).name
    assert_equal story1.name, @planning_story.value(minutia2).name
    assert_nil @planning_task.value(minutia2)

    assert @tree_configuration.include_card?(minutia2)
  end

  # scenario: can set a card's grandparent to 'not set'
  def test_setting_iteration_of_task2_to_not_set_will_move_it_and_its_children_to_be_direct_child_of_release1
    minutia1 = @project.cards.find_by_name('minutia1')
    minutia2 = @project.cards.find_by_name('minutia2')
    release1 = @project.cards.find_by_name('release1')
    iteration1 = @project.cards.find_by_name('iteration1')
    story1 = @project.cards.find_by_name('story1')
    task2 = @project.cards.find_by_name('task2')

    card_selection = CardSelection.new(@project, [task2])
    card_selection.update_property(@planning_iteration.name, '')

    assert_equal release1.name, @planning_release.value(task2.reload).name
    assert_nil @planning_iteration.value(task2)
    assert_nil @planning_story.value(task2)

    assert_equal release1.name, @planning_release.value(minutia1.reload).name
    assert_nil @planning_iteration.value(minutia1)
    assert_nil @planning_story.value(minutia1)
    assert_equal task2.name, @planning_task.value(minutia1).name

    assert_equal release1.name, @planning_release.value(minutia2.reload).name
    assert_nil @planning_iteration.value(minutia2)
    assert_nil @planning_story.value(minutia2)
    assert_equal task2.name, @planning_task.value(minutia2).name
  end

  def test_setting_cards_on_various_levels_to_have_a_not_set_parent_or_grandparent
    minutia1 = @project.cards.find_by_name('minutia1')
    minutia2 = @project.cards.find_by_name('minutia2')
    release1 = @project.cards.find_by_name('release1')
    iteration1 = @project.cards.find_by_name('iteration1')
    story2 = @project.cards.find_by_name('story2')
    task2 = @project.cards.find_by_name('task2')

    card_selection = CardSelection.new(@project, [task2, minutia1, story2])
    card_selection.update_property(@planning_iteration.name, '')

    assert_equal release1.name, @planning_release.value(task2.reload).name
    assert_nil @planning_iteration.value(task2)

    assert_equal release1.name, @planning_release.value(task2.reload).name
    assert_nil @planning_iteration.value(task2)
    assert_nil @planning_story.value(task2)

    assert_equal release1.name, @planning_release.value(minutia1.reload).name
    assert_nil @planning_iteration.value(minutia1)
    assert_nil @planning_story.value(minutia1)
    assert_nil @planning_task.value(minutia1)
  end

  def test_moving_cards_to_be_children_of_a_card_not_on_the_tree_will_add_the_card_to_the_tree
    non_tree_iteration = @project.cards.create!(:name => 'non_tree', :card_type => @type_iteration)
    task2 = @project.cards.find_by_name('task2')

    card_selection = CardSelection.new(@project, [task2])
    card_selection.update_property(@planning_iteration.name, non_tree_iteration.id)

    task2.reload
    non_tree_iteration.reload
    minutia1 = @project.cards.find_by_name('minutia1')
    minutia2 = @project.cards.find_by_name('minutia2')

    assert_equal 1, @tree_configuration.level_in_complete_tree(non_tree_iteration)

    assert_nil @planning_release.value(task2)
    assert_equal non_tree_iteration.name, @planning_iteration.value(task2).name
    assert_nil @planning_story.value(task2)
    assert_nil @planning_task.value(task2)

    [minutia1, minutia2].each do |minutia|
      assert_nil @planning_release.value(minutia)
      assert_equal non_tree_iteration.name, @planning_iteration.value(minutia).name
      assert_nil @planning_story.value(minutia)
      assert_equal task2.name, @planning_task.value(minutia).name
    end
  end

  def test_versions_are_created_and_versions_on_changed_cards_are_increased
    minutia1 = @project.cards.find_by_name('minutia1')
    minutia2 = @project.cards.find_by_name('minutia2')
    task2 = @project.cards.find_by_name('task2')
    story1 = @project.cards.find_by_name('story1')
    iteration1 = @project.cards.find_by_name('iteration1')
    release1 = @project.cards.find_by_name('release1')

    original_task2_version = task2.version
    original_minutia1_version = minutia1.version
    original_minutia2_version = minutia2.version

    card_selection = CardSelection.new(@project, [task2, minutia2])
    card_selection.update_property(@planning_story.name, story1.id)

    assert_equal story1.name, @planning_story.value(task2.reload).name
    assert_equal story1.name, @planning_story.value(minutia1.reload).name
    assert_equal story1.name, @planning_story.value(minutia2.reload).name

    assert_nil @planning_task.value(minutia2.reload)
    assert_equal task2.name, @planning_task.value(minutia1).name

    assert_equal iteration1.name, @planning_iteration.value(task2).name
    assert_equal iteration1.name, @planning_iteration.value(minutia1).name
    assert_equal iteration1.name, @planning_iteration.value(minutia2).name

    assert_equal release1.name, @planning_release.value(task2).name
    assert_equal release1.name, @planning_release.value(minutia1).name
    assert_equal release1.name, @planning_release.value(minutia2).name

    assert_equal story1.id, minutia2.versions.last.cp_planning_story_card_id.to_i

    assert_equal original_task2_version, task2.versions.last.version
    assert_equal original_minutia1_version, minutia1.versions.last.version
    assert_equal original_minutia2_version + 1, minutia2.versions.last.version

    assert_equal original_task2_version, task2.version
    assert_equal original_minutia1_version, minutia1.version
    assert_equal original_minutia2_version + 1, minutia2.version
  end

  def test_update_property_should_add_errors_if_update_invalid
    minutia1 = @project.cards.find_by_name('minutia1')
    minutia2 = @project.cards.find_by_name('minutia2')
    task2 = @project.cards.find_by_name('task2')
    story1 = @project.cards.find_by_name('story1')

    card_selection = CardSelection.new(@project, [task2, minutia2])

    card_selection.update_property(@planning_story.name, minutia1.id)
    assert_equal ["Property #{'Planning story'.bold} must be set to a card of type #{'story'.bold} and so cannot be set to card #{'minutia1'.bold}, which is a #{'minutia'.bold}."], card_selection.errors

    assert_raise_message(PropertyDefinition::InvalidValueException, /Card properties can only be updated with ids of existing cards/) do
      card_selection.update_property(@planning_story.name, -0.23)
    end

    card_selection = CardSelection.new(@project, [story1])
    card_selection.update_property(@planning_story.name, story1.id)
    assert_equal ["One or more selected cards has card type #{'story'.bold} and property #{'Planning story'.bold} does not apply to it."], card_selection.errors
  end

  def test_multi_types_in_levels_scenario
    create_tree_project(:init_planning_tree_with_multi_types_in_levels) do |project, tree, configuration|
      type_release, type_iteration, type_story = find_planning_tree_types

      story3 = project.cards.find_by_name('story3')
      iteration2 = project.cards.find_by_name('iteration2')
      release1 = project.cards.find_by_name('release1')

      planning_release = project.relationship_property_definitions.detect{|pd|pd.name == 'Planning release'}
      planning_iteration = project.relationship_property_definitions.detect{|pd|pd.name == 'Planning iteration'}
      planning_story = project.relationship_property_definitions.detect{|pd|pd.name == 'Planning story'}

      card_selection = CardSelection.new(project, [story3])
      card_selection.update_property(planning_iteration.name, iteration2.id)

      assert_equal iteration2.name, planning_iteration.value(story3.reload).name
      assert_nil planning_release.value(story3)
    end
  end

  # bug 3390
  def test_that_update_works_with_mixed_case_card_types
    with_new_project do |project|
      configuration = project.tree_configurations.create!(:name => 'Planning')

      type_story = project.card_types.create :name => 'sTOry'
      type_iteration = project.card_types.create :name => 'iteratiON'
      type_release = project.card_types.create :name => 'RELease'

      init_three_level_tree(configuration)
      tree = configuration.create_tree

      planning_iteration = project.find_property_definition('Planning iteration')
      story1 = project.cards.find_by_name('story1')
      iteration2 = project.cards.find_by_name('iteration2')

      card_selection = CardSelection.new(project, [story1])
      card_selection.update_property(planning_iteration.name, iteration2.id)

      assert_equal [], card_selection.errors
      assert_equal iteration2.name, planning_iteration.value(story1.reload).name
    end
  end

  # bug 4701
  def test_changing_card_type_will_not_disassociate_children_of_cards_whose_type_does_not_actually_change
    release2 = @project.cards.find_by_name('release2')
    iteration3 = @project.cards.find_by_name('iteration3')
    iteration4 = @project.cards.find_by_name('iteration4')
    story2 = @project.cards.find_by_name('story2')

    card_selection = CardSelection.new(@project, [release2, iteration3])
    card_selection.update_property('Type', @type_iteration.name)

    assert_card_directly_under_root(@tree_configuration, release2.reload)
    assert_card_directly_under_root(@tree_configuration, iteration3.reload)

    assert_nil @planning_task.value(story2.reload)
    assert_nil @planning_story.value(story2)
    assert_equal 'iteration3', @planning_iteration.value(story2).name
    assert_nil @planning_release.value(story2)
    assert @tree_configuration.include_card?(story2)

    assert_card_directly_under_root(@tree_configuration, iteration4.reload)
  end

  # bug 4713
  def test_another_case_of_changing_card_type_will_not_disassociate_children_of_cards_whose_type_does_not_actually_change
    release1 = @project.cards.find_by_name('release1')
    release2 = @project.cards.find_by_name('release2')
    iteration1 = @project.cards.find_by_name('iteration1')
    iteration3 = @project.cards.find_by_name('iteration3')
    story1 = @project.cards.find_by_name('story1')
    story2 = @project.cards.find_by_name('story2')
    task2 = @project.cards.find_by_name('task2')
    task1 = @project.cards.find_by_name('task1')
    minutia1 = @project.cards.find_by_name('minutia1')
    minutia2 = @project.cards.find_by_name('minutia2')

    card_selection = CardSelection.new(@project, [iteration1, release2])
    card_selection.update_property('Type', @type_story.name)

    assert_card_directly_under_root(@tree_configuration, release2.reload)
    assert_card_directly_under_root(@tree_configuration, iteration1.reload)
    assert_card_directly_under_root(@tree_configuration, iteration3.reload)

    assert_nil @planning_task.value(story2.reload)
    assert_nil @planning_story.value(story2)
    assert_equal 'iteration3', @planning_iteration.value(story2).name
    assert_nil @planning_release.value(story2)
    assert @tree_configuration.include_card?(story2)

    assert_nil @planning_task.value(story1.reload)
    assert_nil @planning_story.value(story1)
    assert_nil @planning_iteration.value(story1)
    assert_equal 'release1', @planning_release.value(story1).name
    assert @tree_configuration.include_card?(story1)

    assert_nil @planning_task.value(task1.reload)
    assert_equal 'story1', @planning_story.value(task1).name
    assert_nil @planning_iteration.value(task1)
    assert_equal 'release1', @planning_release.value(task1).name
    assert @tree_configuration.include_card?(task1)

    assert_nil @planning_task.value(task2.reload)
    assert_equal 'story1', @planning_story.value(task2).name
    assert_nil @planning_iteration.value(task2)
    assert_equal 'release1', @planning_release.value(task2).name
    assert @tree_configuration.include_card?(task2)

    assert_equal 'task2', @planning_task.value(minutia1.reload).name
    assert_equal 'story1', @planning_story.value(minutia1).name
    assert_nil @planning_iteration.value(minutia1)
    assert_equal 'release1', @planning_release.value(minutia1).name
    assert @tree_configuration.include_card?(minutia1)

    assert_equal 'task2', @planning_task.value(minutia2.reload).name
    assert_equal 'story1', @planning_story.value(minutia2).name
    assert_nil @planning_iteration.value(minutia2)
    assert_equal 'release1', @planning_release.value(minutia2).name
    assert @tree_configuration.include_card?(minutia2)

    assert_card_directly_under_root(@tree_configuration, release1.reload)
  end

  # bug 4602, bug 5949
  def test_card_type_change_should_result_in_removal_from_tree_if_new_type_is_not_valid_for_tree
    release1 = @project.cards.find_by_name('release1')
    release2 = @project.cards.find_by_name('release2')
    iteration1 = @project.cards.find_by_name('iteration1')
    iteration3 = @project.cards.find_by_name('iteration3')
    iteration4 = @project.cards.find_by_name('iteration4')
    story1 = @project.cards.find_by_name('story1')
    story2 = @project.cards.find_by_name('story2')
    task2 = @project.cards.find_by_name('task2')
    task1 = @project.cards.find_by_name('task1')
    minutia1 = @project.cards.find_by_name('minutia1')
    minutia2 = @project.cards.find_by_name('minutia2')

    @type_card = @project.card_types.find_by_name('Card')

    card_selection = CardSelection.new(@project, [iteration1, release2])
    card_selection.update_property('Type', @type_card.name)

    assert_card_not_in_tree_and_relationships_are_nil(@tree_configuration, release2.reload)
    assert_card_not_in_tree_and_relationships_are_nil(@tree_configuration, iteration1.reload)

    assert_card_directly_under_root(@tree_configuration, iteration3.reload)
    assert_card_directly_under_root(@tree_configuration, iteration4.reload)

    assert_nil @planning_task.value(story2.reload)
    assert_nil @planning_story.value(story2)
    assert_equal 'iteration3', @planning_iteration.value(story2).name
    assert_nil @planning_release.value(story2)
    assert @tree_configuration.include_card?(story2)

    assert_nil @planning_task.value(story1.reload)
    assert_nil @planning_story.value(story1)
    assert_nil @planning_iteration.value(story1)
    assert_equal 'release1', @planning_release.value(story1).name
    assert @tree_configuration.include_card?(story1)

    assert_nil @planning_task.value(task1.reload)
    assert_equal 'story1', @planning_story.value(task1).name
    assert_nil @planning_iteration.value(task1)
    assert_equal 'release1', @planning_release.value(task1).name
    assert @tree_configuration.include_card?(task1)

    assert_nil @planning_task.value(task2.reload)
    assert_equal 'story1', @planning_story.value(task2).name
    assert_nil @planning_iteration.value(task2)
    assert_equal 'release1', @planning_release.value(task2).name
    assert @tree_configuration.include_card?(task2)

    assert_equal 'task2', @planning_task.value(minutia1.reload).name
    assert_equal 'story1', @planning_story.value(minutia1).name
    assert_nil @planning_iteration.value(minutia1)
    assert_equal 'release1', @planning_release.value(minutia1).name
    assert @tree_configuration.include_card?(minutia1)

    assert_equal 'task2', @planning_task.value(minutia2.reload).name
    assert_equal 'story1', @planning_story.value(minutia2).name
    assert_nil @planning_iteration.value(minutia2)
    assert_equal 'release1', @planning_release.value(minutia2).name
    assert @tree_configuration.include_card?(minutia2)

    assert_card_directly_under_root(@tree_configuration, release1.reload)
  end

  def display_name(card)
    "##{card.number} #{card.name}"
  end
end
