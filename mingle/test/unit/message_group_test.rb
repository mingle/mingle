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

# Tags: messagegroup
class MessageGroupTest < ActiveSupport::TestCase

  def test_should_be_done_when_nothing_happen_after_created_group
    group = MessageGroup.create!(:project_id => 1, :action => 'action')
    assert group.done?
  end

  def test_should_cause_group_not_done_after_mark_a_message
    group = MessageGroup.create!(:project_id => 1, :action => 'action')
    assert group.done?
    group.mark(Messaging::SendingMessage.new(:body => 'message'))
    assert_false group.done?
  end

  def test_should_be_done_after_process_all_messages
    group = MessageGroup.create!(:project_id => 1, :action => 'action')
    message = Messaging::SendingMessage.new(:body => 'message')
    group.mark(message)
    MessageGroup.processing(to_receiving_message(message))
    assert group.done?
  end

  def test_should_not_done_when_marked_new_message_while_processing_message
    group = MessageGroup.create!(:project_id => 1, :action => 'action')
    message = Messaging::SendingMessage.new(:body => 'message')
    group.mark(message)
    
    MessageGroup.processing(to_receiving_message(message)) do
      group.mark(Messaging::SendingMessage.new(:body => 'new message'))
    end
    assert_false group.done?
  end
  
  def test_should_be_destroyed_after_processing_all_group_messages
    group = MessageGroup.create!(:project_id => 1, :action => 'action')
    message = Messaging::SendingMessage.new(:body => 'message')
    group.mark(message)
    MessageGroup.processing(to_receiving_message(message))
    assert_nil MessageGroup.find_by_group_id(group.group_id)
  end
  
  def test_should_return_message_processing_after_processing_message_finished
    group = MessageGroup.create!(:project_id => 1, :action => 'action')
    message = Messaging::SendingMessage.new(:body => 'message')
    group.mark(message)
    receiving_message = to_receiving_message(message)
    assert_equal receiving_message, MessageGroup.processing(receiving_message)
  end
  
  def test_shoul_pass_message_for_processing_message_block
    group = MessageGroup.create!(:project_id => 1, :action => 'action')
    message = Messaging::SendingMessage.new(:body => 'message')
    group.mark(message)
    receiving_message = to_receiving_message(message)
    processing_message = nil
    MessageGroup.processing(receiving_message) do |message|
      processing_message = message
    end
    assert_equal receiving_message, processing_message
  end
  
  def test_should_be_destroy_after_activated_when_no_message_is_marked
    group = MessageGroup.create!(:project_id => 1, :action => 'action')
    group.activate
    assert_nil MessageGroup.find_by_group_id(group.group_id)
  end
  
  def test_active_group_should_return_group_itself
    group = MessageGroup.create!(:project_id => 1, :action => 'action')
    active_group = nil
    result = group.activate
    assert_equal group, result
  end
  
  def test_should_just_call_block_when_processing_message_not_in_a_group
    called_block = false
    message = to_receiving_message(Messaging::SendingMessage.new(:body => 'message'))
    MessageGroup.processing(message) do
      called_block = true
    end
    assert called_block
  end
  
  def test_should_be_eql_when_group_id_of_group_is_eql
    assert_equal MessageGroup.new("id"), MessageGroup.new("id")
  end

  def to_receiving_message(message)
    ReceivingMessageStub.new(message)
  end

  class ReceivingMessageStub
    def initialize(sending_message)
      @sending_message = sending_message
    end
    def property(key)
      @sending_message.property(key)
    end
  end
end
