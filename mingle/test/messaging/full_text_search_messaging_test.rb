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
class FullTextSearchMessagingTest < ActiveSupport::TestCase
  include MessagingTestHelper

  def setup
    @bob = User.find_by_login("bob")
    @bobs_name = @bob.name
  end

  def teardown
    @bob.update_attribute :name, @bobs_name
    logout_as_nil
  end

  def test_index_cards_puts_messages_into_the_bulk_card_queue
    route(:from => FullTextSearch::IndexingBulkCardsProcessor::QUEUE, :to => TEST_QUEUE)
    login_as_admin

    with_first_project do |project|
      all_cards = project.cards
      assert all_cards.size > 0

      FullTextSearch.index_cards(project)
      messages = all_messages_from_queue

      assert_equal 1, messages.size
      assert_equal project.id, messages.first[:project_id]
      assert_equal  all_cards.map(&:id).sort, messages.first[:ids].split(",").map(&:to_i).sort
    end
  end

  def test_bulk_indexing_processor_generates_individual_messages
    route(:from => FullTextSearch::IndexingCardsProcessor::QUEUE, :to => TEST_QUEUE)
    login_as_admin

    with_first_project do |project|
      all_cards = project.cards
      assert all_cards.size > 0

      put_message_on_bulk_card_queue(project)
      FullTextSearch::IndexingBulkCardsProcessor.run_once
      messages = all_messages_from_queue

      assert_messages_equal project.cards.collect(&:message).sort_by{|m|m[:id]}, messages.sort_by{|m|m[:id]}
      assert_equal [], all_messages_from_queue(FullTextSearch::IndexingPagesProcessor::QUEUE)
      assert_equal [], all_messages_from_queue(FullTextSearch::IndexingMurmursProcessor::QUEUE)
    end
  end

  def test_should_reindex_only_cards_created_by_user_when_user_name_changed
    route(:from => FullTextSearch::IndexingCardsProcessor::QUEUE, :to => TEST_QUEUE)
    with_first_project do | project |
      assert_equal 0, all_messages_from_queue.length
      login_as_member
      create_card!(:name => 'members_card')

      bob = login_as_bob
      bobs_card = create_card!(:name => 'bobs_card')

      clear_message_queue

      bob.update_attribute :name, 'bobs new user name'
      FullTextSearch.run_once

      queue = all_messages_from_queue
      assert_equal 1, queue.length
      assert queue.first, bobs_card.message
    end
  end

  def test_should_reindex_only_cards_modified_by_users_when_user_name_changed
    route(:from => FullTextSearch::IndexingCardsProcessor::QUEUE, :to => TEST_QUEUE)
    with_first_project do | project |
      assert_equal 0, all_messages_from_queue.length
      login_as_member
      members_card = create_card!(:name => 'members_card')

      bob = login_as_bob
      members_card.name = "now bobs_card"
      members_card.save!

      clear_message_queue

      bob.update_attribute :name, 'bobs new user name'
      FullTextSearch::IndexingUsersProcessor.run_once

      queue = all_messages_from_queue
      assert_equal 1, queue.length
      assert queue.first, members_card.message
    end
  end

  def test_should_reindex_only_pages_created_by_user_when_user_name_changed
    route(:from => FullTextSearch::IndexingPagesProcessor::QUEUE, :to => TEST_QUEUE)
    with_first_project do | project |
      assert_equal 0, all_messages_from_queue.length
      login_as_member
      project.pages.create!(:name => 'members_page')

      bob = login_as_bob
      bobs_card = project.pages.create!(:name => 'bobs_page')

      clear_message_queue

      bob.update_attribute :name, 'bobs new user name'
      FullTextSearch::IndexingUsersProcessor.run_once

      queue = all_messages_from_queue
      assert_equal 1, queue.length
      assert queue.first, bobs_card.message
    end
  end

  def test_should_reindex_only_pages_modified_by_users_when_user_name_changed
    route(:from => FullTextSearch::IndexingPagesProcessor::QUEUE, :to => TEST_QUEUE)
    with_first_project do | project |
      assert_equal 0, all_messages_from_queue.length
      login_as_member
      members_page = project.pages.create!(:name => 'another_members_page')

      bob = login_as_bob
      members_page.name = "now bobs_page"
      members_page.save!

      clear_message_queue

      bob.update_attribute :name, 'bobs new user name'
      FullTextSearch::IndexingUsersProcessor.run_once

      queue = all_messages_from_queue
      assert_equal 1, queue.length
      assert queue.first, members_page.message
    end
  end

  def test_project_indexing_request_should_be_split_as_card_indexing_queue
    login_as_bob

    with_first_project do |project|
      project.update_full_text_index

      assert project.cards.size > 0

      FullTextSearch::IndexingProjectsProcessor.run_once

      delivered_messages = all_messages_from_queue(FullTextSearch::IndexingCardsProcessor::QUEUE)
      assert_messages_equal project.cards.collect(&:message).sort_by{|m|m[:id]}, delivered_messages.sort_by{|m|m[:id]}
    end
  end

  def test_indexing_card_to_update_full_text_index
    route(:from => FullTextSearch::IndexingCardsProcessor::QUEUE, :to => TEST_QUEUE)
    login_as_admin
    with_new_project do |project|
      card = project.cards.create!(:name => 'first card', :card_type_name => 'Card')
      card.update_attribute :name, 'new name for card'

      FullTextSearch::IndexingCardsProcessor.run_once
      assert_message_in_queue card.message
    end
  end

  def test_project_indexing_request_should_be_split_as_page_indexing_queue
    bob = login_as_bob
    route(:from => FullTextSearch::IndexingPagesProcessor::QUEUE, :to => TEST_QUEUE)
    with_first_project do |project|
      assert project.pages.size > 0
      project.update_full_text_index

      FullTextSearch::IndexingProjectsProcessor.run_once

      project.pages.find(:all).sort_by{|page|page.id}.reverse.each do |page|
        assert_message_in_queue page.message
      end
    end
  end

  def test_should_not_send_indexing_page_belonging_to_another_project_while_processing_indexing_project_request
    bob = login_as_bob
    with_new_project do |project|
      project.pages.create!(:name => 'sss_page_name')
    end
    route(:from => FullTextSearch::IndexingPagesProcessor::QUEUE, :to => TEST_QUEUE)
    with_first_project do |project|
      project.pages.delete_all
      project.update_full_text_index
      FullTextSearch::IndexingProjectsProcessor.run_once
      assert_receive_nil_from_queue
    end
  end

  def test_indexing_page_to_update_full_text_index
    route(:from => FullTextSearch::IndexingPagesProcessor::QUEUE, :to => TEST_QUEUE)
    login_as_member

    with_first_project do |project|
      page = project.pages.first
      page.update_attribute :content, 'new page content should be uniq'

      FullTextSearch::IndexingPagesProcessor.run_once
      assert_message_in_queue page.message
    end
  end

  def test_project_indexing_request_should_be_split_into_murmurs_indexing_queue
    bob = login_as_bob
    route(:from => FullTextSearch::IndexingMurmursProcessor::QUEUE, :to => TEST_QUEUE)
    with_first_project do |project|
      murmur = create_murmur

      FullTextSearch.run_once

      assert_message_in_queue murmur.message
    end
  end

  def test_should_ignore_failure_when_indexing_failed
    with_first_project do |project|
      FullTextSearch::IndexingSearchablesProcessor.new.on_message({:project_id => project.id, :type => '__NotExistingClass'})
    end
  end

  def test_index_project_cards_with_card_ids
    route(:from => FullTextSearch::IndexingCardsProcessor::QUEUE, :to => TEST_QUEUE)

    login_as_admin
    with_new_project do |project|
      card_1 = project.cards.create!(:name => 'first card', :card_type_name => 'Card')
      card_2 = project.cards.create!(:name => 'second card', :card_type_name => 'Card')
      FullTextSearch.index_card_selection(project, [card_1.id, card_2.id])

      assert_messages_equal [card_1.message, card_2.message].sort_by{|c|c[:id]}, all_messages_from_queue.sort_by{|c|c[:id]}
    end
  end

  def test_should_not_send_dup_and_nil_card_id_when_indexing_project_cards_with_card_ids
    route(:from => FullTextSearch::IndexingBulkCardsProcessor::QUEUE, :to => TEST_QUEUE)

    login_as_bob
    with_first_project do |project|
      card_1 = project.cards.first
      FullTextSearch.index_card_selection(project, [card_1.id, card_1.id, nil])

      messages = all_messages_from_queue
      assert_equal 1, messages.size, "Should have received just one message on the queue, looks like we're sending a message for dups as well'"

      expected_message = {:project_id => project.id, :ids => card_1.id.to_s}
      assert_equal [expected_message], messages.collect(&:body_hash)
    end
  end

  def test_bulk_murmurs_processor_splits_message_into_regular_murmur_indexing_messages
    route(:from => FullTextSearch::IndexingMurmursProcessor::QUEUE, :to => TEST_QUEUE)
    admin = login_as_admin

    with_new_project do |project|
      murmur_1 = create_murmur(:murmur => 'hi', :author => admin)
      murmur_2 = create_murmur(:murmur => 'there', :author => admin)
      FullTextSearch.index_bulk_murmurs(project, [murmur_1.id, murmur_2.id])

      assert_messages_equal  sort_by_id([murmur_1.message, murmur_2.message]), sort_by_id(all_messages_from_queue)
    end
  end

  def test_index_murmurs
    route(:from => FullTextSearch::IndexingMurmursProcessor::QUEUE, :to => TEST_QUEUE)
    admin = login_as_admin
    with_new_project do |project|
      m1 = project.murmurs.create!(:murmur  => 'hello world', :author => admin)
      m2 = project.murmurs.create!(:murmur => 'hello world again', :author => admin)

      assert_messages_equal sort_by_id([m1.message, m2.message]), sort_by_id(all_messages_from_queue)
    end
  end

  def test_index_murmurs_from_card_comments
    route(:from => FullTextSearch::IndexingMurmursProcessor::QUEUE, :to => TEST_QUEUE)
    login_as_admin
    with_new_project do |project|
      card = project.cards.create!(:name => 'first card', :card_type_name => 'Card')
      card.add_comment :content => 'hello world'
      murmur = find_murmur_from(card)
      assert_messages_equal  [murmur.message], all_messages_from_queue
    end
  end

  def test_index_all_projects
    route(:from => FullTextSearch::IndexingProjectsProcessor::QUEUE, :to => TEST_QUEUE)
    login_as_admin
    # make sure we at least have one project
    create_project

    FullTextSearch::IndexingSiteProcessor.enqueue
    FullTextSearch.run_once

    project_ids = Project.not_hidden.map(&:id).sort
    assert_equal project_ids, all_messages_from_queue.map{|m| m[:id]}.sort
  end

  def test_processor_should_not_swallow_index_update_error
    processor = FakeSearchableProcessor.new
    with_new_project do |project|
      message = {:project_id => project.id, :id => 1}
      assert_raises(ElasticSearch::NetworkError) do
        processor.on_message(message)
      end
    end
  end


  class FakeSearchable
    class << self
      def find_by_id(*args)
        self.new
      end
    end

    def reindex
      raise ElasticSearch::NetworkError.new("failed")
    end
  end

  class FakeSearchableProcessor < FullTextSearch::IndexingSearchablesProcessor
    QUEUE = 'mingle.indexing.fake_searchables'
    TARGET_TYPE = 'FullTextSearchMessagingTest::FakeSearchable'
  end

  private

  def index_project(project)
    FullTextSearch::IndexingProjectsProcessor.request_indexing([project])
    FullTextSearch::run_once
  end

  def put_message_on_bulk_card_queue(project)
    message = {:project_id => project.id, :ids => project.cards.map(&:id).join(",")}
    FullTextSearch::IndexingBulkCardsProcessor.new.send_message(FullTextSearch::IndexingBulkCardsProcessor::QUEUE, [Messaging::SendingMessage.new(message)])
  end

  def sort_by_id(messages)
    messages.sort_by { |m| m[:id] }
  end
end
