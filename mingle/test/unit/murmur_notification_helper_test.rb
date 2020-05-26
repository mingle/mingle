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

class MurmurNotificationHelperTest < ActiveSupport::TestCase
  include MurmurNotificationHelper

  def setup
    @old_mingle_site_url = MingleConfiguration.site_url
    MingleConfiguration.site_url = 'http://test.host'

    @bob = User.find_by_login('bob')
    @member = User.find_by_login('member')
    @project = create_project(:users =>[@member, @bob])

    @project.activate
    login_as_member
    @card = @project.cards.create!(:name => 'card with murmur', :card_type_name => 'card', :number => 786 )
  end

  def teardown
    MingleConfiguration.site_url = @old_mingle_site_url
  end

  def test_should_add_border_style_for_murmurs_except_latest_murmur
    first_murmur = @card.origined_murmurs.create!(:murmur => "@#{@bob.login} likes murmur\nhaha",
                                           :author => User.current, :project => @project)
    second_murmur = @card.origined_murmurs.create!(:murmur => 'second murmur',
                                                  :author => User.current, :project => @project)

    style = notification_style(second_murmur, @card.discussion, @bob)

    assert_not_include 'border-top' , style

    style = notification_style(first_murmur, @card.discussion, @bob)

    assert_match /border-top: 1px solid #DFDFDF; padding-top: 1px; margin-top: 1px;/ , style
  end

  def test_should_add_grey_background_for_the_latest_murmur
    first_murmur = @card.origined_murmurs.create!(:murmur => 'first murmur',
                                                  :author => @member, :project => @project)
    second_murmur = @card.origined_murmurs.create!(:murmur => 'second murmur',
                                                   :author => User.current, :project => @project)

    style = notification_style(second_murmur, @card.discussion, @bob)

    assert_match /background-color: #F5F5F5/ , style

    style = notification_style(first_murmur, @card.discussion, @bob)

    assert_match /background-color: #FFFFFF/, style
  end

  def test_should_add_blue_background_for_the_murmurs_in_which_user_is_mentioned
    first_murmur = @card.origined_murmurs.create!(:murmur => "hey @#{@bob.login}",
                                                  :author => @member, :project => @project)
    second_murmur = @card.origined_murmurs.create!(:murmur => 'second murmur',
                                                   :author => User.current, :project => @project)

    style = notification_style(second_murmur, @card.discussion, @bob)

    assert_match /background-color: #F5F5F5/ , style

    style = notification_style(first_murmur, @card.discussion, @bob)

    assert_match /background-color: #E9F2F8/, style
  end

  def test_should_format_created_at_for_murmur_according_to_project_date_format
    murmur = Murmur.new(:created_at => DateTime.parse('2016-08-04 14:30:56 IST'))
    @project.update_attributes('time_zone' => 'Bangkok', 'date_format' => '%Y/%m/%d')

    murmured_at = murmured_at(murmur)

    assert_equal '2016/08/04 16:00 ICT', murmured_at
  end

  def test_should_inline_style_for_mentioned_users
    murmur_content_with_user_mention_html = 'hey <a class="at-highlight at-user">@test_user</a>'

    formatted_content = format_murmur_notification(murmur_content_with_user_mention_html)

    assert_equal 'hey <a style="color: #3FBEEA; text-decoration: none;">@test_user</a>', formatted_content
  end

  def test_should_add_card_name_as_tooltip_for_valid_card_links
    murmur_content_with_card_link_html = "have a look at <a class=\"card-tool-tip\">#{@card.prefixed_number}</a>"

    formatted_content = format_murmur_notification(murmur_content_with_card_link_html)

    assert_equal "have a look at <a title=\"#{@card.name}\">#{@card.prefixed_number}</a>", formatted_content
  end

  def test_should_add_card_name_with_quotes_correctly_for_valid_card_links
    @card.name = 'Card with "quotes \' "'
    @card.save!
    murmur_content_with_card_link_html = "have a look at <a class=\"card-tool-tip\">#{@card.prefixed_number}</a>"

    formatted_content = format_murmur_notification(murmur_content_with_card_link_html)

    assert_equal "have a look at <a title=\"Card with &quot;quotes &#39; &quot;\">#{@card.prefixed_number}</a>", formatted_content
  end

  def test_should_add_card_not_found_as_tooltip_for_invalid_card_links
    murmur_content_with_card_link_html = 'hey <a class="at-highlight at-user">@test_user</a> have a look at <a class="card-tool-tip">#9999</a>'

    formatted_content = format_murmur_notification(murmur_content_with_card_link_html)

    assert_equal 'hey <a style="color: #3FBEEA; text-decoration: none;">@test_user</a> have a look at <a title="Card not found!">#9999</a>', formatted_content
  end

  def test_discussion_should_return_all_the_murmurs_in_a_card_if_its_a_card_murmur
    first_murmur = @card.origined_murmurs.create!(:murmur => "hey @#{@bob.login}",
                                                  :author => @member, :project => @project)
    second_murmur = nil
    Timecop.travel(DateTime.now + 1) do
      second_murmur = @card.origined_murmurs.create!(:murmur => 'second murmur',
                                                   :author => User.current, :project => @project)
    end
    discussion = discussion(second_murmur)

    assert_equal [second_murmur,first_murmur], discussion

  end

  def test_discussion_should_return_all_the_murmurs_in_the_same_conversation_if_its_a_project_murmur
    first_murmur = @project.murmurs.create!(:murmur => "hey @#{@bob.login}", :author => @member)

    second_murmur = @project.murmurs.create!(:murmur => 'second murmur',
                                                   :author => User.current, :replying_to_murmur_id => first_murmur.id)
    third_murmur = @project.murmurs.create!(:murmur => "hey @#{@bob.login}",
                                                  :author => @member, :project => @project)

    discussion = discussion(second_murmur)

    assert_equal [DefaultMurmur.find_by_id(second_murmur.id), DefaultMurmur.find_by_id(first_murmur.id)], discussion

    end


  def test_discussion_should_return_only_project_murmurs_if_its_a_project_murmur
    first_murmur = @project.murmurs.create!(:murmur => "hey @#{@bob.login}", :author => @member)

    second_murmur = @card.origined_murmurs.create!(:murmur => 'second murmur',
                                                   :author => User.current, :project => @project)


    discussion = discussion(first_murmur)

    assert_equal [first_murmur], discussion

  end




end
