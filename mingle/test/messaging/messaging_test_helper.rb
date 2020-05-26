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

MingleConfiguration.multitenant_messaging = 'true'

module MessagingTestHelper

  class SampleConsumer
    attr_reader :sent
    def initialize
      @sent = []
    end

    def send(*args)
      @sent << args
    end
  end

  def self.included(base)
    base.setup :setup_with_messaging
    base.teardown :teardown_with_messaging
  end

  def run_all_search_message_processors
    FullTextSearch.run_once
    ElasticSearch.refresh_indexes
  end

  def start_a_broker(config)
    stop_messaging
    $__broker__ = org.apache.activemq.broker.BrokerFactory.createBroker("xbean:" + config, true)
  end

  def stop_messaging
    Messaging.reset_connection
    if Rails.env.acceptance_test?
      Net::HTTP.get(URI.parse("http://localhost:4001/_class_method_call?class=Messaging&method=reset_connection"))
    end
    $__broker__.stop if $__broker__
    $__broker__ = nil
  rescue Exception => e
    # puts e.message
    # puts e.backtrace.join("\n")
    # any error during stop messaging get ignored
  end

  def onMessage(message)
    message = message.text if message.respond_to?(:text)
    @received_messages << deserialize(@listening_topic_format, message)
  end

  include Messaging::Endpoint
  include Messaging::Group::GatewayExt
  include Messaging::Enablement

  TEST_QUEUE = 'mingle.test_events' unless defined?(TEST_QUEUE)

  def route(options)
    Messaging::Redirects.add(options)
  end

  def wire_tap(options)
    Messaging::Wiretaps.add(options)
  end

  def setup_with_messaging
    Messaging.enable
    start_a_broker(File.join(Rails.root, 'test', 'data', 'test_activemq.xml'))
  end

  def teardown_with_messaging
    stop_messaging
    Messaging::Redirects.each do |from, targets|
      targets.delete(TEST_QUEUE)
    end

    Messaging::Wiretaps.each do |from, targets|
      targets.delete(TEST_QUEUE)
    end

    Messaging.disable
  end

  def assert_message_in_queue(message, assert_failed_message=nil)
    message = message.body_hash if message.respond_to? :body_hash
    assert_equal message, receive_from_queue.body_hash, assert_failed_message
  end

  def assert_message_in_queue_contains(items)
    message_hash = receive_from_queue.body_hash
    items.each do |item_key, values|
      message_items = message_hash[item_key]
      values.each do |key, value|
        assert message_items.has_key?(key)
        assert message_items.has_value?(value)
      end
    end

  end

  def assert_message_not_in_queue(message, assert_failed_message=nil)
    message = message.body_hash if message.respond_to? :body_hash
    assert_equal message, receive_from_queue.body_hash, assert_failed_message
  end

  def assert_receive_nil_from_queue(queue = TEST_QUEUE)
    pull_from_queue(queue) do |mess|
      assert_nil mess, "Message(#{mess}) should not be in the queue #{queue}"
    end
  end

  def assert_messages_equal(expecteds, actuals)
    assert_equal expecteds.collect(&:body_hash), actuals.collect(&:body_hash)
  end

  def get_all_messages_in_queue(queue = TEST_QUEUE)
    messages = []

    continue = true
    while continue
      continue = false
      pull_from_queue(queue) do |message|
        continue = true
        messages << message
      end
    end
    messages
  end
  alias_method :clear_message_queue, :get_all_messages_in_queue

  def all_messages_from_queue(queue = TEST_QUEUE)
    all_messages = []
    while message = pull_from_queue(queue)
      all_messages << message
    end
    all_messages
  end

  def receive_from_queue
    mess = pull_from_queue
    assert_not_nil mess, "Could not get message from queue #{TEST_QUEUE}"
    mess
  end

  def pull_from_queue(queue = TEST_QUEUE)
    message = nil
    receive_message_without_message_group(queue) do |m|
      message = m
      if block_given?
        yield(m)
      else
        m
      end
    end
    message
  end

  def bridge_messages(from_queue, to_queue, &block)
    messages = get_all_messages_in_queue(from_queue)
    if block_given?
      messages.each { |m| yield m }
    end
    messages = messages.collect { |m| m.to_sending_message }
    send_message(to_queue, messages)
  end

  def message_count(queue)
    messages = get_all_messages_in_queue(queue)
    messages_to_send = messages.collect { |m| m.to_sending_message }
    if self.respond_to?(:send_message_without_multicasting)
      send_message_without_multicasting(queue, messages_to_send)
    else
      send_message(queue, messages_to_send)
    end
    messages.size
  end


end
