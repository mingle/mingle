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
  class Processor
    include Base

    def self.route(options)
      Redirects.add(options)
    end

    def self.wire_tap(options)
      Wiretaps.add(options)
    end

    def self.run_once(options={})
      processor = options[:processor] || self.new
      queue = processor.class::QUEUE
      Kernel.logger.debug "run once #{queue}: #{options.inspect}"

      bulk_receive(queue, options, processor)
    end

    def self.bulk_receive(queue, options, processor)
      Messaging::Gateway.instance.receive_message(queue, options) do |message|
        process(message, processor)
      end
    end

    def self.process_with_error_handling(message, processor)
      process(message, processor)
    end

    def self.process(message, processor)
      Kernel.logger.debug { "receive_message from #{processor.class::QUEUE}: #{message.inspect}" }
      User.with_first_admin { processor.on_message(message) }
    end

    def self.queue_processors
      @@processors ||= build_queue_processors
    end

    def self.build_queue_processors
      {}.tap do |processors|
        @@subclasses.each do |processor|
          if defined?(processor::QUEUE)
            processors[processor::QUEUE] = processor
          end
        end
      end
    end

    def self.inherited(child) #:nodoc:
      @@subclasses ||= []
      @@subclasses << child
      super
    end
  end

  class MessageSortingProcessor < Processor
    NO_TENANT = :"$$"

    def self.bulk_receive(queue, options, processor)
      sort_key = options.delete(:sort_by) || :id
      cache = Hash.new {|h, k| h[k] = []}

      Messaging::Gateway.instance.receive_message(queue, options) do |message|
        tenant_name = message[:tenant] || NO_TENANT
        cache[tenant_name] << message
      end

      until(cache.empty?) do
        tenant_name, messages = cache.shift
        messages = messages.sort {|a,b| a[sort_key] <=> b[sort_key]}

        if tenant_name != NO_TENANT && tenant = Multitenancy.find_tenant(tenant_name)
          tenant.activate do
            messages.each do |message|
              process(message, processor)
            end
          end
        else
          messages.each do |message|
            process(message, processor)
          end
        end
      end
    end
  end

  class UserAwareProcessor < Processor
    def self.process(message, processor)
      User.find(message[:user_id]).with_current do
        if message[:project_id]
          Project.find(message[:project_id]).with_active_project { processor.on_message(message) }
        else
          processor.on_message(message)
        end
      end
    end
  end

  class UserAwareWithLegacyMessageHandlingProcessor < Processor
    def self.process(message, processor)
      if message[:user_id]
        User.find(message[:user_id]).with_current do
          processor.on_message(message)
        end
      else
        User.with_first_admin do
          processor.on_message(message)
        end
      end
    end
  end

  class DeduplicatingProcessor < Processor
    def on_message(message)
      message_identifier = idenity_hash(message)
      message_identifier.merge!(:tenant => message[:tenant]) if message[:tenant]

      return if processed_ids.include?(message_identifier)
      processed_ids << message_identifier
      do_process_message(message)
    end

    def do_process_message(message)
      raise "to be implemented by subclasses"
    end

    # subclasses may override this to generate domain-specific message ids
    def idenity_hash(message)
      default_identity_hash(message)
    end

    def processed_ids
      @processed_ids ||= Set.new
    end

    protected

    def default_identity_hash(message)
      message.body_hash.reject{|k,v| k.to_s == 'id'}
    end
  end
end
