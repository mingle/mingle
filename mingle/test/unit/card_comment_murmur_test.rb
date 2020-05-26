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

class CardCommentMurmurTest < ActiveSupport::TestCase

  def setup
    @project = first_project
    @project.activate
    @member = User.find_by_login('member')
    login_as_member
  end

  def test_card_comment_murmurs_should_be_created_for_the_same_project_as_the_card
    murmur = murmur_by_comment(card, "Comment")
    assert_equal "Comment", murmur.murmur
    assert_equal @project.id, murmur.project_id
  end

  def test_card_comment_murmurs_should_be_created_by_the_modifier_of_the_card
    assert_equal User.current.id, murmur_by_comment(card, "Comment").author_id
  end

  def test_card_comment_murmurs_should_contain_origin_as_the_originating_card
    assert_equal card, murmur_by_comment(card, "Comment").origin
  end

  def test_card_comment_murmurs_should_describe_origin
    murmur = murmur_by_comment(card, "Comment")
    assert_equal "Card ##{card.number}", murmur.describe_origin
  end

  def test_card_comment_murmurs_should_describe_origin_as_a_deleted_card_if_card_is_deleted
    murmur = murmur_by_comment(card, "Comment")
    card.destroy
    assert_nil murmur.reload.origin_id
  end

  def test_card_comment_murmurs_should_describe_origin_as_a_deleted_card_if_card_is_bulk_deleted
    murmur = murmur_by_comment(card, "Comment")
    CardSelection.new(@project, [card]).destroy
    assert_nil murmur.reload.origin_id
  end

  def test_reply_template_should_include_card_murmured_from
    User.find_by_login('bob').with_current do
      card.add_comment :content => "first comment #4"
    end
    m = find_murmur_from(card)
    assert_equal "@bob ##{card.number} #4", m.reply_template.join(" ")
  end

  def test_reply_template_should_not_have_duplicated_card_numbers
    User.find_by_login('bob').with_current do
      card.add_comment :content => "first comment #4 ##{card.number} #4"
    end
    m = find_murmur_from(card)
    assert_equal "@bob ##{card.number} #4", m.reply_template.join(" ")
  end

  def test_reply_template_for_deleted_card
    User.find_by_login('bob').with_current do
      card.add_comment :content => "first comment #4"
      card.delete
    end
    m = find_murmur_from(card)
    assert_equal "@bob #4", m.reply_template.join(" ")
  end

  def test_replying_a_card_murmur_should_create_conversation
    murmur = murmur_by_comment(card, "hey @team, what do you think about this card")
    reply = murmur_by_comment(card, "+1000, I want this for a long time", :replying_to_murmur_id => murmur.id)

    assert_not_nil murmur.reload.conversation
    assert_equal murmur.reload.conversation, reply.reload.conversation
  end

  private

  def card
    @card ||= @project.cards.first
  end

  def murmur_by_comment(card, comment, comment_attributes={})
    comment_attributes = comment_attributes.merge(:content => comment)
    card.comment = comment_attributes
    card.save!
    card.origined_murmurs.last
  end
end
