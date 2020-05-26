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

class CardCommentsTest < ActiveSupport::TestCase
  def setup
    @project = first_project
    @project.activate
    @first_card = @project.cards.first
    login_as_member
  end

  def teardown
    Clock.reset_fake
  end

  def test_comment_as_mumur_like_includes_a_reply_template_with_context
    card = @project.cards.create! :name => "new card", :card_type_name => "Card"
    card.add_comment :content => "Hey @bob, how about you check out cards #1 and #2. Thanks @bob!"
    murmur = card.discussion.first
    assert_not_nil murmur

    assert_not_equal [], murmur.reply_template
    assert_equal ["@bob", '#' + card.number.to_s, '#1', '#2'], murmur.reply_template
  end

  def test_load_old_style_comment_as_murmur_like_obj
    card = @project.cards.create! :name => "new card", :card_type_name => "Card"
    card.versions.reload.last.update_attributes(:comment => 'first comment')

    murmur = card.discussion.first

    assert_not_nil murmur
    assert_equal "version-" + card.version.to_s, murmur.id
    assert_equal "first comment", murmur.murmur
    assert_equal card.type_and_number, murmur.describe_origin
    assert_equal "member", murmur.author.login
  end

  def test_be_able_to_get_comments_content
    @first_card.add_comment :content => "first comment"
    @first_card.add_comment :content => "second comment"

    assert_sort_equal ['first comment', 'second comment'], @first_card.comments.collect(&:content)
  end

  def test_author_of_comment
    User.find_by_login('bob').with_current do
      @first_card.add_comment :content => "first comment"
    end

    User.find_by_login('member').with_current do
      @first_card.add_comment :content => "second comment"
    end

    assert_sort_equal ['bob', 'member'], @first_card.comments.collect(&:created_by).collect(&:login)
  end

  def test_get_create_at_in_lates_first_order
    Clock.fake_now(:year => 2007, :month => 1, :day => 1)
    @first_card.add_comment :content => "first comment"

    Clock.fake_now(:year => 2007, :month => 1, :day => 2)
    @first_card.add_comment :content => "second comment"
    assert_equal [Date.parse("2007-1-2"), Date.parse("2007-1-1")], @first_card.comments.collect(&:created_at).collect(&:to_date)
  end

  def test_to_xml
    Clock.fake_now(:year => 2007, :month => 1, :day => 1)
    @first_card.add_comment :content => "first comment"

    xml = @first_card.comments.first.to_xml
    assert_equal 'first comment', get_element_text_by_xpath(xml, '/comment/content')
    assert_equal 'datetime', get_attribute_by_xpath(xml, '/comment/created_at/@type')
    assert_equal User.current.login, get_element_text_by_xpath(xml, '/comment/created_by/login')
  end

  def test_card_comment_should_be_blank_if_content_is_blank
    assert Card::Comment.new(@first_card, :content => nil).blank?
    assert Card::Comment.new(@first_card, :content => "").blank?
    assert !Card::Comment.new(@first_card, :content => "comment").blank?
  end

  def test_add_comment_as_murmur_should_create_murmur
    @first_card.add_comment :content => "first comment"
    assert_equal 'first comment', find_murmur_from(@first_card).murmur
  end

  def test_should_strip_leading_and_trailing_spaces_for_content
    assert_equal 'with leading space', Card::Comment.new(@first_card, :content => " " + "with leading space").content
    assert_equal 'with leading line break', Card::Comment.new(@first_card, :content => "\n " + "with leading line break").content
    assert_equal 'with trailing space', Card::Comment.new(@first_card, :content => "with trailing space" + " ").content
    assert_equal 'with trailing line break', Card::Comment.new(@first_card, :content => "with trailing line break" + "\n ").content
  end

  def test_author_should_be_the_user_that_created_the_comment_not_the_user_that_created_the_card
    card = create_card!(:name => 'card seven')
    login_as_admin
    card.add_comment :content => 'this is a commented murmur comment'
    assert_equal User.find_by_login('admin'), find_murmur_from(card).author
  end

end
