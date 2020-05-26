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

#Tags: feeds
class FeedsCachePopulatingProcessorTest < ActiveSupport::TestCase
  include MessagingTestHelper
  def setup
    login_as_member
  end

  def test_feed_cache_are_populated_when_there_are_card_changes
    with_first_project do |project|
      assert_feeds_cache_populated_on(project) { create_card!(:name => 'new card') }
    end
  end

  def test_feed_cache_are_populated_when_bulk_update_card
    with_first_project do |project|
      assert_feeds_cache_populated_on(project) do
        CardSelection.new(project, [project.cards.find_by_number('1')]).update_properties('status' => 'closed')
        HistoryGeneration.run_once()
      end
    end
  end

  def test_feed_cache_are_populated_when_there_are_page_changes
    with_first_project do |project|
      assert_feeds_cache_populated_on(project) { project.pages.create(:name => 'new page') }
    end
  end

  def test_feed_cache_are_populated_when_there_are_revs_commited
    with_first_project do |project|
      assert_feeds_cache_populated_on(project) do
        project.revisions.create!({:number => 1, :identifier => 'revision_id', :commit_message => 'fix a bug', :commit_time => Time.now.utc, :commit_user => 'xxx'})
      end
    end
  end

  def test_feed_cache_are_populated_when_there_are_correction_event_happened
    with_first_project do |project|
      assert_feeds_cache_populated_on(project) { project.card_types.first.update_attribute :name, 'story' }
    end
  end

  def test_feed_cache_are_populated_when_there_are_user_changed_his_name
    with_first_project do |project|
      assert_feeds_cache_populated_on(project) { User.find_by_login('bob').update_attribute(:name, 'iamnobody') }
    end
  end

  def test_feed_cache_should_be_updated_when_some_event_happenned_between_two_run
    with_first_project do |project|
      card = create_card!(:name => 'new card')
      FeedsCachePopulatingProcessor.run_once(:batch_size => 1000)
      old_feeds = feeds_cache(project).read
      card.update_attributes(:name => 'not very new now')
      FeedsCachePopulatingProcessor.run_once(:batch_size => 1000)
      assert_not_equal old_feeds, feeds_cache(project).read
    end
  end

  def test_feed_cache_are_populated_when_a_card_is_copied
    source_project = create_project(:name => "project 1")
    dest_project = create_project(:name => "project 2")

    source_project.activate
    source = source_project.cards.create! :name => 'card', :card_type_name => source_project.card_types.first.name
    FeedsCachePopulatingProcessor.run_once(:batch_size => 1000)
    old_feeds = feeds_cache(source_project).read
    get_all_messages_in_queue

    dest = source.copier(dest_project).copy_to_target_project
    FeedsCachePopulatingProcessor.run_once(:batch_size => 1000)
    updated_feeds = feeds_cache(source_project).read
    assert_not_equal old_feeds, updated_feeds
  end

  def test_feed_cache_are_populated_when_an_objective_is_created
    login_as_admin
    program = program('simple_program')
    objective = program.objectives.planned.create(:name => 'first objective', :start_at => '2011-1-1', :end_at => '2011-2-1')

    FeedsCachePopulatingProcessor.run_once(:batch_size => 1000)
    assert feeds_cache(program).cached?
  end

  def test_cache_are_populated_for_both_site_url_and_api_url
    MingleConfiguration.overridden_to(:site_u_r_l => 'https://site.com', :api_u_r_l => 'https://api.com') do
      with_first_project do |project|
        assert !feeds_cache(project, MingleConfiguration.site_url).cached?
        assert !feeds_cache(project, MingleConfiguration.api_url).cached?
        create_card!(:name => 'foo')
        FeedsCachePopulatingProcessor.run_once(:batch_size => 1000)

        assert feeds_cache(project, MingleConfiguration.site_url).cached?
        assert feeds_cache(project, MingleConfiguration.api_url).cached?

        cache = feeds_cache(project, MingleConfiguration.site_url).read
        assert_include MingleConfiguration.site_url, cache
        assert_not_include MingleConfiguration.api_url, cache

        cache = feeds_cache(project, MingleConfiguration.api_url).read
        assert_include MingleConfiguration.api_url, cache
        assert_not_include MingleConfiguration.site_url, cache
      end
    end

  end

  private
  def assert_feeds_cache_populated_on(deliverable, &block)
    assert !feeds_cache(deliverable).cached?
    yield
    deliverable.reload
    FeedsCachePopulatingProcessor.run_once(:batch_size => 1000)
    assert feeds_cache(deliverable).cached?
  end

  def feeds_cache(deliverable, site_url=MingleConfiguration.site_url)
    FeedsCache.new(Feeds.new(deliverable), site_url)
  end
end
