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

class SqsIntegrationTest < ActiveSupport::TestCase
  include Messaging
  def setup
    Messaging.enable
    Adapters.adapter_name = 'sqs'
    @prefix = "testqueue".uniquify
    Messaging.middleware << Messaging::RetryOnError.new(:match => /UnknownOperationException/, :tries => 5)
    MingleConfiguration.multitenant_messaging = 'true'
  end

  def teardown
    MingleConfiguration.multitenant_messaging = nil
    Messaging.disable
    AWS::SQS.new.queues.with_prefix('testqueue').each do |q|
      q.delete rescue nil
    end
  end

  class Sender
    include Messaging::Base
  end

  def test_we_can_change_to_delayed_queue
    queue_name = "#{@prefix}.queue.name"
    Sender.new.send_message(queue_name, messages)
    sleep 5
    received_messages = []
    Gateway.instance.receive_message(queue_name, :batch_size => 2) do |msg|
      received_messages << msg
    end
    assert_received_messages(received_messages)

    MingleConfiguration.with_message_delay_seconds_rate_overridden_to(10) do
      Sender.new.send_message(queue_name, messages)
    end
    sleep 5
    received_messages = []
    Gateway.instance.receive_message(queue_name) do |msg|
      received_messages << msg
    end
    assert received_messages.empty?
  end

  def test_should_return_queue_size
    gateway = Gateway.instance
    queue_name = "#{@prefix}.queue.name"
    messages = [SendingMessage.new({'projectId' => 5})]
    gateway.send_message(queue_name, messages)
    assert_equal 1, gateway.queue_size(queue_name)
  end

  def test_send_blank_message
    gateway = Gateway.instance
    queue_name = "#{@prefix}.queue.name"
    messages = [SendingMessage.new({})]
    gateway.send_message(queue_name, messages)

    Gateway.instance.receive_message(queue_name) do |m|
      assert_equal({}, m.body_hash)
    end
  end

  def test_should_process_camelcase_attributes
    queue_name = "#{@prefix}.queue.name"
    messages = [SendingMessage.new({'projectId' => 5})]
    Gateway.instance.send_message(queue_name, messages)

    Gateway.instance.receive_message(queue_name) do |m|
      assert_equal 5, m.property('projectId')
    end
  end

  def test_should_be_able_to_set_batch_size_more_than_10
    queue_name = "#{@prefix}.queue.name"
    messages = [SendingMessage.new({'projectId' => 5})]
    Gateway.instance.send_message(queue_name, messages * 11)
    loop do
      break if Gateway.instance.queue_size(queue_name) >= 11
      sleep 1
    end
    messages = []
    Gateway.instance.receive_message(queue_name, :batch_size => 11) do |m|
      messages << m
    end
    assert_equal 11, messages.size
  end

  def test_message_group
    queue_name = "#{@prefix}.queue.name"
    group = MessageGroup.create!(:project_id => 1, :action => 'abcd')
    group.activate do
      Sender.new.send_message(queue_name, messages[0..0])
    end
    sleep 5
    Gateway.instance.receive_message(queue_name, :batch_size => 1) {}
    assert_nil MessageGroup.find_by_action(1, 'abcd')
  end

  def test_send_message
    queue_name = "#{@prefix}.queue.name"
    Gateway.instance.send_message(queue_name, messages)
    sleep 5
    received_messages = []
    Gateway.instance.receive_message(queue_name, :batch_size => 2) do |msg|
      received_messages << msg
    end
    assert_received_messages(received_messages)
  end

  def test_queues_delete_message_on_receive
    queue_name = "#{@prefix}.queue.name"
    Adapters::SQS.queues_deleting_message_on_receive = [queue_name]
    Gateway.instance.send_message(queue_name, messages)
    sleep 5
    received_messages = []
    Gateway.instance.receive_message(queue_name, :batch_size => 1) do |msg|
      raise 'error'
    end rescue nil
    Gateway.instance.receive_message(queue_name, :batch_size => 1) do |msg|
      raise 'error'
    end rescue nil
    Gateway.instance.receive_message(queue_name, :batch_size => 2) do |msg|
      received_messages << msg
    end

    assert_equal 0, received_messages.size
  end

  def assert_received_messages(received_messages)
    assert_equal received_messages.size, 2
    assert_equal(received_messages[0].to_h, {:project_id => 5})
    assert_equal(received_messages[1].to_h, {:text => 'text'})
    assert_equal(received_messages[1].to_h, received_messages[1].body_hash)
  end

  def messages
    [SendingMessage.new({:project_id => 5}), SendingMessage.new({:text => 'text'})]
  end
end
