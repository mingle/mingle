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

class EventTrackerTest < ActiveSupport::TestCase
  include MessagingTestHelper

  def setup
    clear_message_queue(EventsTracker::QUEUE)
    @consumer = SampleConsumer.new
    @tracker = EventsTracker.new(@consumer)
  end

  def test_track_event_should_send_to_the_queue
    MingleConfiguration.overridden_to(:metrics_api_key => 'm_key') do
      @tracker.track("foo", "create_card", {"p1" => "v1"})
      EventsTracker.run_once(:processor => @tracker)
      message = @consumer.sent.last
      assert_equal 1, @consumer.sent.size
      assert_equal 'event', message[0]
      event_data = JSON.load(message[1])['data']

      assert_equal 'create_card', event_data['event']
      assert_equal 'foo', event_data['properties']['distinct_id']
      assert_equal 'v1', event_data['properties']['p1']
    end
  end
end
