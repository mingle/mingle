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
class CardPropertyIndexingTest < ActiveSupport::TestCase
  include MessagingTestHelper

  def test_should_reindex_cards_if_property_definition_is_deleted
    route(:from => FullTextSearch::IndexingCardsProcessor::QUEUE, :to => TEST_QUEUE)
    with_new_project do | project |
      assert_equal 0, all_messages_from_queue.length
      login_as_admin

      estimate = setup_numeric_text_property_definition('estimate')
      card_type = project.card_types.first

      project.cards.create! :name => "something", :card_type => card_type
      project.cards.create! :name => "something else", :card_type => card_type
      clear_message_queue

      estimate.destroy
      FullTextSearch::IndexingBulkCardsProcessor.run_once

      assert_equal 2, all_messages_from_queue.length
    end
  end

  def test_should_reindex_cards_if_property_definition_value_changes
    route(:from => FullTextSearch::IndexingCardsProcessor::QUEUE, :to => TEST_QUEUE)
    with_new_project do | project |
      assert_equal 0, all_messages_from_queue.length
      login_as_admin

      estimate = setup_numeric_property_definition('estimate', [1, 2, 3, 4])
      card_type = project.card_types.first
      card_type.card_defaults.update_properties([['estimate', 1]])

      project.cards.create! :name => "something", :card_type => card_type
      project.cards.create! :name => "something else", :card_type => card_type
      clear_message_queue

      first_entry = estimate.values.first
      first_entry.value = "99"
      first_entry.save!

      FullTextSearch::IndexingBulkCardsProcessor.run_once

      assert_equal 2, all_messages_from_queue.length
    end
  end

  def test_should_reindex_cards_if_property_definition_is_renamed
    route(:from => FullTextSearch::IndexingCardsProcessor::QUEUE, :to => TEST_QUEUE)
    with_new_project do | project |
      assert_equal 0, all_messages_from_queue.length
      login_as_admin

      estimate = setup_numeric_property_definition('estimate', [1, 2, 3, 4])
      card_type = project.card_types.first

      project.cards.create! :name => "something", :card_type => card_type
      project.cards.create! :name => "something else", :card_type => card_type

      clear_message_queue

      estimate.name = "new estimate"
      estimate.save!

      FullTextSearch::IndexingBulkCardsProcessor.run_once

      assert_equal 2, all_messages_from_queue.length
    end
  end

  def test_should_reindex_cards_on_bulk_updation_of_card_properties
    route(:from => FullTextSearch::IndexingCardsProcessor::QUEUE, :to => TEST_QUEUE)
    with_new_project do | project |
      assert_equal 0, all_messages_from_queue.length
      login_as_admin

      estimate = setup_numeric_property_definition('estimate', [1, 2, 3, 4])
      card_type = project.card_types.first

      card = project.cards.create! :name => "something", :card_type => card_type
      project.cards.create! :name => "something else", :card_type => card_type

      clear_message_queue

      updater = Bulk::BulkUpdateProperties.new(project, CardIdCriteria.new("IN (#{card.id})"))
      updater.update_properties({'estimate' => 2})

      FullTextSearch::IndexingBulkCardsProcessor.run_once

      assert_equal 1, all_messages_from_queue.length
    end
  end

  def test_should_reindex_cards_if_property_definition_card_type_association_changes
    route(:from => FullTextSearch::IndexingCardsProcessor::QUEUE, :to => TEST_QUEUE)
    with_new_project do | project |
      assert_equal 0, all_messages_from_queue.length
      login_as_admin

      estimate = setup_numeric_property_definition('estimate', [1, 2, 3, 4])

      twice_the_estimate = setup_formula_property_definition('twice_the_estimation', "estimate * 2")

      first_card_type = project.card_types.first
      project.cards.create! :name => "something", :card_type => first_card_type, :cp_estimate => "3"
      project.cards.create! :name => "something else", :card_type => first_card_type, :cp_estimate => "3"
      project.card_types.create :name => "Release"
      second_card_type = project.card_types.second
      clear_message_queue

      twice_the_estimate.update_attributes :card_types => [second_card_type]
      FullTextSearch::IndexingBulkCardsProcessor.run_once

      assert_equal 2, all_messages_from_queue.length
    end
  end

end
