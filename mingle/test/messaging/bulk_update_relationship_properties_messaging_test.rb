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

# Tags: messaging, bulk
class BulkUpdateRelationshipPropertiesMessagingTest < ActiveSupport::TestCase
  include MessagingTestHelper
  
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
  
  def test_should_generate_changes
    minutia1 = @project.cards.find_by_name('minutia1')
    minutia2 = @project.cards.find_by_name('minutia2')
    task2 = @project.cards.find_by_name('task2')
    story1 = @project.cards.find_by_name('story1')
    
    card_selection = CardSelection.new(@project, [task2, minutia2])
    card_selection.update_property(@planning_story.name, story1.id)
    HistoryGeneration.run_once
    assert_equal 1, minutia2.reload.versions.last.changes.size
    assert_equal ["Planning task changed from ##{task2.number} task2 to (not set)"], minutia2.reload.versions.last.describe_changes
  end
  
  def test_update_creates_attachments_for_its_versions
    minutia1 = @project.cards.find_by_name('minutia1')
    minutia2 = @project.cards.find_by_name('minutia2')
    task2 = @project.cards.find_by_name('task2')
    story1 = @project.cards.find_by_name('story1')
    
    minutia2.attach_files(sample_attachment("1.gif"))
    minutia2.save!
    
    card_selection = CardSelection.new(@project, [task2, minutia2])
    card_selection.update_property(@planning_story.name, story1.id)
    
    HistoryGeneration.run_once
    last_version = minutia2.reload.versions.last
    
    assert_equal 1, last_version.attachments.size
    assert_equal 1, last_version.changes.size
  end
  
  
  # bug 3331
  def test_selecting_a_card_that_is_descendant_of_another_selected_card_will_not_create_two_versions
    minutia2 = @project.cards.find_by_name('minutia2')
    task2 = @project.cards.find_by_name('task2')
    story1 = @project.cards.find_by_name('story1')
    story2 = @project.cards.find_by_name('story2')
    iteration1 = @project.cards.find_by_name('iteration1')
    iteration3 = @project.cards.find_by_name('iteration3')
    release1 = @project.cards.find_by_name('release1')
    release2 = @project.cards.find_by_name('release2')
    
    original_minutia2_card_version = minutia2.version
    original_task2_card_version = task2.version
    
    original_minutia2_versions_size = minutia2.versions.size
    original_task2_versions_size = task2.versions.size
    
    card_selection = CardSelection.new(@project, [task2, minutia2])
    card_selection.update_property(@planning_story.name, story2.id)
    
    HistoryGeneration.run_once
    expected_change =  ["Planning release changed from #{display_name(release1)} to #{display_name(release2)}",
                       "Planning iteration changed from #{display_name(iteration1)} to #{display_name(iteration3)}",
                       "Planning story changed from #{display_name(story1)} to #{display_name(story2)}",
                       "Planning task changed from #{display_name(task2)} to (not set)"]
    assert_equal expected_change, minutia2.versions.last.describe_changes
    
    assert_equal original_minutia2_versions_size + 1, minutia2.reload.versions.size
    assert_equal original_task2_versions_size + 1, task2.reload.versions.size
    
    assert_equal original_task2_card_version + 1, task2.versions.last.version
    assert_equal original_minutia2_card_version + 1, minutia2.versions.last.version
  end
  
  
  
  # bug 3061
  def test_changing_card_type_will_remove_cards_from_tree_and_move_children_up_accordingly
    release1 = @project.cards.find_by_name('release1')
    iteration1 = @project.cards.find_by_name('iteration1')
    story1 = @project.cards.find_by_name('story1')
    minutia1 = @project.cards.find_by_name('minutia1')
    minutia2 = @project.cards.find_by_name('minutia2')
    task2 = @project.cards.find_by_name('task2')
    
    original_minutia2_card_version = minutia2.version
    original_task2_card_version = task2.version
    original_minutia1_card_version = minutia1.version
    
    card_selection = CardSelection.new(@project, [task2, minutia2])
    card_selection.update_property('Type', @type_minutia.name)
    
    assert_nil @planning_task.value(minutia1.reload)
    assert_equal 'story1', @planning_story.value(minutia1).name
    assert_equal 'iteration1', @planning_iteration.value(minutia1).name
    assert_equal 'release1', @planning_release.value(minutia1).name
    assert @tree_configuration.reload.include_card?(minutia1)
    
    assert_nil @planning_task.value(task2.reload)
    assert_nil @planning_story.value(task2)
    assert_nil @planning_iteration.value(task2)
    assert_nil @planning_release.value(task2)
    assert @tree_configuration.include_card?(task2)
    
    assert_nil @planning_task.value(minutia2.reload)
    assert_equal 'story1', @planning_story.value(minutia2).name
    assert_equal 'iteration1', @planning_iteration.value(minutia2).name
    assert_equal 'release1', @planning_release.value(minutia2).name
    assert @tree_configuration.include_card?(minutia2)
    
    assert_equal original_minutia1_card_version + 1, minutia1.version
    assert_equal original_minutia2_card_version + 1, minutia2.version
    assert_equal original_task2_card_version + 1, task2.version
    
    HistoryGeneration.run_once
    
    expected_change =  ["Planning release changed from #{display_name(release1)} to (not set)",
                       "Planning iteration changed from #{display_name(iteration1)} to (not set)",
                       "Planning story changed from #{display_name(story1)} to (not set)",
                       "Type changed from task to minutia"]
    assert_equal expected_change.sort, task2.reload.versions.last.describe_changes.sort
    
    assert_equal ["Planning task changed from #{display_name(task2)} to (not set)"], minutia2.reload.versions.last.describe_changes
    assert_equal ["Planning task changed from #{display_name(task2)} to (not set)"], minutia1.reload.versions.last.describe_changes
  end
  
  def test_update_creates_taggings_for_its_versions
    minutia1 = @project.cards.find_by_name('minutia1')
    minutia2 = @project.cards.find_by_name('minutia2')
    task2 = @project.cards.find_by_name('task2')
    story1 = @project.cards.find_by_name('story1')
    
    minutia2.tag_with('apple')
    minutia2.save!
    
    card_selection = CardSelection.new(@project, [task2, minutia2])
    card_selection.update_property(@planning_story.name, story1.id)
    
    HistoryGeneration.run_once
    last_version = minutia2.reload.versions.last
    
    assert last_version.tags.collect(&:name).include?('apple')
    assert_equal 1, last_version.changes.size
  end
  
  def test_changing_card_type_of_two_cards_that_are_related_does_not_create_multiple_card_versions_for_same_card
    release1 = @project.cards.find_by_name('release1')
    release2 = @project.cards.find_by_name('release2')
    iteration1 = @project.cards.find_by_name('iteration1')
    iteration2 = @project.cards.find_by_name('iteration2')
    iteration3 = @project.cards.find_by_name('iteration3')
    story1 = @project.cards.find_by_name('story1')
    story2 = @project.cards.find_by_name('story2')
    task2 = @project.cards.find_by_name('task2')
    task1 = @project.cards.find_by_name('task1')
    minutia1 = @project.cards.find_by_name('minutia1')
    minutia2 = @project.cards.find_by_name('minutia2')
    
    original_task2_version = task2.version
    
    card_selection = CardSelection.new(@project, [iteration1, task2])
    card_selection.update_property('Type', @type_story.name)
    
    HistoryGeneration.run_once
    
    assert_card_directly_under_root(@tree_configuration, iteration1.reload)
    assert_card_directly_under_root(@tree_configuration, task2.reload)
    assert_card_directly_under_root(@tree_configuration, release1.reload)
    
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
    
    assert_nil @planning_task.value(minutia1.reload)
    assert_equal 'story1', @planning_story.value(minutia1).name
    assert_nil @planning_iteration.value(minutia1)
    assert_equal 'release1', @planning_release.value(minutia1).name
    assert @tree_configuration.include_card?(minutia1)
    
    assert_nil @planning_task.value(minutia2.reload)
    assert_equal 'story1', @planning_story.value(minutia2).name
    assert_nil @planning_iteration.value(minutia2)
    assert_equal 'release1', @planning_release.value(minutia2).name
    assert @tree_configuration.include_card?(minutia2)
    
    assert_equal original_task2_version + 1, task2.reload.version
    assert_equal ["Planning release changed from #{display_name(release1)} to (not set)", "Planning iteration changed from #{display_name(iteration1)} to (not set)", "Type changed from task to story", "Planning story changed from #{display_name(story1)} to (not set)"], task2.versions.last.describe_changes
  end
  
  def display_name(card)
    "##{card.number} #{card.name}"
  end
end
