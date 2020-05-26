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

class MessagingMailboxTest < ActiveSupport::TestCase
  include Messaging::Base

  def setup
    Messaging.enable
    Messaging::Mailbox.sender = Sender.new
  end

  def teardown
    Messaging::Mailbox.sender = Messaging::Gateway.instance
    Messaging.disable
  end

  def test_should_send_out_message_directly_by_default
    send_message('indexing_card', [create_message('should not be sent out directly')])
    assert_equal 1, Messaging::Mailbox.sender.messages.size
  end

  def test_should_filter_empty_messages
    Messaging::Mailbox.transaction do
      send_message('indexing_card', [nil, nil])
      send_message('indexing_card', [])
      send_message('indexing_card', [nil])
    end
    send_message('indexing_card', [nil])
    assert_nil sender.messages
  end

  def test_deliver_mails
    send_message('indexing_card', [create_message('hello')])
    assert_equal(['indexing_card', [create_message('hello')], {}], sender.messages.first)
  end

  def test_deliver_mails_in_transaction
    Messaging::Mailbox.transaction do
      send_message('q', [create_message('hello')])
      send_message('q', [create_message('hello 2')])
      send_message('q2', [create_message('hello 3')])
      assert_nil(Messaging::Mailbox.sender.messages)
    end
    expected = [
      ['q', [create_message('hello'), create_message('hello 2')], {}],
      ['q2', [create_message('hello 3')], {}]
    ]
    assert_equal(expected.sort, Messaging::Mailbox.sender.messages.sort)
  end

  def test_no_message_cached_after_committed_mail_box_transaction
    send_message('q', [create_message('hello1')])
    Messaging::Mailbox.transaction do
      send_message('q', [create_message('hello2')])
    end
    send_message('q', [create_message('hello3')])
    Messaging::Mailbox.transaction do
      send_message('q', [create_message('hello4')])
    end
    assert_equal(4, Messaging::Mailbox.sender.messages.size)
  end

  def test_should_rollback_when_there_is_error_in_transaction
    assert_raise RuntimeError do
      Messaging::Mailbox.transaction do
        send_message('q', [create_message('hello')])
        raise 'something bad happened'
      end
    end
    assert_nil sender.messages
  end

  def test_should_deliver_duplicate_messages_in_transaction
    # for perf issue, we don't want uniq messages anymore.
    Messaging::Mailbox.transaction do
      send_message('world', [create_message('hello')])
      send_message('world', [create_message('hello')])
    end
    assert_equal [['world', [create_message('hello'), create_message('hello')], {}]], sender.messages
  end

  def test_send_an_array_messages
    send_message('world', [create_message('hello'), create_message('hello2')])
    assert_equal [['world', [create_message('hello'), create_message('hello2')], {}]], sender.messages
  end

  def test_send_messages_with_delay_seconds_option_based_on_message_delay_seconds_rate_configuration
    MingleConfiguration.with_message_delay_seconds_rate_overridden_to(10) do
      Messaging::Mailbox.transaction do
        send_message('hello', [create_message('world')])
        send_message('world', [create_message('hello')])
      end
      hello = ['hello', [create_message('world')], {:delay_seconds => 20}]
      world = ['world', [create_message('hello')], {:delay_seconds => 10}]
      assert_equal [hello, world], sender.messages
    end
  end

  class Sender
    attr_accessor :messages
    def send_message(queue_name, messages=[], options={})
      (@messages ||= []) << [queue_name, messages, options]
    end
  end

  private
  def create_message(msg)
    OpenStruct.new :message => msg, :properties => {}
  end
end
