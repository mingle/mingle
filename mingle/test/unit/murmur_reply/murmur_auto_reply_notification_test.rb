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

class MurmurAutoReplyNotificationTest < ActiveSupport::TestCase

  SAAS_ENABLED = {:saas_env => 'some_env'}

  def test_send_auto_reply_should_return_nil_if_error_type_is_invalid
    MingleConfiguration.overridden_to(SAAS_ENABLED) do
      assert_nil MurmurAutoReplyNotification.new.send_auto_reply_for_message(Mailgun::Message.new, :invalid_error_type)
    end
  end

  def test_send_auto_reply_should_return_nil_on_installer
    assert_nil MurmurAutoReplyNotification.new.send_auto_reply_for_message(Mailgun::Message.new, :invalid_error_type)
  end

  def test_send_auto_reply_for_invalid_user
    MingleConfiguration.overridden_to(SAAS_ENABLED) do
      subject = 'You have been murmured'
      user_email = 'user@email.com'
      murmur_reply_email = 'murmur-reply-abcd@mailgun.com'
      message = Mailgun::Message.new({:from => user_email, :recipient => murmur_reply_email, :subject => subject})
      response = MurmurAutoReplyNotification.new.send_auto_reply_for_message(message, :invalid_operation)
      assert_equal subject, response.subject
      assert_equal "#<TMail::AddressHeader \"Mingle Auto-Reply <#{murmur_reply_email}>\">", response['from'].inspect
      assert_equal user_email, response.to[0]
      assert_equal murmur_reply_email, response.reply_to[0]
      assert_match /resource you requested does not exist/, response.body
    end
  end
end
