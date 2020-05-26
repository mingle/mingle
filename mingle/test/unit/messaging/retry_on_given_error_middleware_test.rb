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

class RetryOnGivenErrorMiddlewareTest < ActiveSupport::TestCase
  include Messaging

  class BlankEndpoint
    def send_message(queue, messages, opts={})
    end

    def receive_message(queue, options={}, &block)
      block.call('msg')
    end
  end

  class UnknownOperationException < StandardError
  end

  def setup
    @blank_endpoint = BlankEndpoint.new
  end

  def test_should_retry_receive_message_when_got_the_error_matched_with_class_name
    middleware = Messaging::RetryOnError.new(:match => /UnknownOperationException/, :tries => 3)
    middleware = middleware.new(@blank_endpoint)
    tried = 0
    middleware.receive_message('queue') do |msg|
      tried += 1
      raise UnknownOperationException.new('error') if tried < 3
    end
    assert_equal 3, tried
  end

  def test_should_retry_receive_message_when_got_the_error_matched_with_message
    middleware = Messaging::RetryOnError.new(:match => /UnknownOperationException/, :tries => 3)
    middleware = middleware.new(@blank_endpoint)
    tried = 0
    middleware.receive_message('queue') do |msg|
      tried += 1
      raise "<UnknownOperationException/>" if tried < 3
    end
    assert_equal 3, tried
  end

  def test_should_raise_error_when_got_the_error_does_not_match_given_class_name
    middleware = Messaging::RetryOnError.new(:match => /UnknownOperationException/, :tries => 3)
    middleware = middleware.new(@blank_endpoint)
    tried = 0
    assert_raise RuntimeError do
      middleware.receive_message('queue') do |msg|
        tried += 1
        raise 'error'
      end
    end
    assert_equal 1, tried
  end

end
