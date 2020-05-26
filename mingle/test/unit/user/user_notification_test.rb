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

class UserNotificationTest < ActiveSupport::TestCase
  def setup
    @user = create_user!
  end

  def test_user_can_remember_last_message_read
    assert_false @user.has_read_notification?("foo")
    @user.mark_notification_read("foo")
    assert @user.has_read_notification?("foo")
    assert_false @user.has_read_notification?("bar")
  end

  def test_user_has_bad_memory_for_previous_notifications
    @user.mark_notification_read("foo")
    @user.mark_notification_read("bar")
    assert @user.has_read_notification?("bar")
    assert_false @user.has_read_notification?("foo")
  end

  def test_by_default_user_has_read_all_blank_message
    assert @user.has_read_notification?("  ")
    assert @user.has_read_notification?("")
    assert @user.has_read_notification?(nil)
  end


end
