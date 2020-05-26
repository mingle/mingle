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

  class MiddlewareConfig < Array
    def insert_before(existing_middleware, new_middleware)
      existing_index = existing_middleware_index(existing_middleware)
      new_index = existing_index == 0 ? 0 : existing_index - 1
      insert(new_index, new_middleware)
    end

    def insert_after(existing_middleware, new_middleware)
      new_index = existing_middleware_index(existing_middleware) + 1
      insert(new_index, new_middleware)
    end

    def existing_middleware_index(middleware)
      index(middleware).tap do |idx|
        raise "#{middleware} not found in current list of configured middleware" if idx.nil?
      end
    end

    def build(endpoint)
      Messaging.middleware.reverse.inject(endpoint) do |next_m, m|
        case m
        when Array
          klass, *args = m
          klass.new(next_m, *args)
        else
          m.new(next_m)
        end
      end || endpoint
    end
  end

  def middleware
    @middleware ||= MiddlewareConfig.new
  end

  module_function :middleware

  module Middleware
    class WithoutMiddleware
      def initialize(endpoint)
        @endpoint = endpoint
      end
      def send_message(*args)
        @endpoint.send_message_without_middleware(*args)
      end
      def receive_message(*args, &block)
        @endpoint.receive_message_without_middleware(*args, &block)
      end
    end

    def self.included(base)
      base.send(:alias_method_chain, :send_message, :middleware)
      base.send(:alias_method_chain, :receive_message, :middleware)
    end

    def send_message_with_middleware(queue, messages, options={})
      endpoint.send_message(queue, messages, options)
    end

    def receive_message_with_middleware(queue, options={}, &block)
      endpoint.receive_message(queue, options, &block)
    end

    def endpoint
      Messaging.middleware.build(WithoutMiddleware.new(self))
    end
  end
end
