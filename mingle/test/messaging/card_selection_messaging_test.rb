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
require File.expand_path(File.dirname(__FILE__) + '/messaging_test_helper')

# Tags: messaging, indexing
class CardSelectionMessagingTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  include MessagingTestHelper

  def setup
    login_as_member
    @project = card_selection_project
    @project.activate
    @cards = @project.cards
    @card_selection = CardSelection.new(@project.reload, @cards)
  end
  
  def test_remove_tag_should_generate_changes
    card_1 = @project.cards[0]
    card_2 = @project.cards[1]
    card_3 = @project.cards[2]
    
    card_1.tag_with(['ratchet']).save!
    card_2.tag_with(['ratchet']).save!    
    card_3.tag_with(['ratchet']).save!    
    
    @card_selection = CardSelection.new(@project, [card_1, card_2])
    @card_selection.remove_tag('ratchet')

    HistoryGeneration.run_once
    assert_equal 1, card_1.reload.versions.last.changes.size    
    assert_equal 'ratchet', card_1.reload.versions.last.changes[0].removed_tag.name
    assert_equal 1, card_2.reload.versions.last.changes.size
    assert_equal 'ratchet', card_2.reload.versions.last.changes[0].removed_tag.name
    # Assert change was limited to the two cards passed in to card selection.
    assert_equal 1, card_3.reload.versions.last.changes.size
    assert_equal 'ratchet', card_3.reload.versions.last.changes[0].added_tag.name
  end
  
  def test_update_properties_should_generate_changes
    card_1 = @project.cards[0]
    card_2 = @project.cards[1]
    @card_selection = CardSelection.new(@project, [card_1, card_2])
    @card_selection.update_properties('Status' => 'open')
    HistoryGeneration.run_once
    assert_equal 1, card_1.reload.versions.last.changes.size
    assert_equal 1, card_2.reload.versions.last.changes.size
  end
  
  
  def test_update_properties_does_not_generate_changes_for_formula_properties_not_available_to_the_types_of_cards_updated
    create_project.with_active_project do |project|
      story_type = project.card_types.create!(:name => 'story')
      bug_type = project.card_types.create!(:name => 'bug')
      
      min_size = setup_numeric_text_property_definition('min size')
      max_size = setup_numeric_text_property_definition('max size')
      
      bug_size = setup_formula_property_definition('bug size', "('min size' + 'max size')/2")
      story_size = setup_formula_property_definition('story size', "'min size' + 'max size'")
      project.card_types.find_by_name('Card').destroy
      
      bug_type.save!
      bug_type.reload.property_definitions = [min_size, max_size, bug_size]
      bug_type.save!
      
      story_type.save!
      story_type.reload.property_definitions = [min_size, max_size, story_size]
      story_type.save!
      
      bug = create_card!(:name => 'bug', :card_type => bug_type, 'min size' => '1', 'max size' => '3')
      story = create_card!(:name => 'story', :card_type => story_type, 'min size' => '3', 'max size' => '8')

      CardSelection.new(project, [bug]).update_properties('max size' => '5')

      HistoryGeneration.run_once()
      assert_changed_fields(bug, 'max size', 'bug size')
      assert_no_changed_fields(bug, 'story size')
      
      CardSelection.new(project, [story]).update_properties('max size' => '5')
      HistoryGeneration.run_once()
      assert_changed_fields(story, 'max size', 'story size')
      assert_no_changed_fields(story, 'bug size')
      
      CardSelection.new(project, [story, bug]).update_properties('max size' => '5')
      HistoryGeneration.run_once()
      assert_changed_fields(story, 'max size', 'story size')
      assert_no_changed_fields(story, 'bug size')
      assert_changed_fields(bug, 'max size', 'bug size')
      assert_no_changed_fields(bug, 'story size')
    end
  end
  
  
  def test_update_properties_creates_attachments_for_its_versions
    card = @cards.first
    card.attach_files(sample_attachment("1.gif"))
    card.save!
    @card_selection.update_properties('Status' => 'open')
    HistoryGeneration.run_once
    last_version = card.reload.versions.last

    assert_equal 1, last_version.attachments.size
    assert_equal 1, last_version.changes.size
  end
  
  def test_update_properties_creates_taggings_for_its_versions
    card = @cards.first
    card.tag_with('apple')
    card.save!
    @card_selection.update_properties('Status' => 'open')
    HistoryGeneration.run_once
    last_version = card.reload.versions.last

    assert last_version.tags.collect(&:name).include?('apple')
    assert_equal 1, last_version.changes.size
  end
  
  def test_tag_with_creates_attachments_for_its_versions
    card = @cards.first
    card.attach_files(sample_attachment("1.gif"))
    card.save!
    @card_selection.tag_with('ratchet')
    HistoryGeneration.run_once
    last_version = card.reload.versions.last

    assert_equal 1, last_version.attachments.size
    assert_equal 1, last_version.changes.size
  end
  
  def test_tag_with_should_generate_changes
    card_1 = @project.cards[0]
    card_2 = @project.cards[1]
  
    @card_selection = CardSelection.new(@project, [card_1, card_2])
    @card_selection.tag_with('ratchet')

    HistoryGeneration.run_once

    assert_equal 1, card_1.reload.versions.last.changes.size
    assert_equal 1, card_2.reload.versions.last.changes.size
  end  
  
  
  
  ##################################################################################################
  #                                 ---------------Planning tree-----------------
  #                                |                                            |
  #                    ----- release1----                                -----release2-----
  #                   |                 |                               |                 |
  #              iteration1      iteration2                       iteration3          iteration4
  #                  |                                                 |
  #           ---story1----                                         story2        
  #          |           |
  #       task1   -----task2----
  #              |             |  
  #          minutia1       minutia2      
  #           
  ##################################################################################################
  def test_destroy_will_recompute_aggregates_for_relevant_parent_cards
    create_tree_project(:init_five_level_tree) do |project, tree, configuration|
      type_release, type_iteration, type_story, type_task, type_minutia = find_five_level_tree_types
    
      minutia1 = project.cards.find_by_name('minutia1')
      minutia2 = project.cards.find_by_name('minutia2')
      task1 = project.cards.find_by_name('task1')
      story2 = project.cards.find_by_name('story2')
      iteration3 = project.cards.find_by_name('iteration3')
      release2 = project.cards.find_by_name('release2')
      release1 = project.cards.find_by_name('release1')
      iteration1 = project.cards.find_by_name('iteration1')
      story1 = project.cards.find_by_name('story1')
    
      minutia_count_for_release = setup_aggregate_property_definition('minutia count for release', AggregateType::COUNT, nil, configuration.id, type_release.id, type_minutia)
      minutia_count_for_iteration = setup_aggregate_property_definition('minutia count for iteration', AggregateType::COUNT, nil, configuration.id, type_iteration.id, type_minutia)
      minutia_count_for_story = setup_aggregate_property_definition('minutia count for story', AggregateType::COUNT, nil, configuration.id, type_story.id, type_minutia)
      task_count_for_story = setup_aggregate_property_definition('task count for story', AggregateType::COUNT, nil, configuration.id, type_story.id, type_task)
    
      [minutia_count_for_release, minutia_count_for_iteration, minutia_count_for_story, task_count_for_story].each(&:update_cards)

      all_messages_from_queue('mingle.compute_aggregates.cards')

      CardSelection.new(project, [task1, minutia1]).destroy
      assert_equal 4, all_messages_from_queue('mingle.compute_aggregates.cards').size
    end
  end

  def test_should_not_recompute_aggregates_for_deleted_parent_cards_while_destroying
    create_tree_project(:init_five_level_tree) do |project, tree, configuration|
      type_release, type_iteration, type_story, type_task, type_minutia = find_five_level_tree_types
    
      minutia1 = project.cards.find_by_name('minutia1')
      minutia2 = project.cards.find_by_name('minutia2')
      task1 = project.cards.find_by_name('task1')
      story2 = project.cards.find_by_name('story2')
      iteration3 = project.cards.find_by_name('iteration3')
      release2 = project.cards.find_by_name('release2')
      release1 = project.cards.find_by_name('release1')
      iteration1 = project.cards.find_by_name('iteration1')
      story1 = project.cards.find_by_name('story1')
    
      minutia_count_for_release = setup_aggregate_property_definition('minutia count for release', AggregateType::COUNT, nil, configuration.id, type_release.id, type_minutia)
      minutia_count_for_iteration = setup_aggregate_property_definition('minutia count for iteration', AggregateType::COUNT, nil, configuration.id, type_iteration.id, type_minutia)
      minutia_count_for_story = setup_aggregate_property_definition('minutia count for story', AggregateType::COUNT, nil, configuration.id, type_story.id, type_minutia)
      task_count_for_story = setup_aggregate_property_definition('task count for story', AggregateType::COUNT, nil, configuration.id, type_story.id, type_task)
    
      [minutia_count_for_release, minutia_count_for_iteration, minutia_count_for_story, task_count_for_story].each(&:update_cards)

      all_messages_from_queue('mingle.compute_aggregates.cards')

      CardSelection.new(project, [task1, story1]).destroy
      assert_equal 2, all_messages_from_queue('mingle.compute_aggregates.cards').size
    end
  end
  
  def assert_changed_fields(versioned, *field_names)
    changes = versioned.versions.reload.last.changes
    assert_equal field_names.size, changes.size
    field_names.each do |field_name| 
      assert changes.any? { |change| change.field == field_name }
    end  
  end

  def assert_no_changed_fields(versioned, *field_names)
    changes = versioned.versions.reload.last.changes
    field_names.each do |field_name| 
      assert !changes.any? { |change| change.field == field_name }
    end  
  end

  
end
