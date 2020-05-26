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

class InviteToTeamMailerTest < ActiveSupport::TestCase

  def setup
    @project = first_project
    @invitee = create_user!
    @inviter = User.first_admin
  end

  def test_invitation_for_existing_user_has_name_in_greeting
    email = InviteToTeamMailer.create_invitation_for_existing_user(:invitee => @invitee, :inviter => @inviter, :project => @project)
    assert_include "Hi #{@invitee.name}", email.body
  end

  def test_invitation_for_existing_user_has_informative_subject_line
    email = InviteToTeamMailer.create_invitation_for_existing_user(:invitee => @invitee, :inviter => @inviter, :project => @project)
    assert_equal "#{@inviter.name} has invited you to join the Mingle project: #{@project.name}", email.subject
  end

  def test_invitation_for_existing_user_mail_has_a_sender
    email = InviteToTeamMailer.create_invitation_for_existing_user(:invitee => @invitee, :inviter => @inviter, :project => @project)
    assert_equal [ActionMailer::Base.default_sender[:address]],  email.from
  end

  def test_invitation_for_existing_user_is_sent_to_invitee
    email = InviteToTeamMailer.create_invitation_for_existing_user(:invitee => @invitee, :inviter => @inviter, :project => @project)
    assert_equal [@invitee.email], email.to
  end

  def test_invitation_for_existing_user_contain_absolute_project_link
    email = InviteToTeamMailer.create_invitation_for_existing_user(:invitee => @invitee, :inviter => @inviter, :project => @project)
    assert_include "#{MingleConfiguration.site_url}/projects/#{@project.identifier}", email.body
  end

  def test_invitation_for_new_user_should_generate_a_lost_password_ticket_that_expires_in_7_days
    assert_nil @invitee.login_access.lost_password_ticket
    Clock.fake_now('2014-02-13 10:00:00')
    InviteToTeamMailer.create_invitation_for_new_user(:invitee => @invitee, :inviter => @inviter, :project => @project)
    Clock.fake_now('2014-02-20 09:59:00')
    assert_not_nil LoginAccess.find_by_lost_password_ticket(@invitee.login_access.lost_password_ticket)

    Clock.fake_now('2014-02-20 10:01:00')
    assert_nil LoginAccess.find_by_lost_password_ticket(@invitee.login_access.lost_password_ticket)
  end

  def test_invitation_for_new_user_skips_name_in_greeting
    email = InviteToTeamMailer.create_invitation_for_new_user(:invitee => @invitee, :inviter => @inviter, :project => @project)
    assert_include "Hey!", email.body
  end

  def test_invitation_for_new_user_should_include_link_to_set_password
    email = InviteToTeamMailer.create_invitation_for_new_user(:invitee => @invitee, :inviter => @inviter, :project => @project)
    assert_equal [@invitee.email], email.to
    assert_equal "#{@inviter.name} has invited you to join Mingle", email.subject

    ticket = @invitee.login_access.lost_password_ticket

    assert_include "profile/set_password?ticket=#{ticket}", email.body
  end

  def test_ask_for_upgrade_should_have_site_url_in_subject
    email = InviteToTeamMailer.create_ask_for_upgrade(:requester => @inviter)
    assert_equal "Alert: Mingle SaaS - More users are wanted for #{MingleConfiguration.site_url}", email.subject
  end

  def test_ask_for_upgrade_should_be_sent_to_the_configured_ask_for_upgrade_email_recipient
    MingleConfiguration.with_ask_for_upgrade_email_recipient_overridden_to("license.person@tw.com") do
      email = InviteToTeamMailer.create_ask_for_upgrade(:requester => @inviter)
      assert_equal ["license.person@tw.com"], email.to
    end
  end

  def test_ask_for_upgrade_should_have_site_url_and_lead_info_in_body
    email = InviteToTeamMailer.create_ask_for_upgrade(:requester => @inviter)
    assert_include MingleConfiguration.site_url, email.body
    assert_include User.first_admin.email, email.body
    assert_include User.first_admin.name, email.body
    assert_include CurrentLicense.registration.max_active_full_users.to_s, email.body
  end

  def test_ask_for_upgrade_should_have_requesting_user_included_in_email
    requester = create_user!
    email = InviteToTeamMailer.create_ask_for_upgrade(:requester => requester)
    assert_include requester.name, email.body
    assert_include requester.email, email.body
  end



end
