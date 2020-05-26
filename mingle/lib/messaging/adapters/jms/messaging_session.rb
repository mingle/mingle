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
      class MessagingSession
        def initialize(jms_connection, session=nil)
          @connection = jms_connection
          @session = session || @connection.create_session
          @producers = {}
          @consumers = {}
        end

        def close
          @producers.values.each(&:close)
          @consumers.values.each(&:close)
          @session.close
        end

        def rollback_if_need
          @session.rollback if @session.getTransacted
        end

        def commit_if_need
          @session.commit if @session.getTransacted
        end

        def producer(queue_name)
          @producers[queue_name] ||= create_producer(queue_name)
        end

        def consumer(queue_name)
          @consumers[queue_name] ||= create_consumer(queue_name)
        end

        def create_text_message(text)
          @session.create_text_message(text)
        end

        def create_browser(queue_name, message_selector=nil)
          @session.create_browser(create_queue(queue_name), message_selector)
        end

        def log_if_block_exceeds(threshold, log_message, &block)
          start = Clock.now
          block.call.tap do
            if (difference = Clock.now - start) > threshold
              ActiveRecord::Base.logger.info(log_message.gsub(%r/@.+@/, difference.round(3).to_s))
            end
          end
        end

        def create_queue(queue_name)
          @session.create_queue(queue_name)
        end

        def create_producer(queue_name)
          log_if_block_exceeds(0.25.second, "Warning: create_producer took @duration@ secs.") do
            @session.create_producer(create_queue(queue_name))
          end
        end

        def create_consumer(queue_name)
          log_if_block_exceeds(0.25.second, "Warning: create_consumer took @duration@ secs.") do
            @session.create_consumer(create_queue(queue_name))
          end
        end

      end
    end
  end
end
