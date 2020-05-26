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

class CardMessagingTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  include MessagingTestHelper

  def setup
    @project = first_project
    @project.activate
    login_as_member
  end

  def test_generate_changes
    create_project(:users => [User.find_by_login('member')]) do |project|
      setup_property_definitions :status => ['new']
      card1 = create_card!(:name => 'card1')
      card1.update_attribute :cp_status, 'new'
      card1.reload

      property_definition = project.find_property_definition('status')
      property_definition.update_attribute(:hidden, true)

      project.reload
      card1.reload
      HistoryGeneration.run_once

      assert_equal 2, card1.versions.length
      assert_equal 2, card1.versions[0].changes.length # name & card_type
      assert_equal 1, card1.versions[1].changes.length

      project.generate_changes
      HistoryGeneration.run_once
      card1.reload

      assert_equal 2, card1.versions.length
      assert_equal 2, card1.versions[0].changes.length
      assert_equal 1, card1.versions[1].changes.length
    end
  end

  def test_diff_should_show_the_attachments_change
    card = Card.new(:name => "card for testing attachment version", :project => @project, :card_type => @project.card_types.first)
    card.attach_files(sample_attachment("1.gif"))
    card.save!
    HistoryGeneration.run_once
    assert card.reload.versions.last.describe_changes.include?("Attachment added 1.gif")
    card.attach_files(sample_attachment("2.gif"))
    card.save!
    HistoryGeneration.run_once
    assert_equal 2, card.reload.versions.count
    assert card.reload.versions.last.describe_changes.include?("Attachment added 2.gif")
  end

  def test_should_show_delete_attachments_changes
    card = create_card!(:name => "card for testing attachment version")
    card.attach_files(sample_attachment)
    card.save!

    card.remove_attachment(card.attachments.first.file_name)
    card.save!
    HistoryGeneration.run_once
    assert_equal 'Attachment removed sample_attachment.txt', card.find_version(3).describe_changes.first
  end

  def test_changes_should_include_system_generated_comments
    card = @project.cards.first
    card.system_generated_comment = 'You has system generated comment'
    card.save!
    HistoryGeneration.run_once
    assert_equal "System generated comment: You has system generated comment", card.versions.last.describe_changes.join
  end

  def test_text_property_change_creates_changes
    first_card = @project.cards.first
    versions_before_change = first_card.versions.size
    first_card.update_attributes(:cp_id => 'text value')
    HistoryGeneration.run_once
    versions_after_change = first_card.reload.versions.size

    assert_equal 1, versions_after_change - versions_before_change
    assert_equal 1, first_card.versions.last.event.changes.size
    assert_equal "id set to text value", first_card.versions.last.describe_changes.join
  end

  def test_property_changes_return_property_name_and_only_new_value_if_previous_value_is_nil
    card = create_card!(:name => 'first name')
    card.cp_status = 'new'
    card.cp_priority = 'high'
    card.save!
    HistoryGeneration.run_once

    assert_change({:status => [nil, 'new'], :priority => [nil, 'high']}, card.reload.versions[1].property_changes)
  end

  def test_diff_against_nil_version_empty_if_no_tags
    card = create_card!(:name => 'first name', :card_type => @project.card_types.first)
    HistoryGeneration.run_once
    assert_equal 2, card.reload.versions[0].changes.size
  end

  def test_diff_includes_name_change
    card =create_card!(:name => 'first name')
    card.update_attributes(:name => 'second name')

    HistoryGeneration.run_once
    assert_change({:name => ['first name', 'second name']}, card.reload.versions[1].changes)
  end

  def test_diff_includes_description_change
    card =create_card!(:name => 'first name', :description => 'this is a card!')
    assert card.update_attributes(:description => 'card descriptions are FUNKY')
    HistoryGeneration.run_once
    assert_change({:description => [nil, nil]}, card.reload.versions[1].changes)
  end

  def test_diff_includes_new_tags_and_property_values
     card = @project.cards.new(:name => 'first name', :project => @project, :card_type => @project.card_types.first)
     card.tag_with('hey')
     card.cp_status = 'open'
     card.cp_iteration = '2'
     card.save!
     HistoryGeneration.run_once
     assert_equal 5, card.reload.versions[0].changes.size
     assert_change({:status => [nil, 'open'], :iteration => [nil, '2'], :tags => [nil, 'hey'], :name => [nil, 'first name'], :type => [nil, @project.card_types.first.name]}, card.reload.versions[0].changes)
   end

   def test_diff_includes_removed_tags_and_property_values
     card = @project.cards.new(:name => 'first name', :project => @project, :cp_status => 'new', :card_type => @project.card_types.first)
     card.tag_with('hey')
     card.save!

     card.cp_status = nil
     card.tag_with([])
     card.save!

     HistoryGeneration.run_once
     assert_change({:status => ['new', nil], :tags => ['hey', nil]}, card.reload.versions[1].changes)
   end

   def test_diff_excludes_tags_removed_or_added_fields_if_no_tags_removed_or_added
     card = @project.cards.new(:name => 'first name', :project => @project, :card_type => @project.card_types.first)
     card.tag_with('status-fixed').save!
     card.update_attributes(:name => "new name")
     HistoryGeneration.run_once
     assert_change({:name => ['first name', 'new name']}, card.reload.versions[1].changes)
   end

   def test_description_change_does_not_provide_to_and_from_values
     card =create_card!(:name => 'first name', :description => 'v1')
     card.description = "v2"
     card.save!
     HistoryGeneration.run_once
     assert_equal "Description changed", card.reload.versions[1].changes[0].describe
   end

   def test_changes_tag_with_ungroup_tag_should_be_due_to_that_tag
     card = create_card!(:name => 'first name')
     card.tag_with('atom')
     card.save!
     card.tag_with('atom, rss')
     card.save!
     HistoryGeneration.run_once
     versions = card.reload.versions

     assert_equal @project.tag_named('atom'), versions[1].changes.first.tag
   end

  def test_should_recompute_aggregates_when_card_in_tree_is_deleted
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      @project = project
      @tree_configuration = configuration
      @type_release, @type_iteration, @type_story = find_planning_tree_types

      release1, iteration1, story1 = ['release1', 'iteration1', 'story1'].collect { |card_name| @project.cards.find_by_name(card_name) }

      story_count_for_release = setup_aggregate_property_definition('story count for release', AggregateType::COUNT, nil, @tree_configuration.id, @type_release.id, @type_story)
      story_count_for_iteration = setup_aggregate_property_definition('story count for iteration', AggregateType::COUNT, nil, @tree_configuration.id, @type_iteration.id, @type_story)

      [story_count_for_release, story_count_for_iteration].each(&:update_cards)
      all_messages_from_queue('mingle.compute_aggregates.cards')

      story1.destroy

      assert_equal 2, all_messages_from_queue('mingle.compute_aggregates.cards').size
    end
  end

  private
  def assert_change(expected_changes, actual_changes)
    assert_equal expected_changes.size, actual_changes.size
    actual_changes.each do |change|
      assert(expected_changes.any? do |field_name, values|
        change.field.ignore_case_equal?(field_name.to_s) and [change.old_value, change.new_value] == values
      end)
    end
  end

end
