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

class FirebaseRetentionPolicy
  AGE_THRESHOLD = 1 # in weeks
  MURMUR_TIMESTAMP_PUBLISHED='fbPublishedAt'

  class << self

    def current
      format(current_week)
    end

    def next
      format(next_week)
    end

    def keep_until
      format(keep_until_week)
    end

    def current_week
      Time.now.utc.to_date.beginning_of_week # always a monday
    end

    def next_week
      current_week + (AGE_THRESHOLD * 7)
    end

    def keep_until_week
      current_week - (AGE_THRESHOLD * 7)
    end

    def format(date)
      date.strftime("%Y-%m-%d")
    end

    def apply
      client = FirebaseClient.new(
        MingleConfiguration.firebase_app_url,
        MingleConfiguration.firebase_secret
      )

      apply_live_events(client)
      apply_murmur_email_replies(client)
    end

    def apply_live_events(client)
      top_level = FirebaseKeys::KEYS[:live_events]
      threshold_date = keep_until_week

      (client.get(top_level, :shallow => true).parsed_response || {}).keys.each do |week_slice|
        if Time.utc(*(week_slice.split("-").map(&:to_i))).to_date < threshold_date
          delete_firebase_key(client, top_level, week_slice)
        end
      end

      # publish the current week so listeners can validate
      client.set(FirebaseKeys.current_week_key, current)
    end

    def apply_murmur_email_replies(client)
      murmur_top_level_key = FirebaseKeys::KEYS[:murmur_email_replies]
      threshold_time = (Time.now.utc - threshold_days_for_murmur_email_replies.to_i.days).to_i * 1000

      (client.get(murmur_top_level_key).parsed_response || {}).each do |murmur_key, murmur_value|
        unless "last_processed_event_details".include?(murmur_key)
          murmur_timestamp = murmur_value.first[1][MURMUR_TIMESTAMP_PUBLISHED]
          if murmur_timestamp < threshold_time
            delete_firebase_key(client, murmur_top_level_key, murmur_key)
          end
        end
      end
    end

    def threshold_days_for_murmur_email_replies
      MingleConfiguration.murmur_email_replies_firebase_threshold_in_days || "90"
    end

    private
    def delete_firebase_key(client, top_level_key, key_to_delete)
      path_to_delete = [top_level_key, key_to_delete].join('/')
      Kernel.logger.info "Deleting #{path_to_delete} from Firebase..."
      client.delete(path_to_delete)
      Kernel.logger.info "Removed data at #{path_to_delete} from Firebase"
    end

  end
end
