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
    module SQS
      class SqsEndpoint
        include Singleton
        DEFAULT_VISIBILITY_TIMEOUT = 60 * 10 # 10 min

        attr_accessor :queues_deleting_message_on_receive

        def send_message(queue_name, messages, options={})
          q = queue(queue_name)
          Rails.logger.debug("[SqsEndpoint] send #{messages.size} messages to #{queue_name}")
          messages.map(&:full_text).each_slice(10).to_a.each do |msgs|
            retryable(:tries => 3, :sleep => 0.05) do
              args = msgs + [options]
              q.batch_send(*args)
            end
          end
        end

        def receive_message(queue_name, options={}, &block)
          batch_size = options[:batch_size] ||= 1
          if deleting_message_on_receive?(queue_name)
            if batch_size != 1
              Rails.logger.warn("Ignore batch_size #{batch_size}, because #{queue_name} is set as deleting message on receive and must be processed one by one")
            end
            if msg = queue(queue_name).receive_message
              msg.delete
              message_processor(&block).call(msg)
            end
          else
            queue = queue(queue_name)
            loop do
              has_message = false
              queue.receive_messages(:limit => batch_size > 10 ? 10 : batch_size) do |msg|
                # aws may return fewer messages than you requested, so
                # decrease batch_size by counting messages received
                # Message is deleted if the block returns correctly
                batch_size -= 1
                has_message = true
                message_processor(&block).call(msg)
              end
              break if batch_size < 1
              break unless has_message
            end
          end
        rescue AWS::SQS::Errors::ChecksumError => e
          Rails.logger.error(<<-ERROR)
AWS SQS ChecksumError, failed messages:
#{e.failures.join("\n")}
ERROR
          raise e
        end

        def deleting_message_on_receive?(queue_name)
          @qs ||= Array(queues_deleting_message_on_receive).map{|q| Messaging::Endpoint.namespaced_queue(q)}
          @qs.include?(queue_name)
        end

        def queue_size(queue_name)
          queue(queue_name).approximate_number_of_messages
        end

        def poll(queue_name, options, &block)
          queue(queue_name).poll(options, &message_processor(&block))
        end

        def browse_messages(*args)
          raise 'unsupported operation browse_message in sqs'
        end

        def browse_messages_with_session(*args)
          raise 'unsupported operation browse_messages_with_session in sqs'
        end

        def queue(name)
          sanitize_queue_name = sanitize_queue_name(name)
          queues[name] ||= sqs.queues.create(sanitize_queue_name, :visibility_timeout => DEFAULT_VISIBILITY_TIMEOUT)
        rescue => e
          Rails.logger.error("Queue creation error for #{sanitize_queue_name}: #{e.backtrace.join("\n")}")
          raise e
        end

        private
        def queues
          @queues ||= ThreadsafeHash.new
        end

        def sanitize_queue_name(name)
          name.gsub(/[^a-zA-Z0-9\-_]/, '_').shorten(80)
        end
        def message_processor(&block)
          lambda {|msg| block.call(ReceivingMessage.new(msg))}
        end

        def sqs
          AWS::SQS.new(region: 'us-west-1')
        end
      end

      SqsEndpoint.instance
    end
  end
end
