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

class MurmurData
  attr_reader :timestamp, :tenant, :user_id, :murmur_id, :email_client_info, :attachment_uploaders, :from, :recipient, :subject

  CLIENT_INFO_SEPARATOR = '; '
  GMAIL_HEADER_KEY = /x-(gm|google|gmail).*/
  GOOGLE_SERVICE = 'Google Web Mail'
  MICROSOFT_SERVICE = 'Microsoft Web Mail'
  MIME_VERSION_HEADER_KEY = 'mime-version'
  MSOWA_HEADER_KEY = /x-(ms|microsoft|exchange).*/
  UNKNOWN = 'Unknown'
  USER_AGENT_HEADER_KEY = 'user-agent'
  X_MAILER_HEADER_KEY = 'x-mailer'
  YAHOO_SERVICE = 'Yahoo Web Mail'
  YMAIL_HEADER_KEY = /x-(ymail|yahoo).*/

  def initialize(options)
    @murmur_text = options[:murmur_text].strip
    @attachment_uploaders = options[:attachment_uploaders]
    @email_client_info = options[:email_client_info]
    @from = options[:from]
    @recipient = options[:recipient]
    @subject = options[:subject]
    @timestamp = options[:timestamp]
  end

  def self.create_from(response, message)
    options = {
        :murmur_text => response['stripped-text'].trim,
        :attachment_uploaders => prepare_attachment_uploaders(response['attachments']),
        :email_client_info => extract_email_client_info(response['message-headers']),
        :timestamp => message.timestamp,
        :from => message.from,
        :recipient => message.recipient,
        :subject => message.subject
    }
    self.new(options)
  end

  def set_firebase_data(tenant, murmur_id, user_id)
    @tenant = tenant
    @user_id = user_id
    @murmur_id = murmur_id
  end

  def scrubbed_murmur_text
    return @murmur_text if @murmur_text.blank?
    remove_inline_image_tags
    remove_mobile_signatures
  end
  memoize :scrubbed_murmur_text

  private
  def remove_inline_image_tags
    @murmur_text.gsub!(/\[(image|cid):[^\]]+\]/i,'')
  end

  def remove_mobile_signatures
    return @murmur_text if @murmur_text.blank?
    @murmur_text.split("\n").last[/^\s*sent.*(from|on).*(iphone|android|blackberry|move)$/i].nil? ? @murmur_text :
        (@murmur_text = @murmur_text.split("\n")[0..-2].join("\n"))
  end

  class << self
    def setup_attachment_uploader(uploader_klass)
      @uploader_klass  = uploader_klass
    end

    private
    def extract_email_client_info(message_headers)
      client_info = []
      message_headers.each do |header|
        key = header.first.downcase
        value = header.last
        case key
          when USER_AGENT_HEADER_KEY
            client_info << value
          when X_MAILER_HEADER_KEY
            client_info << value
          when MIME_VERSION_HEADER_KEY
            client_info << value if /[a-zA-Z]/ =~ value
          when GMAIL_HEADER_KEY
            client_info << GOOGLE_SERVICE unless client_info.include?(GOOGLE_SERVICE)
          when YMAIL_HEADER_KEY
            client_info << YAHOO_SERVICE unless client_info.include?(YAHOO_SERVICE)
          when MSOWA_HEADER_KEY
            client_info << MICROSOFT_SERVICE unless client_info.include?(MICROSOFT_SERVICE)
        end
      end
      client_info << UNKNOWN unless client_info.any?
      client_info.join(CLIENT_INFO_SEPARATOR)
    end

    def prepare_attachment_uploaders(attachments)
      attachments.map{|attachment| @uploader_klass.new(attachment['url'], attachment['name'], attachment['size'])}
    end
  end

end
