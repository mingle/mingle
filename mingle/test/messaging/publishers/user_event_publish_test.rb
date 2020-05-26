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
require File.expand_path(File.dirname(__FILE__) + '/../messaging_test_helper')

# Tags: messaging, users, indexing
class UserEventPublishTest < ActiveSupport::TestCase
  include MessagingTestHelper
  
  def setup
    route(:from => UserEventPublisher::QUEUE, :to => TEST_QUEUE)
  end
  
  def test_update_user
    login_as_admin
    with_first_project do |project|
      user = create_user!
      assert_receive_nil_from_queue
      old_name = user.name
      new_name = 'New Name'.uniquify
      user.update_attribute(:name, new_name)
      assert_message_in_queue_contains :changed_columns => {'name' => {'old' => old_name, 'new' => new_name}}
    end
  end
  
  def test_should_clear_previously_changed_columns_with_old_and_new_values_after_message_published
    bob = User.find_by_login('bob')
    login_as_bob
    
    with_first_project do |project|
      bob.update_attribute :name, 'new bob'
      
      assert_message_in_queue_contains :changed_columns => {'name' => {'old' => 'bob@email.com', 'new' => 'new bob'}}

      bob = User.find_by_login('bob')
      bob.update_attribute(:name, 'new new bob')

      assert_message_in_queue_contains :changed_columns => {'name' => {'old' => 'new bob', 'new' => 'new new bob'}}
    end
  end
  
  
  def test_update_user_icon_should_not_send_out_message
    login_as_admin
    with_first_project do |project|
      user = create_user!
      assert user.update_attributes(:icon => sample_attachment("user_icon.gif"))
      assert_receive_nil_from_queue
    end
  end

end
