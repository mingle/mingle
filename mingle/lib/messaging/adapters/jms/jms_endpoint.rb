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

module Messaging
  module Adapters
    module JMS
      class JmsEndpoint
        include Singleton

        def with_session(&block)
          @connection ||= JMSConnection.new(JMS.load_config)
          session = MessagingSession.new(@connection)
          yield(session).tap do |ret|
            session.commit_if_need
          end
        rescue Exception => e
          session.rollback_if_need rescue nil
          raise e
        ensure
          session.close if session
        end

        def reset_connection
          @connection.close if @connection
          @connection = nil
        end

        def queue_size(queue_name)
          browse_messages(queue_name).size
        end

        def send_message(queue_name, messages, options={})
          messages.group_into_blocks_of_size(MESSAGE_PUBLISHING_BATCH_SIZE).each do |batch_of_messages|
            with_session do |session|
              batch_of_messages.each do |message|
                send_single_message(session, queue_name, message)
              end
            end
          end
        end

        def receive_message(queue_name, options={})
          options[:batch_size] ||= 1
          options[:timeout] ||= Rails.env.test? ? 500 : -1
          count = 0
          with_session do |session|
            consumer = session.consumer(queue_name)
            count = 0
            while count < options[:batch_size] && message = pop_message(session, consumer, queue_name, options)
              count += 1
              m = ReceivingMessage.new(message)
              yield m
              session.commit_if_need
            end
            options[:batch_size] -= count
          end
        end

        def browse_messages(queue_name, message_selector=nil)
          with_session do |session|
            browse_messages_with_session(session, queue_name, message_selector)
          end
        end

        def browse_messages_with_session(session, queue_name, message_selector=nil)
          browser = session.create_browser(queue_name, message_selector)
          result = []
          e = browser.enumeration
          while e.has_more_elements
            result << ReceivingMessage.new(e.next_element)
          end
          result
        end

        private

        def pop_message(session, consumer, queue_name, options)
          session.log_if_block_exceeds(0.2.seconds, "Warning: receive_message on queue: #{queue_name} took @duration@ secs.") do
            options[:timeout] > 0 ? consumer.receive(options[:timeout]) : consumer.receiveNoWait
          end
        end

        def send_single_message(session, queue_name, message)
          producer = session.producer(queue_name)
          jms_message = session.create_text_message(message.body_xml)
          message.properties.each do |key, value|
            jms_message.set_string_property(key.to_s, value.to_s)
          end
          producer.send(jms_message)
        end
      end

      JmsEndpoint.instance # initialize instance, avoid thread issue
    end
  end
end
