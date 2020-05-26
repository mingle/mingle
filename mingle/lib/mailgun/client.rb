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

class MailgunClient
  include RetryOnNetworkError, AttachmentsHelper

  class DownloadError < StandardError
  end

  def initialize(api_key, domain)
    @api_key = api_key
    @domain = domain
    MurmurData.setup_attachment_uploader(AttachmentUploader)
  end

  def fetch_stored_messages(batch_size=100, options={})
    with_retry do |retries, exception|
      url = "https://api.mailgun.net/v3/#{@domain}/events"
      query = {:limit => batch_size, :event => 'stored', :ascending => 'yes'}.merge(options)
      log_failed_try_on_exception(url, query, "GET", retries, exception)
      response = HTTParty.get url, {:basic_auth => auth, :query => query}
      create_messages(response)
    end
  end

  def fetch_email(message)
    with_retry do |retries, exception|
      log_failed_try_on_exception(message.storage_url, {}, "GET", retries, exception)
      response = HTTParty.get message.storage_url, {:basic_auth => auth}
      return nil unless response.code == 200
      MurmurData.create_from(response, message)
    end
  end

  def send_email(options)
    HTTParty.post "https://api.mailgun.net/v3/#{@domain}/messages", :body => options, :basic_auth => auth
  end

  def download(url)
    response = HTTParty.get(url, {:basic_auth => auth})
    raise DownloadError.new("Failed to fetch #{url} from Mailgun.") if response.code >= 400
    response.body
  end

  private
  def auth
    {:username => 'api', :password => @api_key}
  end

  def create_messages(response)
    messages = []
    return messages if response["items"].nil?
    response["items"].each do |item|
      messages << Mailgun::Message.create_from(item, @domain)
    end
    messages
  end

end
