# -*- coding: utf-8 -*-

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

class RevisionTest < ActiveSupport::TestCase
  def setup
    @create_repo_start_time = Time.now
    @driver = with_cached_repository_driver(name + '_setup') do |driver|
      driver.create
      driver.import("#{Rails.root}/test/data/test_repository")
      driver.checkout
    end
    @create_repo_end_time = Time.now
    @project = first_project
    @project.activate
    login_as_admin
    configure_subversion_for(@project, {:repository_path => @driver.repos_dir})
  end

  def teardown
    cleanup_repository_drivers_on_failure
    Revision.destroy_all
  end

  def test_create_from_repository_revision_when_no_identifier_present
    revision = Revision.create_from_repository_revision(
      OpenStruct.new(:number => 34, :time => Time.now), @project)
    assert_equal 34, revision.number
    assert_equal '34', revision.identifier
  end

  def test_create_from_repository_revision_when_identifier_present
    revision = Revision.create_from_repository_revision(
      OpenStruct.new(:number => 34, :identifier => 'abcdef', :time => Time.now), @project)
    assert_equal 34, revision.number
    assert_equal 'abcdef', revision.identifier
  end

  def test_create_from_repository_revision_when_no_number_present
    revision = Revision.create_from_repository_revision(
      OpenStruct.new(:identifier => 'abcdef', :time => Time.now), @project)
    assert_equal 1, revision.number
    assert_equal 'abcdef', revision.identifier

    revision = Revision.create_from_repository_revision(
      OpenStruct.new(:identifier => 'xyz', :time => Time.now), @project)
    assert_equal 2, revision.number
    assert_equal 'xyz', revision.identifier
  end

  def test_mingle_user
    does_not_work_without_subversion_bindings do
      user = User.find_by_login("first")
      user.update_attributes(:version_control_user_name => @driver.user)

      @project.cache_revisions
      assert_equal user, Revision.find_by_commit_user(@driver.user).mingle_user
    end
  end

  def test_can_create_has_and_belongs_to_many_with_multiple_card_tables
    first_card = first_project.with_active_project do |project|
      revision = project.revisions.create!(:number => '1111', :identifier => 'sfdasdf',
        :commit_message => 'check in 1111', :commit_time => Time.now, :commit_user => 'jb')
      card = project.cards.first
      CardRevisionLink.create!(:project_id => project.id, :card_id => card.id, :revision_id => revision.id)
      card
    end

    second_card = with_first_project do |project|
      second_card =create_card!(:number => '90', :name => 'card number 2 on project_without_cards')
      revision = project.revisions.create!(:number => '2222', :identifier => 'asfasff',
        :commit_message => 'check in 2222', :commit_time => Time.now, :commit_user => 'jb')
      CardRevisionLink.create!(:project_id => project.id, :card_id => second_card.id, :revision_id => revision.id)
      second_card
    end

    with_first_project do |project|
      assert_equal 1, Revision.find_by_number(1111).cards.length
      assert_equal first_card, Revision.find_by_number(1111).cards.first
    end

    with_first_project do |project|
      assert_equal 1, Revision.find_by_number(2222).cards.length
      assert_equal second_card, Revision.find_by_number(2222).cards.first
    end
  end

  def test_delete_for_project_removes_all_dependent_rows
    does_not_work_without_subversion_bindings do
      @driver.unless_initialized do
        @driver.add_file('new_file.txt', 'some content')
        @driver.commit 'added new_file.txt for #1 and #4'
      end
      @project.cache_revisions
      @project.reload

      decoy_project = project_without_cards
      decoy_project.with_active_project do
        decoy_project.cards.create!(:card_type_name => 'Card', :number => 1, :name => 'a card')
        decoy_project.cards.create!(:card_type_name => 'Card', :number => 4, :name => 'another card')
        configure_subversion_for(decoy_project, {:repository_path => @driver.repos_dir})
        decoy_project.cache_revisions
        decoy_project.reload
      end

      assert_revision_count(@project, 2, 2)
      Revision.delete_for(@project)
      assert_revisions_deleted(@project)

      decoy_project.with_active_project do
        assert_revision_count(decoy_project, 2, 2)
      end
    end
  end

  def assert_revision_count(project, expected_revision_count, expected_card_link_count)
    assert_equal expected_revision_count, project.revisions.size
    assert_equal expected_card_link_count, CardRevisionLink.find_all_by_project_id(project.id).size
  end

  def assert_revisions_deleted(project)
    assert_equal 0, project.revisions.size
    assert_equal 0, CardRevisionLink.find_all_by_project_id(project.id).size
    assert_equal 0, Event.find_all_by_deliverable_id_and_type(project.id, 'RevisionEvent').size
    assert_equal 0, Change.count_by_sql("SELECT count(*) from #{Change.table_name} WHERE event_id NOT IN (SELECT id FROM #{Event.table_name})")
  end

  def test_commit_message_not_longer_than_255_truncates_safely
    long_commit_message = '中文'*1000
    rev = Revision.create!(:commit_time => Time.new, :commit_user => 'dave',
                           :project => @project, :number => 37, :identifier => '2342lkjsdfl',
                           :commit_message => long_commit_message)
    truncated = rev.commit_message_not_longer_than_255
    assert truncated.length <= 255
    assert truncated.length > 253
  end

  def test_commit_message_not_long_than_255_is_OK_with_short_messages
    message = 'blah blah "中文中文中文'
    assert_equal message, create_revision(message).commit_message_not_longer_than_255
  end

  def test_commit_message_not_long_than_255_is_OK_with_messages_exactly_255_chars
    message = 'a' * 255
    assert_equal 255, message.length
    assert_equal message, create_revision(message).commit_message_not_longer_than_255
  end

  def test_previous_and_next_revision_identifier
    @project.revisions.create!(:number => 1, :identifier => 'abc',
      :commit_message => 'commit 1', :commit_time => Time.now, :commit_user => 'user')
    @project.revisions.create!(:number => 2, :identifier => 'xyz',
      :commit_message => 'commit 2', :commit_time => Time.now + 4.seconds, :commit_user => 'user')
    @project.revisions.create!(:number => 3, :identifier => '1234',
      :commit_message => 'commit 3', :commit_time => Time.now + 8.seconds, :commit_user => 'user')
    assert_nil @project.revisions.first.previous_revision_identifier
    assert_equal 'abc', @project.revisions[1].previous_revision_identifier
    assert_equal '1234', @project.revisions[1].next_revision_identifier
    assert_nil @project.revisions.last.next_revision_identifier
  end

  def test_previous_revision_identifier_handles_missing_revisions
    @project.revisions.create!(:number => 1, :identifier => 'rtewt',
      :commit_message => 'commit 1', :commit_time => Time.now, :commit_user => 'user')
    @project.revisions.create!(:number => 2, :identifier => 'asfsaf',
      :commit_message => 'commit 1', :commit_time => Time.now, :commit_user => 'user')
    revision_5 = @project.revisions.create!(:number => 5, :identifier => 'sfsdff',
      :commit_message => 'commit 1', :commit_time => Time.now, :commit_user => 'user')
    assert_equal 'asfsaf', revision_5.previous_revision_identifier
  end

  def test_previous_revision_identifier_handles_missing_revisions_when_on_first_revision
    revision_2 = @project.revisions.create!(:number => 2, :identifier => 'sfsfswer',
      :commit_message => 'commit 1', :commit_time => Time.now, :commit_user => 'user')
    @project.revisions.create!(:number => 5, :identifier => 'slfkjoiu',
      :commit_message => 'commit 1', :commit_time => Time.now, :commit_user => 'user')
    assert_nil revision_2.previous_revision_identifier
  end

  def test_first_and_last_handle_missing_revisions
    revision_2 = @project.revisions.create!(:number => 2, :identifier => 'sadfsadf',
      :commit_message => 'commit 1', :commit_time => Time.now, :commit_user => 'user')
    revision_5 = @project.revisions.create!(:number => 5, :identifier => 'asfsadfff',
      :commit_message => 'commit 1', :commit_time => Time.now, :commit_user => 'user')
    revision_8 = @project.revisions.create!(:number => 8, :identifier => 'sdfsdlfkj',
      :commit_message => 'commit 1', :commit_time => Time.now, :commit_user => 'user')
    assert revision_2.first?
    assert !revision_2.last?
    assert !revision_5.first?
    assert !revision_5.last?
    assert !revision_8.first?
    assert revision_8.last?
  end

  def test_next_revision_identifier_handles_missing_revisions
    @project.revisions.create!(:number => 1, :identifier => 'klsjfdlkasj',
      :commit_message => 'commit 1', :commit_time => Time.now, :commit_user => 'user')
    revision_2 = @project.revisions.create!(:number => 2, :identifier => 'sklfdjlkjs',
      :commit_message => 'commit 1',:commit_time => Time.now, :commit_user => 'user')
    @project.revisions.create!(:number => 5, :identifier => 'isfjkljlkj',
      :commit_message => 'commit 1', :commit_time => Time.now, :commit_user => 'user')
    assert_equal 'isfjkljlkj', revision_2.next_revision_identifier
  end

  # bug 4219
  def test_commit_message_is_truncated_before_being_written_to_the_db
    too_long_message = "a"*66000  # greater than 65535 characters
    revision = Revision.new(revision_parameters.merge(:commit_message => too_long_message))
    revision.save
    assert_equal 65535, revision.commit_message.length
  end

  def test_should_create_revision_event_after_revision_create
    rev = @project.revisions.create!(:number => 1, :identifier => 'oiusdlfjl',
      :commit_message => 'commit 1', :commit_time => Time.now, :commit_user => 'user')
    assert_not_nil rev.reload.event
    assert_kind_of RevisionEvent, rev.event
  end

  def test_event_created_at_is_specified_commit_time_and_mingle_timestamp_is_now
    five_years_ago = 5.years.ago.utc

    rev = @project.revisions.create!(:number => 1, :identifier => 'oiusdlfjl',
      :commit_message => 'commit 1', :commit_time => five_years_ago, :commit_user => 'user')
    assert_equal five_years_ago.to_s, rev.reload.event.created_at.to_s
    assert (current_db_time_utc  - Time.parse(rev.reload.event.mingle_timestamp + " UTC")).abs < 50
  end

  def test_should_destroy_revision_event_after_revision_destroy
    rev = @project.revisions.create!(:number => 1, :identifier => 'lkjsf1sdf',
      :commit_message => 'commit 1', :commit_time => Time.now, :commit_user => 'user')
    event = rev.reload.event
    rev.destroy
    assert_record_deleted(event)
  end

  def test_should_ignore_created_revision_when_create_from_repository_revision
    revision = OpenStruct.new(:number => 1, :message => 'xxx', :time => Time.now.utc)
    Revision.create_from_repository_revision(revision, @project)
    Revision.create_from_repository_revision(revision, @project)
    @project.reload
    assert_equal 1, @project.revisions.find_all_by_number(1).size
  end

  def test_find_or_create_finds_existing_revision
    attributes = {:number => 1, :identifier => 'lkjsf1sdf', :commit_message => 'commit 1', :commit_time => Time.now, :commit_user => 'user', :project_id => @project.id}
    rev = @project.revisions.create!(attributes)
    assert_no_difference "Revision.count" do
      found = Revision.find_or_create(attributes)
      assert_equal rev, found
    end
  end

  def test_find_or_create_creates_if_it_does_not_exist
    assert_difference "Revision.count", +1 do
      found = Revision.find_or_create(:number => 1, :identifier => 'osito', :commit_message => 'commit 1', :commit_time => Time.now, :commit_user => 'user', :project_id => @project.id)
    end

  end

  def test_should_not_allow_two_revisions_in_same_project_to_have_same_number
    Revision.create!(:number => 1, :identifier => 'sdfsdfsdf',
      :commit_message => '', :commit_time => Time.now.utc, :commit_user => '', :project_id => @project.id)
    revision = Revision.create(:number => 1, :identifier => '987lskjklj',
      :commit_message => '', :commit_time => Time.now.utc, :commit_user => '', :project_id => @project.id)

    assert_equal ['Number has already been taken'], revision.errors.full_messages
  end

  def test_should_not_allow_two_revisions_in_same_project_to_have_same_identifier
    Revision.create!(:number => 1, :identifier => 'abc',
      :commit_message => '', :commit_time => Time.now.utc, :commit_user => '', :project_id => @project.id)
    revision = Revision.create(:number => 17, :identifier => 'abc',
      :commit_message => '', :commit_time => Time.now.utc, :commit_user => '', :project_id => @project.id)

    assert_equal ['Identifier has already been taken'], revision.errors.full_messages
  end

  def test_should_be_able_to_create_same_revision_in_2_different_project
    rev = {:number => 1, :identifier => 'lsdfkjklj', :commit_message => '', :commit_time => Time.now.utc, :commit_user => ''}
    Revision.create!(rev.merge(:project_id => @project.id))
    Revision.create!(rev.merge(:project_id => project_without_cards.id))
  end

  #bug 4879
  def test_should_be_empty_when_load_revision_events_if_project_has_no_repository_configuration
    revision = @project.revisions.create!(:number => 1, :identifier => 'sldfkjlj',
      :commit_message => 'commit 1', :commit_time => Time.now, :commit_user => 'user')
    @project.delete_repository_configuration
    assert_equal [], Revision.load_history_event(@project, [revision.id]).collect(&:number)
  end

  def test_short_identifier_returns_full_identifier_if_no_short_length_specified
    revision = @project.revisions.create!(:number => 1, :identifier => 'alsdfjksalkfjsalfjklsadfjlkj',
      :commit_message => 'commit 1', :commit_time => Time.now, :commit_user => 'user')
    project = revision.project
    def project.repository_vocabulary
      {'short_identifier_length' => nil, 'revision' => 'revision'}
    end
    assert_equal "alsdfjksalkfjsalfjklsadfjlkj", revision.short_identifier
  end

  def test_short_name_uses_short_identifier
    revision = @project.revisions.create!(:number => 1, :identifier => 'alsdfjksalkfjsalfjklsadfjlkj',
      :commit_message => 'commit 1', :commit_time => Time.now, :commit_user => 'user')
    project = revision.project
    def project.repository_vocabulary
      {'short_identifier_length' => 7, 'revision' => 'revision'}
    end
    assert_equal "Revision alsd...", revision.short_name
  end

  def test_name_uses_long_identifier
    revision = @project.revisions.create!(:number => 1, :identifier => 'alsdfjksalkfjsalfjklsadfjlkj',
      :commit_message => 'commit 1', :commit_time => Time.now, :commit_user => 'user')
    project = revision.project
    def project.repository_vocabulary
      {'short_identifier_length' => 7, 'revision' => 'revision'}
    end
    assert_equal revision.name, "Revision alsdfjksalkfjsalfjklsadfjlkj"
  end

  def test_send_history_notification_should_work_when_a_user_has_more_than_1000_commits
    assert_nothing_raised { Revision.load_history_event(@project, (1..1001).to_a) }
  end

  private

  def revision_parameters
    {:commit_time => Time.new, :commit_user => 'dave', :project => @project, :number => 37, :commit_message => 'some message'}
  end

  def create_revision(commit_message)
    Revision.create!(revision_parameters.merge(:commit_message => commit_message))
  end

end
