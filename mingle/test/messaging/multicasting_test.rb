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

class MulticastingTest < ActiveSupport::TestCase
  include MessagingTestHelper
  include Messaging::Multicasting

  def test_wiretap_should_send_the_message_to_both_source_and_destination_queues
    q1 = "testings.queue.1"
    q2 = TEST_QUEUE

    wire_tap(:from => q1, :to => q2)
    send_message(q1, [Messaging::SendingMessage.new({:message => 'hello modo'})])
    assert_equal 1, message_count(q1)
    assert_equal 1, message_count(q2)
  end

  def test_route_should_redirect_the_message_to_the_destination_queues
    q1 = "testings.queue.1"
    q2 = TEST_QUEUE

    route(:from => q1, :to => q2)
    send_message(q1, [Messaging::SendingMessage.new({:message => 'hello modo'})])
    assert_equal 0, message_count(q1)
    assert_equal 1, message_count(q2)
  end


end
