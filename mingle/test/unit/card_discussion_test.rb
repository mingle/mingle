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

class CardDiscussionTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree, ActionView::Helpers::DateHelper

  def setup
    @project = first_project
    @project.activate
    login_as_member
  end

  def teardown
    cleanup_repository_drivers_on_failure
    Clock.reset_fake
  end

  def test_adding_a_comment_creates_a_version
    card = @project.cards.find_by_number(1)
    initial_version_size = card.versions.size

    card.add_comment :content => "I would like to close this as a duplicate"
    assert card.comment.blank?
    assert_equal initial_version_size + 1, card.reload.versions.size
    assert_equal "I would like to close this as a duplicate", card.versions[-1].comment
    card.name = 'another new name'
    card.save!
    assert_equal initial_version_size + 2, card.reload.versions.size
    assert_nil card.versions.last.comment
    assert_equal "I would like to close this as a duplicate", card.versions[-2].comment
  end

  def test_adding_a_comment_creates_murmur
    card = @project.cards.find_by_number(1)
    initial_version_size = card.versions.size
    card.add_comment :content => "I would like to close this as a duplicate"
    assert_equal @project.murmurs.reload.last, card.discussion.last
  end

  def test_should_load_old_style_comments_from_card_versions_if_it_is_not_murmured
    card = @project.cards.find_by_number(1)
    card.add_comment :content => 'new style comment should be murmured'
    card.save!

    card.update_attributes(:description => "foo")
    card.versions.reload.last.update_attributes(:comment => 'old style comment 1')

    card.update_attributes(:description => "bar")
    card.versions.reload.last.update_attributes(:comment => 'old style comment 2')


    assert_equal ['old style comment 2', 'old style comment 1', 'new style comment should be murmured'], card.discussion.map(&:murmur)
  end


  def test_discussion_about_card_can_be_collected_through_versions_in_the_right_order
    card = @project.cards.find_by_number(1)
    Clock.fake_now :year => 2009, :month => 12, :day => 31, :hour => 23, :min => 59, :sec => 59
    card.add_comment :content => "I would like to close this as a duplicate"
    Clock.fake_now :year => 2010, :month => 1, :day => 1, :hour => 0, :min => 1, :sec => 0
    card.add_comment :content => "Another comment"
    assert_equal ["Another comment", "I would like to close this as a duplicate"], card.reload.discussion.collect(&:murmur)
  end

  def test_card_comment_murmur_should_describe_its_origin_on_linked_card
    card = @project.cards.find_by_number(1)
    card2 = @project.cards.find_by_number(4)
    comment = "Comment about ##{card2.number}"
    card.add_comment :content => comment
    murmur = @project.murmurs.find_by_origin_type_and_origin_id(card.class.name, card.id)
    CardMurmurLink.create!(:project_id => @project.id, :card_id => card2.id, :murmur_id => murmur.id)
    assert_equal 'Card #1', card2.reload.discussion.find { |struct| struct.murmur == comment }.describe_origin
  end

  def test_card_discussion_includes_murmurs_linked_to_said_card
    card = @project.cards.find_by_number(1)
    Clock.now_is("2009-05-14") do
      murmur = Murmur.create!(:project_id => @project.id, :packet_id => '12345abc'.uniquify, :author => User.current, :murmur => "This is a murmur")
      CardMurmurLink.create!(:project_id => @project.id, :card_id => card.id, :murmur_id => murmur.id)
    end
    Clock.now_is("2009-05-15") do
      murmur = Murmur.create!(:project_id => @project.id, :packet_id => '12345abc'.uniquify, :author => User.current, :murmur => "This is another murmur")
      CardMurmurLink.create!(:project_id => @project.id, :card_id => card.id, :murmur_id => murmur.id)
    end
    assert_equal ["This is another murmur", "This is a murmur"], card.reload.discussion.collect(&:murmur)
  end

  def test_card_discussion_includes_murmurs_linked_to_said_card_in_reverse_time_order
    # jruby can't handle usec Time precision, so we fake the time to make it progress in seconds
    Clock.fake_now(:year => 2005, :month => 10, :day => 9, :hour => 8, :min => 7, :sec => 6)
    card = @project.cards.find_by_number(1)
    card.add_comment :content => "This is a comment"

    Clock.fake_now(:year => 2005, :month => 10, :day => 9, :hour => 8, :min => 7, :sec => 7)
    murmur = Murmur.create!(:project_id => @project.id, :packet_id => '12345abc'.uniquify, :author => User.current, :murmur => "This is a murmur that came after the comment")
    CardMurmurLink.create!(:project_id => @project.id, :card_id => card.id, :murmur_id => murmur.id)

    Clock.fake_now(:year => 2005, :month => 10, :day => 9, :hour => 8, :min => 7, :sec => 8)
    card.add_comment :content => "This is a comment that was created after the murmur"

    assert_equal ["This is a comment that was created after the murmur", "This is a murmur that came after the comment", "This is a comment"], card.reload.discussion.collect(&:murmur)
  end

  def test_comments_reflect_person_creating_the_comment_not_the_original_card_creator
    bob = User.find_by_login 'bob'
    longbob = User.find_by_login 'longbob'

    set_current_user(bob) do
      Clock.fake_now :year => 2009, :month => 12, :day => 31, :hour => 23, :min => 59, :sec => 59
      @project.cards.find_by_name('first card').add_comment :content => "I would like to close this as a duplicate"
    end
    set_current_user(longbob) do
      Clock.fake_now :year => 2010, :month => 1, :day => 1, :hour => 0, :min => 0, :sec => 0
      @project.cards.find_by_name('first card').add_comment :content => "I would like to open this again - bob agrees that it is not a duplicate"
    end
    card = @project.cards.find_by_name('first card')
    assert_equal 2, card.discussion.size
    assert_equal 'longbob@email.com', card.discussion[0].author.email #most recent comment
    assert_equal 'bob@email.com', card.discussion[1].author.email #original comment
  end

  def test_discussion_count_should_be_sum_of_murmurs_and_comments_count
    card = create_card!(:name => 'let talk')
    assert_equal 0, card.discussion.count

    card.add_comment :content => 'foo!'
    murmur = @project.murmurs.create(:murmur => 'bar about ##{card.number}', :author => User.current)
    CardMurmurLink.create!(:project_id => @project.id, :card_id => card.id, :murmur_id => murmur.id)
    card.reload
    assert_equal 2, card.discussion.count
  end
end
