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

class MurmurAutoReplyNotification

  ERRORS = {
      :invalid_operation => 'Your message has not been delivered as the resource you requested does not exist or you do not have access rights to that resource.',
      :global_murmur_attachment_error => 'The attachment could not be uploaded as you were replying to a project level murmur. Attachments can only be forwarded through email replies to card specific murmurs.',
      :empty_murmur_error => 'The murmur could not be posted as no text was entered',
      :attachments_on_empty_murmur => 'The murmur could not be posted as no text was entered. Attachments sent, if any, were added to the card'
  }

  # Switching recipient and from address as this is a reply email
  def send_auto_reply(recipient, from, subject, error_type)
    return nil if ERRORS[error_type].nil? || MingleConfiguration.installer?
    MurmurAutoReplyNotifier.deliver_notify(from, recipient, subject, ERRORS[error_type])
  end

  def send_auto_reply_for_message(message, error_type)
    send_auto_reply(message.recipient, message.from, message.subject, error_type)
  end
end
