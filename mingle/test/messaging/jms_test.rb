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

# Tags: messaging
class JmsTest < ActiveSupport::TestCase
  include MessagingTestHelper
  does_not_work_without_jruby

  def setup
    start_a_broker(File.join(Rails.root, 'test', 'data', 'non_auth_activemq.xml'))
    $fail_amq_connection = false
  end

  def teardown
    $jms_broker_config = nil
    $fail_amq_connection = false
  end

  class Messaging::Adapters::JMS::JMSConnection
    attr_reader :connection_attempts
    alias_method :orig_initialize_connection, :initialize_connection

    # monkey patch to keep track of connection attempts
    def initialize_connection
      @connection_attempts ||= 0
      @connection_attempts += 1
      orig_initialize_connection
    end
  end

  class org::apache::activemq::ActiveMQConnection
    alias_method :orig_create_session, :create_session

    def create_session(*args)
      if $fail_amq_connection
        $fail_amq_connection = false
        raise "Simulating connection inactive failure"
      end
      orig_create_session(*args)
    end
  end

  def test_session_creation_should_retry_if_connection_is_inactive
    $jms_broker_config = {
        "uri" => "vm://localhost"
    }

    $fail_amq_connection = true

    cxn = Messaging::Adapters::JMS::JMSConnection.new($jms_broker_config)
    assert_equal 1, cxn.connection_attempts

    cxn.create_session
    assert_equal 2, cxn.connection_attempts
  end

  def test_should_be_able_to_setup_with_non_username_and_password
    $jms_broker_config = {
        'uri' => 'vm://localhost?broker.persistent=false&jms.useAsyncSend=false'
    }
    send_message TEST_QUEUE, [Messaging::SendingMessage.new({:message => 'hello modo'})]

    assert_equal 'hello modo', receive_from_queue[:message]
  end

  def test_should_be_able_to_setup_with_empty_username_and_password
    $jms_broker_config = {
        'username' => '',
        'password' => '',
        'uri' => 'vm://localhost?broker.persistent=false&jms.useAsyncSend=false'
    }

    send_message TEST_QUEUE, [Messaging::SendingMessage.new({:message => 'hello modo'})]
    assert_message_in_queue(:message => 'hello modo')
  end

  def test_messaging
    send_message(TEST_QUEUE, [Messaging::SendingMessage.new({:message => 'message text'})])
    receive_message(TEST_QUEUE) do |message|
      assert_equal('message text', message[:message])
    end
    assert_receive_nil_from_queue
  end

  def test_send_and_recieve_messages_with_message_properties
    send_message(TEST_QUEUE, [Messaging::SendingMessage.new({:message => 'message text'}, {'message_property_key' => 'message_property_value'})])
    receive_message(TEST_QUEUE) do |message|
      assert_equal 'message_property_value', message.property('message_property_key')
    end
  end

  def test_receive_message_should_be_wrapped_in_transaction
    send_message(TEST_QUEUE, [Messaging::SendingMessage.new({:message => 'this message should be processed in transaction'})])
    assert_raise RuntimeError do
      receive_message(TEST_QUEUE) do |message|
        assert message
        raise 'Raising an exception to simulate something going wrong'
      end
    end

    assert_message_in_queue(:message => 'this message should be processed in transaction')
  end

  def test_receive_and_process_multiple_messages_should_be_wrapped_in_different_transaction
    send_message(TEST_QUEUE, [Messaging::SendingMessage.new({:message => 'this message should be processed in transaction 1'})])
    send_message(TEST_QUEUE, [Messaging::SendingMessage.new({:message => 'this message should be processed in transaction 2'})])
    assert_raise RuntimeError do
      receive_message(TEST_QUEUE, :batch_size => 2) do |message|
        if message[:message] =~ /transaction 2/
          raise 'Raising an exception to simulate something going wrong in transaction 2'
        end
      end
    end

    assert_equal 1, queue_size(TEST_QUEUE)
    assert_message_in_queue(:message => 'this message should be processed in transaction 2')
  end

  def test_should_get_browse_messages_by_queue_name
    send_message(TEST_QUEUE, [Messaging::SendingMessage.new(:message => 'this is a message')])
    send_message("another.queue", [Messaging::SendingMessage.new(:message => 'this is another message')])
    expected_messages = [{:message => 'this is a message'}]
    assert_equal expected_messages, browse_messages(TEST_QUEUE).collect(&:body_hash)
  end

  def test_browse_message_with_selector_should_only_return_the_message_that_matched
    messages = [Messaging::SendingMessage.new({:message => 'this is a message'}, {:my_property => "hello"}), Messaging::SendingMessage.new({:message => 'another_message'}, {:another_property => "world"})]
    send_message(TEST_QUEUE, messages)
    assert_messages_equal [messages.first], browse_messages(TEST_QUEUE, "my_property = 'hello'")
  end

  def test_queue_size
    assert_equal 0, queue_size("does.not.exist")
    assert_equal 0, queue_size(TEST_QUEUE)

    message = Messaging::SendingMessage.new({:message => 'this is a message'})
    send_message(TEST_QUEUE, [message])
    assert_equal 1, queue_size(TEST_QUEUE)
  end

end
