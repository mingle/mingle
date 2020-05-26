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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')
require 'webmock'

class AttachmentUploaderTest < ActiveSupport::TestCase
  def setup
    WebMock.reset!
    WebMock.disable_net_connect!
    @attachment_storage_url = 'https://%ssi.api.mailgun.net/v3/domains/domain-name/messages/message-id/attachments/0'
    @file_name = 'attach_me.ext'
    @file_size = 308
    @file_size_limit_in_mb = 100
    @api_key = 'some-api-key'
  end

  def teardown
    WebMock.allow_net_connect!
  end

  def attachment_url(with_auth = false)
    data = with_auth ? "api:#{@api_key}@" : ''
    @attachment_storage_url % [data]
  end

  def test_execute_should_download_attachment_from_mailgun
    body = 'Contents of attachment as raw ASCII bytes'
    stub_mailgun_email_store(attachment_url(true), body)
    attachment_uploader = AttachmentUploader.new(attachment_url, @file_name, @file_size)
    attachment_uploader.expects(:upload_to_s3)

    MingleConfiguration.overridden_to(
        :mailgun_api_key => @api_key,
        :attachment_size_limit => @file_size_limit_in_mb
    ) do
      attachment_uploader.execute

      file = attachment_uploader.instance_variable_get(:@file)
      assert File.basename(file.path).starts_with?('attachment_to_be_uploaded')
      file.open
      assert_equal body, file.read
      file.close
    end
  end


  def test_execute_should_raise_exception_when_fetching_mailgun_attachment_fails
    body = 'Contents of attachment as raw ASCII bytes'
    stub_mailgun_email_store(attachment_url(true), body, 401)
    attachment_uploader = AttachmentUploader.new(attachment_url, @file_name, @file_size)

    MingleConfiguration.overridden_to(
        :mailgun_api_key => @api_key,
        :attachment_size_limit => @file_size_limit_in_mb
    ) do
      e = assert_raises(MailgunClient::DownloadError) do
        attachment_uploader.execute
      end
      assert_equal "Failed to fetch #{attachment_url} from Mailgun.", e.message
    end
  end

  def test_execute_should_upload_to_s3_when_download_succeeds
    attachment_uploader = AttachmentUploader.new(attachment_url, @file_name, @file_size)
    attachments_bucket = 'attachments-bucket-name'
    s3_access_key = 'some-access-key'

    body = 'Contents of attachment as raw ASCII bytes'
    stub_mailgun_email_store(attachment_url(true), body, 200)

    bucket = mock
    AWS::S3.any_instance.expects(:buckets).returns({attachments_bucket => bucket})

    s3_key_object = mock
    bucket.expects(:objects).returns(s3_key_object)

    key_object = mock
    s3_key_object.expects(:[]).with(){|file_path| File.basename(file_path) == @file_name }.returns(key_object)

    key_object.expects(:write).with(){|args| File.basename(args[:file]).starts_with?('attachment_to_be_uploaded')}

    MingleConfiguration.overridden_to(:s3_upload_access_key_id => s3_access_key,
                                      :s3_upload_secret_key => @api_key,
                                      :attachments_bucket_name => attachments_bucket,
                                      :mailgun_api_key => @api_key,
                                      :attachment_size_limit => @file_size_limit_in_mb

    ) do
      attachment_uploader.execute
    end
  end

  def test_should_raise_exception_when_attachment_is_bigger_than_configured_size_limit
    overlimit_file_size_in_mb = @file_size_limit_in_mb + 1
    MingleConfiguration.overridden_to(:attachment_size_limit => @file_size_limit_in_mb) do
      attachment_uploader = AttachmentUploader.new(attachment_url, @file_name, overlimit_file_size_in_mb*1024*1024)
      error = assert_raises(AttachmentUploader::FileSizeTooBig)  do
        attachment_uploader.execute
      end
      assert_equal "File is too big (#{overlimit_file_size_in_mb}MiB). Max filesize: #{@file_size_limit_in_mb}MiB.", error.message
    end
  end

  private
  def stub_mailgun_email_store(url, body, response_code = 200)
    headers={
        'server'=>['nginx'],
        'date'=>['Mon, 17 Oct 2016 11:04:03 GMT'],
        'content-type'=>['application/ext'],
        'transfer-encoding'=>['chunked'],
        'connection'=>['close'],
        'content-disposition'=>['attachment']
    }
    stub_request(:get, url).
        to_return(status: response_code, body: body, headers: headers)
  end
end
