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

require File.expand_path("../../unit_test_helper", File.dirname(__FILE__))

class DiscussionFragmentCacheTest < ActionController::TestCase
  include CachingTestHelper

  use_memcached_stub

  def setup
    Cache.flush_all
  end

  def test_cache_path_should_change_after_add_comment
    with_first_project do |project|
      card = project.cards.first

      User.with_first_admin do
        assert_cache_path_changed_after(card.discussion) do
          card.add_comment(:content => "First comment")
        end
      end

    end
  end

  def test_cache_paths_should_change_after_adding_card_murmur
    with_first_project do |project|
      card = project.cards.first

      User.with_first_admin do
        old_murmurs_control_cache_path = murmurs_show_cache_path(card.discussion)

        assert_cache_path_changed_after(card.discussion) do
          CardMurmurLink.create!(:project => project, :card => card, :murmur => create_murmur(:murmur => "murmurred comment"))
          card.reload
        end

        assert_not_equal old_murmurs_control_cache_path, murmurs_show_cache_path(card.discussion)
      end

    end
  end

  def test_cache_path_should_change_per_user
    with_first_project do |project|
      card = project.cards.first

      login_as_bob
      assert_cache_path_changed_after(card.discussion) do
        login_as_admin
      end
    end

  end

  private

  def cache_path(discussion)
    Keys::Discussion.new.path_for(discussion)
  end

  def murmurs_show_cache_path(discussion)
    Keys::CardMurmursShowControl.new.path_for(discussion, true)
  end

end
