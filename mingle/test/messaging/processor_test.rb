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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')
require File.expand_path(File.dirname(__FILE__) + '/messaging_test_helper')

# Tags: messaging
class ProcessorTest < ActiveSupport::TestCase
  include MessagingTestHelper
  
  class SampleProcessor < Messaging::Processor
    QUEUE = 'sample_processor_queue'
    cattr_accessor :proc
    def on_message(message); self.class.proc.call end
  end
  
  def teardown
    SampleProcessor.proc = nil
  end
  
  def test_should_remove_messaging_from_queue_when_mingle_cant_handel_it
    # need jruby because messaging is transactional
    requires_jruby do
      SampleProcessor.proc = Proc.new { raise ActiveRecord::StatementInvalid.new }
      Messaging::Gateway.instance.send_message(SampleProcessor::QUEUE, [Messaging::SendingMessage.new({:a => 1})])
      SampleProcessor.run_once rescue nil
      assert_receive_nil_from_queue(SampleProcessor::QUEUE)
    end
  end
  
  def test_should_not_remove_messaging_when_there_are_bad_thing_happen
    # need jruby because messaging is transactional
    requires_jruby do
      SampleProcessor.proc = Proc.new do
        raise Interrupt.new
      end
      Messaging::Gateway.instance.send_message(SampleProcessor::QUEUE, [Messaging::SendingMessage.new({:a => 1})])
      begin
        SampleProcessor.run_once 
      rescue Exception
      end
      assert_equal({:a => 1}, pull_from_queue(SampleProcessor::QUEUE).body_hash)
    end
  end
  
  
end
