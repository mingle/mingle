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

class MurmurNotificationMailer < ActionMailer::Base
  def self.get_deliver_notify_params(users, project, murmur)
    @@invocation_params ||= {}
    @@invocations ||= 0
    @@invocations += 1
    @@invocation_params[@@invocations] = {:users => users, :project => project, :murmur => murmur}
  end
end

class MurmurEmailNotificationTest < ActiveSupport::TestCase

  def setup
    @user_with_email_id = find_or_create_user!(:login => 'user_with_email')
    @user_without_email_id = find_or_create_user!(:login => 'user_without_email', :email => nil)
    @user_creating_murmur = find_or_create_user!(:login => 'user_creating_murmur')

    @project = create_project(:users => [@user_with_email_id, @user_without_email_id]).activate
    login(@user_with_email_id)
    MurmurNotificationMailer.class_eval do
      class_variable_set(:@@invocation_params, {})
      class_variable_set(:@@invocations, 0)
      class << self
        alias_method :deliver_notify, :get_deliver_notify_params
      end
    end
  end

  def test_should_not_do_anything_if_all_users_are_without_email_id
    MurmurEmailNotification.new.deliver_notify([@user_without_email_id], @project, create_murmur(:author => @user_creating_murmur))

    assert_equal 0, value_for('invocations')
  end

  def test_should_filter_users_without_email_id
    MurmurEmailNotification.new.deliver_notify([@user_with_email_id, @user_without_email_id], @project, create_murmur(:author => @user_creating_murmur))

    assert_equal 1, value_for('invocations')
    assert_equal [@user_with_email_id], value_for('invocation_params')[1][:users]
  end

  def test_should_not_call_deliver_notify_for_a_user_creating_the_murmur
      user2= find_or_create_user!(:login => 'user_with_email2')
      @project.add_member(user2)

      MurmurEmailNotification.new.deliver_notify([@user_with_email_id, user2], @project, create_murmur(:author => user2))

      assert_equal 1, value_for('invocations')
      assert_equal [@user_with_email_id], value_for('invocation_params')[1][:users]
  end

  def test_should_call_deliver_notify_for_each_user_when_new_murmur_notification_is_toggled_on
      user2= create_user!(:login => 'user_with_email2')
      @project.add_member(user2)

      MurmurEmailNotification.new.deliver_notify([@user_with_email_id, user2], @project, create_murmur(:author => @user_creating_murmur))

      assert_equal 2, value_for('invocations')
      assert_equal [@user_with_email_id], value_for('invocation_params')[1][:users]
      assert_equal [user2], value_for('invocation_params')[2][:users]
  end

  def teardown
    MurmurNotificationMailer.class_eval do
      remove_class_variable(:@@invocation_params)
      remove_class_variable(:@@invocations)
      class << self
        remove_method :deliver_notify
      end
    end
  end

  private

  def value_for(var_name)
    MurmurNotificationMailer.class_eval { class_variable_get("@@#{var_name}".to_sym) }
  end
end
