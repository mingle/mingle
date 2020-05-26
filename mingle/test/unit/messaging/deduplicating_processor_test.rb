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

class Messaging::DeduplicatingProcessorTest < ActiveSupport::TestCase
  class SimpleProcessor < Messaging::DeduplicatingProcessor
    attr_reader :processed_messages

    def initialize
      @processed_messages = []
    end

    def do_process_message(message)
      @processed_messages << message
    end
  end

  class Message < Hash
    def body_hash
      self
    end
  end

  def test_should_only_call_do_process_message_once_when_there_are_duplicated_messages
    processor = SimpleProcessor.new

    2.times do
      processor.on_message(Messaging::SendingMessage.new({:text => 'hello'}))
    end

    assert_equal 1, processor.processed_messages.size
  end


  def test_should_ignore_id_in_the_message_body_when_processing_duplicated_messages
    processor = SimpleProcessor.new

    processor.on_message(Messaging::SendingMessage.new({:text => 'hello', :id => 1}))
    processor.on_message(Messaging::SendingMessage.new({:text => 'hello', :id => 2}))


    assert_equal 1, processor.processed_messages.size
  end

end
