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

class Messaging::ErrorHandlingMiddlewareTest < ActiveSupport::TestCase
  include Messaging

  def setup
    @endpoint = InMemoryEndpoint.new
    @errors = []
  end

  def test_should_catch_error_and_process_error_by_given_handler
    @middleware = ErrorHandling.new(@endpoint, self)
    @middleware.send_message('queue', messages)
    @middleware.receive_message('queue') { |msg| raise "#{msg[:text]} error" }

    assert_equal 1, @errors.size
    e, context = @errors.first
    assert_equal('hello error', e.message)
    assert_equal({:queue => 'queue'}, context)
  end

  def test_no_error_handler
    @middleware = ErrorHandling.new(@endpoint, nil)
    assert_nil @middleware.handler

    @middleware.send_message('queue', messages)
    @middleware.receive_message('queue') { |msg| raise "#{msg[:text]} error" }
    # no error raised even there is no handler specified
  end

  def test_should_reraise_errors_if_error_matches
    @middleware = ErrorHandling.new(@endpoint, self, [FooError])
    @middleware.send_message('queue', messages)

    assert_raises(FooError) do
      @middleware.receive_message('queue') { |msg| raise FooError.new("reraise me!") }
    end
    assert_equal 1, @errors.size

    @errors = []
    assert_nothing_raised do
      @middleware.receive_message("queue") { |msg| raise "don't raise me" }
    end
    assert_equal 1, @errors.size
  end

  def notify(error, context)
    @errors << [error, context]
  end

  def messages
    [SendingMessage.new({:text => 'hello'})]
  end

  class FooError < StandardError; end
end
