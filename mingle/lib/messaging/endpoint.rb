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
  module Endpoint
    [:reset_connection,
     :browse_messages,
     :browse_messages_with_session].each do |m|
      class_eval <<-RUBY
        def #{m}(*args, &block)
          args[0] = namespaced_queue(args[0]) if args.size > 0
          Messaging::Adapters.endpoint.send('#{m}', *args, &block)
        end
      RUBY
      end

      def send_message(queue_name, *args, &block)
        Messaging::Adapters.endpoint.send_message(namespaced_queue(queue_name), *args, &block)
      end

      def receive_message(queue_name, *args, &block)
        Messaging::Adapters.endpoint.receive_message(namespaced_queue(queue_name), *args, &block)
      end

      def queue_size(queue_name)
        Messaging::Adapters.endpoint.queue_size(namespaced_queue(queue_name))
      end

      module_function
      def namespaced_queue(original_name)
        if MingleConfiguration.multitenant_messaging?
          prefix(prefix(original_name, MingleConfiguration.queue_name_prefix), "multi")
        else
          legacy_queue(original_name)
        end
      end

      def legacy_queue(original_name)
        prefix(prefix(original_name, MingleConfiguration.app_namespace), MingleConfiguration.queue_name_prefix)
      end

      def prefix(value, prefix)
        prefix.blank? ? value : "#{prefix}.#{value}"
      end
  end
end
