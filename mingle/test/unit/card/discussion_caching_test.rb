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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class DiscussionCachingTest < ActiveSupport::TestCase

  use_memcached_stub

  def setup
    Cache.flush_all
    @card = nil
  end

  def test_key_for_comments_changes_when_a_comment_is_added
    with_first_project do |project|
      @card = project.cards.first

      assert_comments_key_changed_after do
        User.with_first_admin do
          @card.add_comment(:content => "First comment")
        end
      end
    end
  end

  def test_key_for_card_murmurs_changes_when_new_murmur_is_linked_to_card
    with_first_project do |project|
      @card = project.cards.first

      assert_card_murmurs_key_changed_after do
        User.with_first_admin do
          CardMurmurLink.create!(:project => project, :card => @card, :murmur => create_murmur(:murmur => "murmurred comment"))
        end
      end
    end
  end

  def test_comments_should_be_cached
    with_first_project do |project|
      User.with_first_admin do
        @card = project.cards.first
        @card.add_comment(:content => "First comment")
      end

      assert_equal @card.comments, Cache.get(comments_key)
    end
  end

  def test_card_murmurs_should_be_cached
    with_first_project do |project|
      User.with_first_admin do
        @card = project.cards.first
        CardMurmurLink.create!(:project => project, :card => @card, :murmur => create_murmur(:murmur => "murmurred comment"))
      end

      assert_equal @card.reload.murmurs, Cache.get(card_murmurs_key)
    end
  end

  private

  def assert_comments_key_changed_after(&block)
    old_key = comments_key
    block.call if block_given?
    assert_not_equal old_key, comments_key
  end

  def assert_card_murmurs_key_changed_after(&block)
    old_key = card_murmurs_key
    block.call if block_given?
    assert_not_equal old_key, card_murmurs_key
  end

  def comments_key
    Keys::CardComments.new.path_for(@card.reload)
  end

  def card_murmurs_key
    Keys::CardMurmurs.new.path_for(@card.reload)
  end
end
