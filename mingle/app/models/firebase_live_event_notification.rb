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

class FirebaseLiveEventNotification

  attr_reader :client

  def initialize(firebase_client)
    @client = firebase_client
  end

  def deliver_notify(project, event)
    payload = event.emit_payload
    current_week_start = FirebaseRetentionPolicy.current

    key = FirebaseKeys.live_events_key(project, current_week_start)
    Rails.logger.debug { "sending payload #{payload.to_json} to key #{key} at #{@client.base_url}" }
    response = client.push(key, payload)

    if response.success?
      Rails.logger.debug { "Firebase response [#{response.url}]: #{response.inspect}" }
    else
      error = "Cannot push to firebase: #{response.url}, resp #{response.code}: #{response.body}; #{payload.to_json}"
      Rails.logger.error(error)
      raise error unless Rails.env.production?
    end

  end
end
