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

module ReplyToMurmurEmailHelper
  def unique_reply_to_email(murmur, user)
    email_domain = TMail::Address.parse(MingleConfiguration.murmur_notification_email_address).domain
    email = "murmur-reply-#{SecureRandomHelper.random_32_char_hex}@#{email_domain}"
    push_to_firebase(murmur, email, user)
    email
  end

  private
  def push_to_firebase(murmur, email, user)
    return if MingleConfiguration.firebase_app_url.blank?
    client = FirebaseMurmurEmailClient.new(FirebaseClient.new(MingleConfiguration.firebase_app_url, MingleConfiguration.firebase_secret))
    client.push_murmur_data(:murmur_id => murmur.id, :reply_to_email => email, :user_id => user.id)
  end
end
