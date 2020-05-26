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

class MurmurNotificationMailerTest < ActiveSupport::TestCase
  def setup
    @old_mingle_site_url = MingleConfiguration.site_url
    MingleConfiguration.site_url = 'http://test.host'

    SmtpConfiguration.load
    ActionMailer::Base.deliveries = []

    @bob = User.find_by_login('bob')
    @member = User.find_by_login('member')
    @project = create_project(:users =>[@member, @bob])

    @project.activate
    login_as_member
  end

  def teardown
    MingleConfiguration.site_url = @old_mingle_site_url
  end

  def test_notify_email
    with_asset_host('http://test.asset.host') do
      murmur = @project.murmurs.create!(:murmur => "@#{@bob.login} likes murmur",
                                        :author => User.current)

      response = MurmurNotificationMailer.deliver_notify([@bob], @project, murmur)

      assert_equal "[Mingle] You have been murmured from #{@project.name}", response.subject

      assert_equal "#<TMail::AddressHeader \"\\\"member@email.com (member)\\\"<hello@example.com>\">", response['from'].inspect
      assert_equal @bob.email, response.bcc[0]

      assert_match /#{murmur.user_display_name}/, response.body
      assert_match /src="http:\/\/test.asset.host\/images\/avatars\/m.png/, response.body
    end
  end

  def test_from_address_and_reply_to_header_set_when_reply_from_murmurs_toggled_on
    MingleConfiguration.murmur_email_from_address = 'murmur-test@email.com'
    MingleConfiguration.with_saas_env_overridden_to(true) do
      murmur = @project.murmurs.create!(:murmur => "@#{@bob.login} likes murmur",
                                        :author => User.current)
      response = MurmurNotificationMailer.deliver_notify([@bob], @project, murmur)
      assert_equal "#<TMail::AddressHeader \"\\\"member@email.com (member)\\\"<murmur-test@email.com>\">", response['from'].inspect
      assert_not_nil response['reply-to']
    end
  end

  def test_reply_to_header_set_is_unique_for_different_emails
    MingleConfiguration.murmur_email_from_address = 'murmur-test@email.com'
    MingleConfiguration.with_saas_env_overridden_to(true) do
      murmur = @project.murmurs.create!(:murmur => "@#{@bob.login} likes murmur",
                                        :author => User.current)
      response = MurmurNotificationMailer.deliver_notify([@bob], @project, murmur)
      assert_not_nil response['reply-to']
      assert_equal 1, response['reply-to'].addrs.size
      first_address = response['reply-to'].addrs.first

      murmur = @project.murmurs.create!(:murmur => "@#{@bob.login} still likes murmur",
                                        :author => User.current)
      response = MurmurNotificationMailer.deliver_notify([@bob], @project, murmur)
      assert_not_nil response['reply-to']
      assert_equal 1, response['reply-to'].addrs.size
      second_address = response['reply-to'].addrs.first
      assert_not_equal first_address, second_address
    end
  end

  def test_reply_to_header_is_saved_on_firebase
    MingleConfiguration.overridden_to(:firebase_app_url => "https://mingle-test.firebaseio.com",
                                      :firebase_secret => "cLhtT3Rr3Oxj4JXSheSy3uzgWEngZN7V6PNMo2qX",
                                      :app_namespace => 'test',
                                      :saas_env => 'some_env',
                                      :murmur_email_from_address => 'murmur-test@email.com') do

      client = FirebaseClient.new(MingleConfiguration.firebase_app_url, MingleConfiguration.firebase_secret)
      client.delete("/murmur_email_replies")
      murmur = @project.murmurs.create!(:murmur => "@#{@bob.login} likes murmur",
                                        :author => User.current)
      response = MurmurNotificationMailer.deliver_notify([@bob], @project, murmur)

      fb_response = client.get(FirebaseKeys.murmur_email_replies(response['reply-to'].addrs.first.address))

      assert_not_nil fb_response.parsed_response
      assert_equal 1, fb_response.values.size

      email_data = fb_response.values.first
      assert email_data.delete("fbPublishedAt").present?, "should have a firebase timestamp"
      assert_equal 'test', email_data.delete('tenant')
      assert_equal murmur.id, email_data.delete('murmur_id')
      assert_equal @bob.id, email_data.delete('user_id')
    end
  end


  def test_should_not_show_images_if_no_asset_host_configured
    murmur = @project.murmurs.create!(:murmur => "@#{@bob.login} likes murmur",
                                      :author => User.current)

    response = MurmurNotificationMailer.deliver_notify([@bob], @project, murmur)

    assert_not_include '<img', response.body
  end

  def test_use_first_line_of_murmur_content_as_subject
    murmur = @project.murmurs.create!(:murmur => "@#{@bob.login} likes murmur\nhaha",
                                      :author => User.current)

    response = MurmurNotificationMailer.deliver_notify([@bob], @project, murmur)
    assert_equal "[Mingle] You have been murmured from #{@project.name}", response.subject
  end

  def test_use_card_number_and_project_name_as_subject_for_murmurs_in_cards_and_prefix_subject_with_Mingle
    card = @project.cards.create!(:name => 'card with murmur', :card_type_name => 'card', :number => 786 )
    murmur = card.origined_murmurs.create!(:murmur => "@#{@bob.login} likes murmur\nhaha",
                                   :author => User.current, :project_id => @project.id)

    response = MurmurNotificationMailer.deliver_notify([@bob], @project, murmur)
    assert_equal "[Mingle] You have been murmured from #786 in #{@project.name}", response.subject
  end

  def test_send_email_by_user_who_has_special_name
    name = 'Us!@#$%^&*()_+-=<>,.'
    User.current.update_attribute(:name, name)
    murmur = @project.murmurs.create!(:murmur => "@#{@bob.login} likes murmur",
                                      :author => User.current)

    response = MurmurNotificationMailer.deliver_notify([@bob], @project, murmur)
    assert_equal "#<TMail::AddressHeader \"\\\"Us!@\\\\\\\#$%^&*()_+-=<>,. (member)\\\"<hello@example.com>\">", response['from'].inspect
  end

  def test_email_should_include_card_links_related_to_the_murmur
    @card = @project.cards.create!(:name => 'haha card', :card_type_name => 'card', :number => 555)
    murmur = CardCommentMurmur.create(:project_id => @project.id, :murmur => "@#{@bob.login} likes murmur #1", :author_id => User.current.id, :origin => @card)

    response = MurmurNotificationMailer.deliver_notify([@bob], @project, murmur)

    assert_match /<a[^>]*>\#1<\/a>/, response.body
    assert_match /<a[^>]*>\#555<\/a>/, response.body
    assert_match /#{@card.name}/, response.body
  end

  def test_email_should_include_all_the_murmurs_when_a_user_is_mentioned
    card = @project.cards.create!(:name => 'haha card', :card_type_name => 'card', :number => 555)
    murmur1 = CardCommentMurmur.create(:project_id => @project.id, :murmur => "@#{@bob.login} likes murmur #1", :author_id => User.current.id, :origin => card)
    murmur2 = CardCommentMurmur.create(:project_id => @project.id, :murmur => "@#{@member.login} likes murmur #5", :author_id => User.current.id, :origin => card)

    response = MurmurNotificationMailer.deliver_notify([@member], @project, murmur2)

    assert_match /<a[^>]*>\#1<\/a>/, response.body
    assert_match /<a[^>]*>\#555<\/a>/, response.body
    assert_match /<a[^>]*>\#5<\/a>/, response.body
    assert_match /#{card.name}/, response.body
  end

  def test_should_have_the_card_url_number_and_name_in_the_card_murmur_greeting
    card = @project.cards.create!(:name => 'Card with murmurs', :card_type_name => 'card', :number => 555)

    murmur = card.origined_murmurs.create!(:murmur => "hey @#{@bob.login}",
                                            :author => @member, :project => @project)

    response = MurmurNotificationMailer.deliver_notify([@bob], @project, murmur)

    assert_match "You've been murmured from <a href=\"http://test.host/projects/#{@project.identifier}/cards/555\" class=\"card-tool-tip card-link-555\" data-card-name-url=\"http://test.host/projects/#{@project.identifier}/cards/card_name/555\">#555</a>", response.body
    assert_match ': Card with murmurs', response.body
  end

  def test_should_have_the_project_name_and_url_for_global_murmur_greeting
    murmur = @project.murmurs.create!(:murmur => "hey @#{@bob.login}", :author => @member)

    response = MurmurNotificationMailer.deliver_notify([@bob], @project, murmur)

    assert_match "You've been murmured from <a href=\"http://test.host/projects/#{@project.identifier}?murmur_id=#{murmur.id}\">#{@project.name}</a>", response.body
  end
end
