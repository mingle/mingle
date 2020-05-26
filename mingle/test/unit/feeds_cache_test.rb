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

# Tags: feeds
class FeedsCacheTest < ActiveSupport::TestCase
  def setup
    login_as_admin
  end

  def test_could_read_cache_of_most_recent_feeds_after_write_it
    with_first_project do |project|
      assert_nil feeds_cache(project).read

      feeds_cache(project).write
      assert_include 'xmlns="http://www.w3.org/2005/Atom"', feeds_cache(project).read
    end
  end

  def test_could_tell_whether_a_page_is_cached
    silence_warnings { Object.const_set('PAGINATION_PER_PAGE_SIZE', 2) }
    with_first_project do |project|
      assert !feeds_cache(project).cached?
      assert !feeds_cache(project, '1').cached?

      feeds_cache(project).write
      assert feeds_cache(project).cached?
      assert !feeds_cache(project, '1').cached?
    end
  ensure
    silence_warnings { Object.const_set('PAGINATION_PER_PAGE_SIZE', 25) }
  end

  def test_should_invald_all_the_cache_upon_project_structure_change
    with_new_project do |project|
      login_as_admin
      create_card!(:name => 'first card')
      feeds_cache(project).write
      project.card_types.first.update_attribute(:name, 'story')
      assert !feeds_cache(project).cached?
    end
  end

  def test_should_invalid_all_the_cache_upon_project_identifier_change
    with_new_project do |project|
      login_as_admin
      create_card!(:name => 'first card')
      feeds_cache(project).write
      project.update_attribute(:identifier, 'identifier'.uniquify[0..20])
      assert !feeds_cache(project).cached?
    end
  end

  def test_url_should_be_absolute_in_cached_content
    with_first_project do |project|
      feeds_cache(project, nil, "http://test.host:8080").write
      assert_include 'href="http://test.host:8080/api/v2/projects/first_project/feeds/events.xml"', feeds_cache(project, nil, "http://test.host:8080").read
    end
  end

  def test_site_url_with_slash_at_the_end
    with_first_project do |project|
      cache = feeds_cache(project, nil, "http://test.host:8080/")
      cache.write
      assert_include "http://test.host:8080/api/v2/projects/first_project/feeds/events.xml", cache.read
    end
  end

  def test_get_will_poplulate_cache_if_missing
    with_first_project do |project|
      assert !feeds_cache(project).cached?
      assert_include 'xmlns="http://www.w3.org/2005/Atom"', feeds_cache(project).get
      assert feeds_cache(project).cached?
    end
  end

  def test_should_invalid_cache_when_site_url_changed
    with_first_project do |project|
      feeds_cache(project, nil, "http://test.host:8080").write
      assert feeds_cache(project, nil, "http://test.host:8080").cached?
      assert !feeds_cache(project, nil, "http://test.host:4001").cached?
    end
  end

  def test_should_clear_feed_cache_on_correction_event_happens
    with_first_project do |project|
      feeds_cache(project).write
      assert feeds_cache(project).cached?
      CorrectionEvent.create_for_repository_settings_change(project)
      assert !feeds_cache(project).cached?
    end
  end

  def test_should_clear_feed_cache_on_user_rename
    bob = User.find_by_login('bob')

    with_first_project {|project| feeds_cache(project).write }
    with_project_without_cards {|project| feeds_cache(project).write }

    bob.update_attribute(:name ,'newbob')

    with_first_project {|project| assert !feeds_cache(project).cached? }
    with_project_without_cards {|project| assert !feeds_cache(project).cached? }
  end

  # bug 12452, when there are 25+ events happened at same time,
  # last page changed, so need to clear old last page to let
  # it to be recached later when someone fetchs it
  def test_should_only_cache_head_page_but_not_last_page
    login_as_admin
    silence_warnings { Object.const_set('PAGINATION_PER_PAGE_SIZE', 2) }
    with_new_project do |project|
      create_card!(:name => 'first card')
      project.events.map(&:generate_changes)
      assert_equal 1, project.events.to_a.size

      incomplete_page_1_content = feeds_cache(project, 1).get
      assert_equal feeds_cache(project).read, incomplete_page_1_content
      assert_match /first card/, incomplete_page_1_content

      2.times {|i| create_card!(:name => "new card #{i + 1}")}
      project.events.map(&:generate_changes)
      assert_equal 3, project.events.to_a.size, "events should be 3"

      #update head page, this is what background job doing
      feeds_cache(project).write

      incomplete_page_2_content = feeds_cache(project, 2).get
      assert_equal feeds_cache(project).read, incomplete_page_2_content
      assert_match /new card 2/, incomplete_page_2_content

      #no page one cache yet
      assert_nil feeds_cache(project, 1).read
      #call get to create cache
      page_1_content = feeds_cache(project, 1).get
      assert_match /first card/, page_1_content
      assert_match /new card 1/, page_1_content
    end
  ensure
    silence_warnings { Object.const_set('PAGINATION_PER_PAGE_SIZE', 25) }
  end

  def test_digest_should_not_modify_if_cache_is_same
    with_first_project do |project|
      cache = feeds_cache(project)
      old_digest = cache.content_digest
      cache.write
      assert_equal old_digest, cache.content_digest
      assert_equal old_digest, feeds_cache(project).content_digest
    end
  end

  def test_digest_should_modify_if_cache_changed
    with_first_project do |project|
      cache = feeds_cache(project)
      old_digest = cache.content_digest
      create_card!(:name => 'foo')
      cache = feeds_cache(project)
      cache.write
      assert_not_equal old_digest, cache.content_digest
    end
  end

  def test_digest_should_modify_if_project_structure_changed
    with_first_project do |project|
      cache = feeds_cache(project)
      old_digest = cache.content_digest
      project.card_types.first.update_attributes(:name => 'foobared')
      cache = feeds_cache(project)
      cache.write
      assert_not_equal old_digest, cache.content_digest
    end
  end

  def test_cache_for_two_clean_project_should_not_interfer_each_other
    p1 = create_project
    p2 = create_project
    feeds_cache(p1).write
    assert !feeds_cache(p2).cached?
  end

  def feeds_cache(project, page=nil, test_site_url='http://test.host:8080')
    FeedsCache.new(Feeds.new(project, page), test_site_url)
  end
end
