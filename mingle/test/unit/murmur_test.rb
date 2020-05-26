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

class MurmurTest < ActiveSupport::TestCase

  def setup
    @project = first_project
    @project.activate
    @member = User.find_by_login('member')
    login_as_member
    view_helper.default_url_options = {:host => 'example.com', :project_id => @project.identifier }
  end

  # bug 9388, jruby postgres does not handle string including \0 (0x00) well
  def test_store_qian_qian_murmur_including_0x00_byte
    dangerous = "murmur: !binary 'I3RlYW1fdXBkYXRlIGNhcmQgbGlzdCBzcGVlZHVwACwgbW9yZSBkZXRhaWwg
      cGxlYXNlIHNlZSBteSBlbWFpbA==
      '"
    murmur = YAML.load(dangerous)['murmur']
    m = create_murmur(:murmur => murmur)
    m.reload
    assert m.murmur
  end

  def test_simple_murmur_with_no_mentions_reply_should_include_author_only
    m = create_murmur(:murmur => 'hello')
    assert_equal "", m.reply_template.join(" ")
    login_as_bob
    assert_equal '@member', m.reply_template.join(" ")
  end

  def test_murmur_reply_should_not_include_system_users
    @member.update_attribute(:system, true)
    m = create_murmur(:murmur => 'commit for card #1', :author => @member)
    login_as_bob
    assert_equal '#1', m.reply_template.join(" ")
  end

  def test_reply_template_should_include_users_and_cards_mentioned_in_murmur
    m = create_murmur(:murmur => '@bob hello have you talked to @admin about #135 and #167?')
    assert_equal '@bob @admin #135 #167', m.reply_template.join(" ")
    login_as_bob
    assert_equal '@member @admin #135 #167', m.reply_template.join(" ")
  end

  def test_reply_template_should_not_include_duplicated_users
    m = create_murmur(:murmur => '@bob @member hello have you talked to @admin about #135 and #167?')
    login_as_bob
    assert_equal '@member @admin #135 #167', m.reply_template.join(" ")
  end

  def test_store_string_including_0x00_byte
    m = create_murmur(:murmur => "\0xxxxx")
    m.reload
    assert m.murmur
  end

  def test_author_can_be_explicitly_set
    assert_equal @member, create_murmur(:author => @member).author
  end

  def test_user_dispaly_name_should_be_author_name_when_there_is_a_mingle_user_associated
    assert_equal 'member@email.com', create_murmur(:author => @member).user_display_name
  end

  def test_should_not_create_if_murmur_is_blank
    assert_raise ActiveRecord::RecordInvalid do
      Murmur.create!(:murmur => '', :project_id => @project.id, :packet_id => '12345abc'.uniquify, :author => User.current)
    end
  end

  def test_create_murmur_with_body
    murmur = @project.murmurs.create(:body => 'hello world', :author => @member)
    assert_equal 'hello world', murmur.murmur
  end

  def test_to_xml
    murmur = create_murmur
    xml = murmur.to_xml
    assert_equal murmur.id.to_s, get_element_text_by_xpath(xml, "/murmur/id")
    assert_equal "default", get_attribute_by_xpath(xml, "/murmur/stream/@type")
    assert_equal murmur.author.login, get_element_text_by_xpath(xml, "/murmur/author/login")
    assert_equal murmur.murmur, get_element_text_by_xpath(xml, "/murmur/body")
    assert_equal 'false', get_element_text_by_xpath(xml, "/murmur/is_truncated")
    assert_equal murmur.created_at.tz_format, get_element_text_by_xpath(xml, "/murmur/created_at")
  end

  def test_to_xml_for_card_comment_murmur_has_stream_type_of_comment
    murmur = murmur_by_commenting(create_card!(:name => 'foo'), 'comment')
    assert_equal "comment", get_attribute_by_xpath(murmur.to_xml, "/murmur/stream/@type")
  end

  def test_to_xml_for_card_comment_murmur_has_origin
    card = create_card!(:name => 'foo')
    murmur = murmur_by_commenting(card, 'comment')
    xml = murmur.to_xml
    assert_equal card.number.to_s, get_element_text_by_xpath(xml, "/murmur/stream/origin/number")
  end

  def test_to_xml_for_card_comment_murmur_has_origin_with_appropriate_url
    card = create_card!(:name => 'foo')
    murmur = murmur_by_commenting(card, 'comment')
    xml = murmur.to_xml(:view_helper => view_helper, :version => 'v2')
    assert_equal "http://example.com/api/v2/projects/first_project/cards/#{card.number}.xml", get_attribute_by_xpath(xml, "/murmur/stream/origin/@url")
  end

  def test_to_xml_for_card_comment_murmur_has_null_origin_if_card_is_deleted
    card = create_card!(:name => 'foo')
    murmur = murmur_by_commenting(card, 'comment')
    card.destroy
    murmur.reload
    xml = murmur.to_xml(:view_helper => view_helper, :version => 'v2')
    assert_equal 'true', get_attribute_by_xpath(xml, "/murmur/stream/origin/@nil")
  end

  def test_should_be_able_to_give_truncated_murmur
    murmur = create_murmur(:murmur => 'a' * 1001)
    xml = murmur.to_xml(:truncate => true)
    assert_equal murmur.truncated_body, get_element_text_by_xpath(xml, "/murmur/body")
    assert_equal 'true', get_element_text_by_xpath(xml, "/murmur/is_truncated")
  end

  def test_should_not_be_truncated_for_short_murmur_even_set_to_truncate
    murmur = create_murmur(:murmur => 'a')
    xml = murmur.to_xml(:truncate => true)
    assert_equal murmur.murmur, get_element_text_by_xpath(xml, "/murmur/body")
    assert_equal 'false', get_element_text_by_xpath(xml, "/murmur/is_truncated")
  end

  def test_can_determine_page_number_based_on_murmur_id
    with_page_size(3) do
      murmur = create_murmur(:murmur => "on page 2")
      (1..3).each { create_murmur(:murmur => "murmur") }
      assert_equal 2, murmur.page_number
    end
  end

  def test_can_determine_page_number_based_on_murmur_id_when_multiple_projects_have_murmurs
    with_page_size(3) do
      murmur = create_murmur(:murmur => "on page 2")
      with_three_level_tree_project do |p|
        (1..4).each { create_murmur }
      end
      (1..3).each { create_murmur }
      assert_equal 2, murmur.page_number
    end
  end

  def test_murmur_content_should_be_stripped
    murmur = create_murmur(:murmur => " \na \n", :project_id => @project.id)
    assert_equal "a", murmur.murmur
  end

  #bug 8259 Remove extra spaces and line breaks on Murmurs
  def test_removes_extra_spaces_and_line_breaks_on_murmurs
    murmur_with_whitespaces = "   \n\r\n\r\n\r   blabla   \n\r\n\r\n\r"
    murmur = create_murmur(:murmur => murmur_with_whitespaces)
    assert_equal "blabla", murmur.murmur
  end

  def test_create_murmur_with_replying_to_murmur
    murmur1 =  create_murmur(:murmur => 'dinner anyone?')
    assert_nil murmur1.conversation
    murmur2 = create_murmur(:murmur => "yeah! what's in your mind?", :replying_to_murmur_id  => murmur1.id)
    murmur3 = create_murmur(:murmur => "cheese cake factory", :replying_to_murmur_id  => murmur2.id)
    assert_not_nil murmur1.reload.conversation
    assert_equal murmur1.conversation, murmur2.conversation
    assert_equal murmur2.conversation, murmur3.conversation
    assert_equal @project, murmur1.conversation.project
  end

  def test_murmur_created_without_replying_to_murmur_id_should_not_have_conversation
    assert_nil create_murmur(:murmur => 'dinner anyone?').reload.conversation
    assert_nil create_murmur(:murmur => 'dinner anyone?', :replying_to_murmur_id => "").reload.conversation
    assert_nil create_murmur(:murmur => 'dinner anyone?', :replying_to_murmur_id => "   ").reload.conversation
  end

  def test_mentions_should_return_all_the_mentions_in_murmur
    murmur = create_murmur(murmur: '@haha [@hoho] @haha, sdfdsf emial@thoug.com @email@thoughtworks.com').reload

    assert_equal %w(haha hoho haha email@thoughtworks.com), murmur.mentions
  end

  def test_should_describe_origin_type_of_murmur_for_default_type
    murmur = create_murmur(murmur: '@haha [@hoho] @haha, sdfdsf emial@thoug.com @email@thoughtworks.com', type: 'DefaultMurmur').reload

    assert_equal 'Project', murmur.origin_type_description
  end

  def test_should_give_card_number_as_origin_type_for_card_comment_type_murmur
    card = create_card!(:number => 10, :name => 'first card', :card_type_name => 'Card')
    card.add_comment :content => "#10 is great"
    card_murmur = find_murmur_from(card)

    assert_equal "#10", card_murmur.origin_type_description
  end

  private
  def murmur_by_commenting(card, comment, comment_attributes={})
    comment_attributes = comment_attributes.merge(:content => comment)
    card.comment = comment_attributes
    card.save!
    card.origined_murmurs.last
  end
end
