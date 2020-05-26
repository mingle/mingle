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

# Tags: messaging, history, indexing
class CardImportMessagingTest < ActiveSupport::TestCase
  include MessagingTestHelper, TreeFixtures::PlanningTree, CardImporterTestHelper

  def test_should_index_cards_after_imported
    route(:from => FullTextSearch::IndexingCardsProcessor::QUEUE, :to => TEST_QUEUE)
    login_as_member
    with_new_project do |project|
      content = <<-CSV
        Number\tName\t
        1\tnew_name_for_card_number1\t
      CSV
      import(content)
      FullTextSearch.run_once

      messages = all_messages_from_queue

      assert_equal 1, messages.size, "Should have received one message for the card being imported"
      assert_equal project.cards.first.id, messages.first.body_hash[:id], "Got message for the wrong card"
    end
  end

  def test_should_deliver_messages_while_processing_all_card_imports
    login_as_member
    with_new_project do |project|
      excel = <<-CSV
        Number\tName\t
        1\tnew_name_for_card_number1\t
      CSV
      with_excel_content_file(excel) do |raw_excel_content_file_path|
        create_card_importer!(project, raw_excel_content_file_path)
        CardImportProcessor.run_once
        assert_equal 1, all_messages_from_queue('mingle.feed_cache_populating').size
        assert_equal 1, all_messages_from_queue('mingle.indexing.cards').size
        assert_equal 1, all_messages_from_queue('mingle.history_changes_generation.cards').size
      end
    end
  end

  # bug 3663
  def test_should_create_appropriate_changes_when_removing_card_from_tree_and_renaming_card_at_same_time
    login_as_member
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      release1 = project.cards.find_by_name('release1')
      iteration1 = project.cards.find_by_name('iteration1')
      story1 = project.cards.find_by_name('story1')
      story2 = project.cards.find_by_name('story2')

      assert configuration.include_card?(story1)
      content = <<-CSV
        Number\tName\tDescription\tType\tPlanning\tPlanning iteration\tPlanning release
        #{iteration1.number}\titerationNewName\t\titeration\tno\t\t##{release1.number}
      CSV
      import(content, :tree_configuration_id => configuration.id)
      [story1, story2, iteration1].collect(&:reload)
      HistoryGeneration.run_once

      assert !configuration.reload.include_card?(iteration1)
      assert_nil iteration1.cp_planning_release_card_id
      assert_equal ["Name changed from iteration1 to iterationNewName",
                    "Planning release changed from #1 release1 to (not set)"].sort, iteration1.versions.last.describe_changes.sort

      assert configuration.reload.include_card?(story1)
      assert_equal release1.id, story1.cp_planning_release_card_id
      assert_nil story1.cp_planning_iteration_card_id
      assert_equal ["Planning iteration changed from #2 iterationNewName to (not set)"], story1.versions.last.describe_changes

      assert configuration.reload.include_card?(story2)
      assert_equal release1.id, story2.cp_planning_release_card_id
      assert_nil story2.cp_planning_iteration_card_id
      assert_equal ["Planning iteration changed from #2 iterationNewName to (not set)"], story2.versions.last.describe_changes
    end
  end

end
