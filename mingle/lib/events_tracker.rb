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

# an asynchronize event tracker send event to mixpanel
class EventsTracker < Messaging::Processor
  include Messaging::Base

  QUEUE = "mingle.mixpanel_events"

  def initialize(consumer=nil)
    @consumer = consumer || Mixpanel::Consumer.new
  end

  def track(user_id, event_name, event_attributes={})
    tracker.track(user_id, event_name, event_attributes)
  end

  def on_message(message)
    @consumer.send(message[:type], message[:msg])
  end

  private

  def tracker
    return Null.instance if MingleConfiguration.metrics_api_key.blank?
    Mixpanel::Tracker.new(MingleConfiguration.metrics_api_key) do |type, msg|
      send_message(QUEUE, [Messaging::SendingMessage.new({:type => type.to_s, :msg => msg})])
    end
  end
end
