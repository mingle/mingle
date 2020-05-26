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

# Tags: messaging, history
class HistoryGenerationProcessorTest < ActiveSupport::TestCase
  include MessagingTestHelper
  include HistoryGeneration

  def setup
    @project = project_without_cards
    @project.activate
    login_as_member
  end

  def test_should_aggregate_different_kinds_of_event_messages_into_history_queue
    route(:from => CardChangesGenerationProcessor::QUEUE, :to => TEST_QUEUE)
    route(:from => PageChangesGenerationProcessor::QUEUE, :to => TEST_QUEUE)
    route(:from => RevisionChangesGenerationProcessor::QUEUE, :to => TEST_QUEUE)
    card, page, rev = sample_card_page_rev
    assert_all_event_included card.versions + page.versions + [rev.reload], all_messages_from_queue
  end

  def test_should_not_change_revision_events_mingle_timestamp_when_user_change_version_controll_user_name
    member = login_as_member
    event = Revision.create_from_repository_revision(OpenStruct.new(:number => 34, :time => Time.now, :version_control_user => 'member'), @project).reload.event
    set_event_timestamp(event, 3.days.ago)
    mingle_timestamp = event.reload.mingle_timestamp
    assert_nil event.created_by_user_id
    member.update_attribute(:version_control_user_name, 'member')
    UserVersionControlNameChangeProcessor.run_once

    assert_equal member.id, event.reload.created_by_user_id
    assert_equal mingle_timestamp, event.reload.mingle_timestamp
  end

  def test_should_be_able_to_process_message_in_batch_style
    card = create_card!(:name => 'card 1')
    card.update_attribute(:name, 'c 1')
    HistoryGeneration.run_once
    assert_changes_not_empty_for_all card.versions
  end

  def test_processors_should_only_process_the_size_of_messages_by_option_batch_size_even_history_generation_has_multi_processors
    bob = login_as_bob
    card = create_card!(:name => 'card 1')
    page = @project.pages.create!(:name => 'hello', :content => 'doh')
    HistoryGeneration.run_once(:batch_size => 1)
    assert_changes_not_empty_for_all card.versions
    assert_equal [], page.versions.first.event.changes
  end

  def test_should_generate_history_events_after_get_page_create_message
    page = @project.pages.create!(:name => 'hello', :content => 'doh')
    page.update_attribute(:name, 'hello1')
    HistoryGeneration.run_once
    assert_changes_not_empty_for_all page.versions
  end

  def test_should_generate_history_events_after_get_revision_create_message
    rev = @project.revisions.create!(:number => '2222', :commit_message => 'check in 2222', :commit_time => Time.now, :commit_user => 'jb')
    HistoryGeneration.run_once
    assert_changes_not_empty_for_all [rev.reload]
  end

  def test_should_regenerate_all_revision_event_when_user_change_his_version_control_name
    @project.revisions.delete_all
    @project.revisions.create!(:number => '2222', :commit_message => 'check in 2222', :commit_time => Time.now, :commit_user => 'member')
    member = User.find_by_login('member')
    member.update_attribute :version_control_user_name, 'member'
    HistoryGeneration.run_once
    assert_equal member.id,
      RevisionEvent.find(:all, :conditions => {:deliverable_id => @project.id, :deliverable_type => Deliverable::DELIVERABLE_TYPE_PROJECT}).first.created_by_user_id
    member.update_attribute :version_control_user_name, 'jb'
    HistoryGeneration.run_once
    assert_equal nil,
      RevisionEvent.find(:all, :conditions => {:deliverable_id => @project.id, :deliverable_type => Deliverable::DELIVERABLE_TYPE_PROJECT}).first.created_by_user_id
  end

  def test_batch_generate_message_for_card_sql_condition
    route(:from => CardChangesGenerationProcessor::QUEUE, :to => TEST_QUEUE)
    card1 = create_card!(:name => 'card1')
    card1.update_attribute(:name, 'card11')
    card2 = create_card!(:name => 'card2')
    card2.update_attribute(:name, 'card22')
    get_all_messages_in_queue

    Card::Version.update_all(:updater_id => 'osito')
    HistoryGeneration.generate_changes_for_card_selection(@project, 'osito')
    HistoryGeneration.run_once
    messages = all_messages_from_queue

    assert_all_event_included [card1.versions.last, card2.versions.last], messages
    assert_all_event_not_included [card1.versions.first, card2.versions.first], messages
  end

  def test_regenerating_history_for_project_should_put_all_event_into_the_processor_queue
    card, page, rev = sample_card_page_rev
    HistoryGeneration.run_once
    route(:from => CardChangesGenerationProcessor::QUEUE, :to => TEST_QUEUE)
    route(:from => PageChangesGenerationProcessor::QUEUE, :to => TEST_QUEUE)
    route(:from => RevisionChangesGenerationProcessor::QUEUE, :to => TEST_QUEUE)

    HistoryGeneration::generate_changes(@project)
    HistoryGeneration.run_once
    messages = all_messages_from_queue
    assert_all_event_included card.versions + page.versions + [rev.reload], messages
  end

  def test_should_only_send_out_one_message_when_request_generating_for_project
    route(:from => ProjectChangesGenerationProcessor::QUEUE, :to => TEST_QUEUE)
    HistoryGeneration::generate_changes(@project)
    assert_equal 1, all_messages_from_queue.size
  end

  def test_should_do_nothing_on_receive_not_existing_project_message
    with_new_project do |project|
      project.pages.create!(:name => 'hello', :content => 'doh')
      project.destroy

      HistoryGeneration.run_once
    end
  end

  def test_should_do_nothing_on_receive_a_non_existing_searchable_id
    page = @project.pages.create!(:name => 'hello', :content => 'doh')
    User.with_first_admin { page.destroy }

    HistoryGeneration.run_once
  end

  def test_should_migrate_mingle_2_1_history_generation_change
    with_first_project do |project|
      card_version = project.cards.first.versions.first
      card_version.event.changes.destroy_all

      message = {}
      message[:id] = card_version.event.id
      message[:type] = card_version.event.class.name
      message[:project_id] = project.id
      send_message(HistoryGeneration::Mingle21ChangeProcessor::QUEUE, [Messaging::SendingMessage.new(message)])
      HistoryGeneration.run_once(:batch_size => 10)
      assert_changes_not_empty_for_all [card_version.reload]
    end
  end

  def test_message_is_republished_if_lock_wait_timeout_exception_occurs
    with_first_project do |project|
      queue = CardChangesGenerationProcessor::QUEUE

      CardVersionEvent.class_eval do
        def generate_changes_with_exception(options = {})
          raise "this is a Lock wait timeout exceeded exception, yo"
        end
        alias :generate_changes_without_exception :generate_changes
        alias :generate_changes :generate_changes_with_exception
      end

      begin
        get_all_messages_in_queue(queue)   # flush queue

        card = project.cards.first
        card.description = "new description"
        card.save!
        expected_messages = [{:id => get_all_messages_in_queue(queue).first[:id] + 1, :project_id => project.id}]

        card.description = "new description 2"
        card.save!

        HistoryGeneration.run_once(:batch_size => expected_messages.size)
        after_processing_messages = get_all_messages_in_queue(queue)
        assert_equal expected_messages, after_processing_messages.collect(&:body_hash)
      ensure
        CardVersionEvent.class_eval do
          alias :generate_changes :generate_changes_without_exception
        end
      end
    end
  end

  private

  def assert_changes_not_empty_for_all(event_sources)
    event_sources.collect(&:event).each do |event|
      assert !event.changes.empty?
    end
  end

  def assert_all_event_included(event_sources, messages)
    event_sources.each do |es|
      assert_include es.event.message.body_hash, messages.collect(&:body_hash)
    end
  end

  def assert_all_event_not_included(event_sources, messages)
    event_sources.each do |es|
      assert_not_include es.event.message, messages
    end
  end

  def sample_card_page_rev
    card = create_card!(:name => 'card 1')
    page = @project.pages.create!(:name => 'hello', :content => 'doh')
    rev = @project.revisions.create!(:number => '2222', :commit_message => 'check in 2222', :commit_time => Time.now, :commit_user => 'jb')

    [card, page, rev]
  end

end
