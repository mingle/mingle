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

class InvalidUserMessageFilterTest < ActiveSupport::TestCase

  def setup
    @project = first_project
    @project.activate
    @member = User.find_by_login('member')
    login_as_member
    MingleConfiguration.multitenancy_mode = true
  end

  def teardown
    Multitenancy.clear_tenants
    MingleConfiguration.multitenancy_mode = nil
  end

  def test_should_filter_messages_with_invalid_user_id
    db_config = ActiveRecord::Base.connection.config
    Multitenancy.add_tenant('tenantx', "database_username" => db_config[:username], 'db_config' => {'url' => db_config[:url]})
    murmur = create_murmur(:murmur => 'hello')
    murmur_data = {
        'murmur_id' => murmur.id,
        'reply_to_email' => 'test@email.com',
        'user_id' => 9999999,
        'tenant' => 'tenantx'
    }
    message = create_message_data(@member.email)
    auto_reply_notification = mock
    message_filter = InvalidUserMessageFilter.new(auto_reply_notification)

    auto_reply_notification.expects(:send_auto_reply_for_message).with(message, :invalid_operation)
    assert message_filter.filter?(message, murmur_data)
  end

  def test_should_filter_messages_when_tenant_does_not_exist
    murmur = create_murmur(:murmur => 'hello')
    murmur_data = {
        'murmur_id' => murmur.id,
        'reply_to_email' => 'test@email.com',
        'user_id' => @member.id,
        'tenant' => 'invalid_tenant'
    }
    message = create_message_data(@member.email)
    auto_reply_notification = mock
    auto_reply_notification.expects(:send_auto_reply_for_message).with(message, :invalid_operation)

    message_filter = InvalidUserMessageFilter.new(auto_reply_notification)
    assert message_filter.filter?(message, murmur_data)
  end

  def test_should_not_filter_when_valid_user_exists_in_tenant
    db_config = ActiveRecord::Base.connection.config
    Multitenancy.add_tenant('tenantx', "database_username" => db_config[:username], 'db_config' => {'url' => db_config[:url]})
    murmur = create_murmur(:murmur => 'hello')
    murmur_data = {
        'murmur_id' => murmur.id,
        'reply_to_email' => 'test@email.com',
        'user_id' => @member.id,
        'tenant' => 'tenantx'
    }
    auto_reply_notification = mock
    auto_reply_notification.expects(:send_auto_reply_for_message).never
    assert_false InvalidUserMessageFilter.new.filter?(create_message_data(@member.email), murmur_data)
    assert InvalidUserMessageFilter.new.filter?(create_message_data('incorrect@email.com'), murmur_data)
  end

   def test_should_filter_when_user_is_deactivated
    db_config = ActiveRecord::Base.connection.config
    Multitenancy.add_tenant('tenantx', "database_username" => db_config[:username], 'db_config' => {'url' => db_config[:url]})
    user = nil
    murmur = nil
    with_new_project do |project|
      user = create_user!(:email => 'test@email.com')
      project.add_member(user)
      login(user)
      murmur = create_murmur(:murmur => 'hello')
    end
    user.update_attribute(:activated, false)
    murmur_data = {
        'murmur_id' => murmur.id,
        'reply_to_email' => 'test@email.com',
        'user_id' => user.id,
        'tenant' => 'tenantx'
    }
    auto_reply_notification = mock
    message_filter = InvalidUserMessageFilter.new(auto_reply_notification)
    message = create_message_data(user.email)
    auto_reply_notification.expects(:send_auto_reply_for_message).with(message, :invalid_operation)

    assert message_filter.filter?(message, murmur_data)
  end

  private
  def create_message_data(from_email)
    options = {
        :from => TMail::Address.parse(from_email),
        :recipient => TMail::Address.parse('test@email.com'),
        :subject => 'Testing murmur poller',
        :storage_url => 'http://testing-murmur-poller@email.com',
        :timestamp => Time.now.to_f
    }
    Mailgun::Message.new(options)
  end

end
