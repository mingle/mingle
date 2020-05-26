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

class FirebaseUnreadMurmurNotification

  def initialize(fb_client)
    @fb_client = fb_client
  end

  def deliver_notify(users, project, murmur)
    users.each do |user|
      next if user == murmur.author
      card_number = (murmur.is_a?(CardCommentMurmur) && murmur.origin_id)? murmur.origin.number : nil
      response = @fb_client.push(FirebaseKeys.unread_murmurs_key(user, project),
                                { 'author' => {:name => murmur.author.name}.to_json, 'card_number' => card_number, 'created_at' => murmur.created_at, 'id' => murmur.id,'text' => murmur.murmur })
      if response.success?
        Rails.logger.debug { "Firebase response [#{response.url}]: #{response.inspect}" }
      else
        error = "Cannot push to firebase, request url: #{response.url} response code: #{response.code}, response body: #{response.body}"
        Rails.logger.error(error)
        raise error unless Rails.env.production?
      end
    end
  end
end
