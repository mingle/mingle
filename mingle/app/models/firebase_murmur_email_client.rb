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

class FirebaseMurmurEmailClient

  def initialize(fb_client)
    @fb_client = fb_client
  end

  def push_murmur_data(murmur_data)
    murmur_data = murmur_data.merge(:tenant => MingleConfiguration.app_namespace)
    retain(FirebaseKeys.murmur_email_replies(murmur_data[:reply_to_email]), murmur_data)
  end

  def fetch_murmur_data(reply_to_email)
    response = fetch(FirebaseKeys.murmur_email_replies(reply_to_email))
    response.nil? ? nil : response.values.first
  end

  def set_last_processed_event_details(event_details)
    response = @fb_client.set(FirebaseKeys.murmur_last_processed_event_details, {'id' => event_details.id, 'timestamp' => event_details.timestamp }.to_json)
    if response.success?
      Rails.logger.debug { "Firebase response [#{response.url}]: #{response.inspect}" }
    else
      error = "Cannot push to firebase, request url: #{response.url} response code: #{response.code}, response body: #{response.body}"
      Rails.logger.error(error)
      raise error
    end
  end

  def fetch_last_processed_event_details
    response = fetch(FirebaseKeys.murmur_last_processed_event_details).parsed_response
    details = response.nil? ? { :timestamp => 3.days.ago.to_f } : JSON.parse(response)
    details.with_indifferent_access
  end

  private

  def fetch(key)
    response = @fb_client.get(key)
    if response.success?
      Rails.logger.debug { "Firebase response : #{response.inspect}" }
    else
      error = "Cannot get from firebase. response code: #{response.code}, response body: #{response.body}"
      Rails.logger.error(error)
      raise error
    end
    response
  end

  def retain(key, value)
    response = @fb_client.push(key, value)
    if response.success?
      Rails.logger.debug { "Firebase response [#{response.url}]: #{response.inspect}" }
    else
      error = "Cannot push to firebase, request url: #{response.url} response code: #{response.code}, response body: #{response.body}"
      Rails.logger.error(error)
      raise error
    end
  end
end
