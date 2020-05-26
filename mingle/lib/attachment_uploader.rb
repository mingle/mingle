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

class AttachmentUploader
  include AWSHelper

  class FileSizeTooBig < StandardError
    def initialize(size)
      @size = size
    end

    def message
      @message ||= "File is too big (#{(@size/(1024*10.24)).round/100}MiB). Max filesize: #{MingleConfiguration.attachment_size_limit}MiB."
    end
  end

  def initialize(storage_url, file_name, file_size)
    @storage_url = storage_url
    @file_name = file_name
    @file_size = file_size
  end

  def execute
    raise FileSizeTooBig.new(@file_size) if @file_size > (MingleConfiguration.attachment_size_limit.to_i * 1024 * 1024)
    download_from_mailgun
    upload_to_s3
  end

  private
  def download_from_mailgun
    Rails.logger.debug "Fetching attachment #{@file_name} from mailgun #{@storage_url}."

    mailgun_client = MailgunClient.new(MingleConfiguration.mailgun_api_key, MingleConfiguration.mailgun_domain)
    @file = Tempfile.new('attachment_to_be_uploaded')
    @file.write mailgun_client.download(@storage_url)
    @file.close

    Rails.logger.info "Successfully fetched attachment #{@file_name} from mailgun #{@storage_url}."
  end

  def upload_to_s3
    return unless MingleConfiguration.use_s3_attachments_storage?

    Rails.logger.debug "Uploading #{@file_name}."

    random_id = SecureRandom.hex(2) + '-' + SecureRandom.hex(2)
    key = File.join(random_s3_key, random_id, @file_name)
    s3 = s3_upload_file(MingleConfiguration.attachments_bucket_name, key, @file.path)

    Rails.logger.info "Uploaded #{@file_name} successfully."
    key
  end
end
