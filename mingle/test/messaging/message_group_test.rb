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
require File.expand_path(File.dirname(__FILE__) + '/messaging_test_helper')

# Tags: messaging, messagegroup
class MessageGroupTest < ActionController::TestCase
  include MessagingTestHelper

  def setup
    @project_id = 1
    @action = 'action'
    @group = MessageGroup.create!(:action => @action, :project_id => @project_id)
  end
  
  def teardown
    @group.destroy
  end

  def test_group_exists_when_there_are_messages_sent_and_not_processed
    @group.activate { send_a_message_to_test_queue }
    assert group_exists?
  end

  def test_group_not_exists_after_all_messages_in_group_are_processed
    @group.activate { send_two_message_to_test_queue }

    receive_message(TEST_QUEUE)
    receive_message(TEST_QUEUE)

    assert_false group_exists?
  end

  def test_group_exists_when_there_is_message_in_group_not_processed_yet
    @group.activate { send_two_message_to_test_queue }
  
    receive_message(TEST_QUEUE)
    assert group_exists?
  end

  def test_group_exists_when_messages_consumed_and_send_at_same_time
    @group.activate { send_a_message_to_test_queue }

    receive_message(TEST_QUEUE) do |message|
      send_a_message_to_test_queue
    end
    assert group_exists?
  end

  def send_two_message_to_test_queue
    Messaging::Processor.new.send_message(TEST_QUEUE, [create_message, create_message])
  end

  def send_a_message_to_test_queue
    Messaging::Processor.new.send_message(TEST_QUEUE, [create_message])
  end

  def create_message
    Messaging::SendingMessage.new(:message => "message")
  end
  
  def group_exists?
    !!MessageGroup.find_by_group_id(@group.group_id)
  end
end
