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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class MiddlewareTest < ActiveSupport::TestCase
  include Messaging

  class CountMiddleware
    cattr_accessor :count
    def initialize(endpoint)
      @endpoint = endpoint
      @@count = 0
    end
    def send_message(queue, messages, opts={})
      @@count += messages.size
      @endpoint.send_message(queue, messages)
    end

    def receive_message(queue, options={}, &block)
      @endpoint.receive_message(queue, options) do |msg|
        block.call(msg)
        @@count -= 1
      end
    end
  end

  class RecordMiddleware
    cattr_accessor :queues
    def initialize(endpoint)
      @@queues = {}
    end
    def send_message(queue, messages, opts={})
      @@queues[queue] = messages
    end

    def receive_message(queue, options={}, &block)
      @@queues[queue].each do |msg|
        block.call(msg)
      end
    end
  end

  class NoopMiddleware
  end

  class MiddlewareNeedConfig < InMemoryEndpoint
    attr_reader :endpoint, :args

    def initialize(endpoint, *args)
      @endpoint = endpoint
      @args = args
    end
  end

  def setup
    @middlewares = Messaging.middleware.dup
    Messaging.middleware.clear
  end

  def teardown
    Messaging.middleware.clear
    Messaging.middleware.concat(@middlewares)
  end

  def test_middleware_loops_through
    Messaging.middleware << CountMiddleware
    Messaging.middleware << RecordMiddleware
    Gateway.instance.send_message('queue', ['message'])
    assert_equal 1, CountMiddleware.count
    assert_equal 1, RecordMiddleware.queues.size
    assert_equal ['message'], RecordMiddleware.queues['queue']
  end

  def test_insert_before_middleware
    assert_raise RuntimeError do
      Messaging.middleware.insert_before(NoopMiddleware, CountMiddleware)
    end

    Messaging.middleware << CountMiddleware
    Messaging.middleware.insert_before(CountMiddleware, RecordMiddleware)

    assert_equal [RecordMiddleware, CountMiddleware], Messaging.middleware
  end

  def test_insert_after_middleware
    assert_raise RuntimeError do
      Messaging.middleware.insert_after(NoopMiddleware, CountMiddleware)
    end

    Messaging.middleware << CountMiddleware
    Messaging.middleware << RecordMiddleware
    Messaging.middleware.insert_after(CountMiddleware, NoopMiddleware)

    assert_equal [CountMiddleware, NoopMiddleware, RecordMiddleware], Messaging.middleware
  end

  def test_add_middleware_with_arguments
    Messaging.middleware << [MiddlewareNeedConfig, 1, 2, 3]
    assert_equal [MiddlewareNeedConfig, 1, 2, 3], Messaging.middleware.last
    endpoint = Messaging.middleware.build(InMemoryEndpoint.new)
    assert_equal InMemoryEndpoint, endpoint.endpoint.class
    assert_equal [1, 2, 3], endpoint.args
  end
end
