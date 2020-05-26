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

class LoginAccessTest < ActiveSupport::TestCase

  def setup
    @member = User.find_by_login('member')
  end

  def test_can_find_login_access_based_on_forgotten_password_ticket
    ticket = @member.login_access.generate_lost_password_ticket!
    assert_equal @member, LoginAccess.find_by_lost_password_ticket(ticket).user
  end

  def test_generate_lost_password_ticket
    assert_nil @member.login_access.lost_password_key
    @member.login_access.generate_lost_password_ticket!
    assert_not_nil @member.login_access.lost_password_key
  end

  def test_generate_lost_password_ticket_expires_after_1_hour_by_default
    Clock.fake_now('2014-02-10 13:00:00')
    @member.login_access.generate_lost_password_ticket!
    Clock.fake_now('2014-02-10 13:59:00')
    assert_not_nil LoginAccess.find_by_lost_password_ticket(@member.login_access.lost_password_ticket)
    Clock.fake_now('2014-02-10 14:00:01')
    assert_nil LoginAccess.find_by_lost_password_ticket(@member.login_access.lost_password_ticket)
  end

  def test_generate_lost_can_be_set_to_expire_in_the_future
    Clock.fake_now('2014-02-10 13:00:00')
    @member.login_access.generate_lost_password_ticket!(:expires_in => 3.days)

    Clock.fake_now('2014-02-13 12:59:00')
    assert_not_nil LoginAccess.find_by_lost_password_ticket(@member.login_access.lost_password_ticket)

    Clock.fake_now('2014-02-13 13:01:00')
    assert_nil LoginAccess.find_by_lost_password_ticket(@member.login_access.lost_password_ticket)
  end

  def test_has_alias_lost_password_ticket
    ticket = @member.login_access.generate_lost_password_ticket!
    assert_equal ticket, @member.login_access.lost_password_key
    assert_equal @member.login_access.lost_password_key, @member.login_access.lost_password_ticket
  end

  def test_find_user_by_login_token
    @member.login_access.update_attribute(:login_token, 'token')
    assert_equal @member, LoginAccess.find_user_by_login_token('token')
  end

  def test_find_user_by_login_token_should_return_nil_when_given_a_wrong_token
    assert_nil LoginAccess.find_user_by_login_token('not exist token')
  end

  def test_should_be_able_to_specify_a_ticket
    @member.login_access.assign_lost_password_ticket('my-ticket')
    login_access = LoginAccess.find_by_lost_password_ticket('my-ticket')
    assert_equal @member, login_access.user
    assert login_access.lost_password_reported_at <= Time.now
  end
end
