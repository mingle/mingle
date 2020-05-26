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


class FakeAttachmentUploader < AttachmentUploader
  attr_reader :storage_url, :file_name, :file_size
end

class MurmurDataTest < ActiveSupport::TestCase
  def test_scrubbed_murmur_text_should_remove_inline_image_tags_with_plain_text
    murmur_data = MurmurData.new({:murmur_text => 'This is a murmur reply with inline image [image: Inline image 1] and another [image: Inline image 2]'})

    assert_equal 'This is a murmur reply with inline image and another', murmur_data.scrubbed_murmur_text.squish
  end

  def test_scrubbed_murmur_text_should_remove_inline_image_tags_with_special_characters_other_than_square_brackets
    murmur_data = MurmurData.new({:murmur_text => 'This is a murmur reply with inline image [image: ImageNameWith $p3c!@| (chara)ters] and another [image: Inline image 1]'})

    assert_equal 'This is a murmur reply with inline image and another', murmur_data.scrubbed_murmur_text.squish
  end

  def test_scrubbed_murmur_text_should_remove_content_id_tags
    murmur_data = MurmurData.new({:murmur_text => 'This is a murmur reply with inline image [cid: some-very-big-content-id] and another [cid: some-very-big-content-id]'})

    assert_equal 'This is a murmur reply with inline image and another', murmur_data.scrubbed_murmur_text.squish
  end

  def test_scrubbed_murmur_text_should_remove_inline_image_and_content_id_tags
    murmur_data = MurmurData.new({:murmur_text => 'This is a murmur reply with inline image [image: some inline image] and another [cid: some-very-big-content-id]'})

    assert_equal 'This is a murmur reply with inline image and another', murmur_data.scrubbed_murmur_text.squish
  end

  def test_should_create_uploaders_when_response_contains_attachments
    attachment_storage_url = 'https://si.api.mailgun.net/v3/domains/your-domain/messages/message-id/attachments/attachment-id'
    file_name = 'some_file.txt'
    MurmurData.setup_attachment_uploader(FakeAttachmentUploader)
    file_size = 308
    response = {
        'stripped-text' => '',
        'message-headers' => [],
        'attachments' => [
            {
                'url' => attachment_storage_url,
                'name' => file_name,
                'content-type' => 'text/plain',
                'size' => file_size
            }
        ]
    }

    murmur_data = create_murmur_data_from(response)
    assert_equal 1, murmur_data.attachment_uploaders.count
    assert_equal attachment_storage_url, murmur_data.attachment_uploaders[0].storage_url
    assert_equal file_name, murmur_data.attachment_uploaders[0].file_name
    assert_equal file_size, murmur_data.attachment_uploaders[0].file_size
  end


  def test_should_extract_email_client_info_from_response_when_user_agent_present
    user_agent_string = 'Custom User Agent'
    response = {
        'stripped-text' => '',
        'message-headers' => [
            ['hello', 'world'],
            ['User-agent', user_agent_string],
            ['foo', 'bar'],
            ['X-Mailer', 'Blah blah']
        ]
    }

    murmur_data = create_murmur_data_from(response)

    assert_include user_agent_string, murmur_data.email_client_info.split(MurmurData::CLIENT_INFO_SEPARATOR)
  end

  def test_should_extract_email_client_info_from_response_when_x_mailer_present
    x_mailer_string = 'Custom X Mailer'
    response = {
        'stripped-text' => '',
        'message-headers' => [
            ['hello', 'world'],
            ['X-Mailer', x_mailer_string],
            ['abcd', 'xyz'],
        ]
    }

    murmur_data = create_murmur_data_from(response)

    assert_include x_mailer_string, murmur_data.email_client_info.split(MurmurData::CLIENT_INFO_SEPARATOR)
  end

  def test_should_extract_email_client_info_from_response_when_mime_version_contains_alphabets
    mime_version_string = '1.0 (Mac OSX Mail 9.3 \(3124\)'
    response = {
        'stripped-text' => '',
        'message-headers' => [
            ['foo', 'bar'],
            ['Mime-Version', mime_version_string]
        ]
    }

    murmur_data = create_murmur_data_from(response)

    assert_include mime_version_string, murmur_data.email_client_info.split(MurmurData::CLIENT_INFO_SEPARATOR)
  end

  def test_extract_email_client_info_should_ignore_mime_version_when_it_does_not_contain_alphabets
    response = {
        'stripped-text' => '',
        'message-headers' => [
            ['foo','bar'],
            ['Mime-Version', '1.0']
        ]
    }

    murmur_data = create_murmur_data_from(response)

    assert_not_include '1.0', murmur_data.email_client_info.split(MurmurData::CLIENT_INFO_SEPARATOR)
  end

  def test_should_extract_email_client_info_from_response_without_repetition_when_client_is_gmail
    response = {
        'stripped-text' => '',
        'message-headers' => [
            ['X-Gm-irrelevant', 'irrelevant value'],
            ['X-Google-irrelevant2', 'irrelevant value2']
        ]
    }

    murmur_data = create_murmur_data_from(response)

    assert_equal 'Google Web Mail', murmur_data.email_client_info
  end

  def test_should_extract_email_client_info_from_response_without_repetition_when_client_is_ymail
    response = {
        'stripped-text' => '',
        'message-headers' => [
            ['X-yahoo-irrelevant', 'irrelevant value'],
            ['X-ym-irrelevant', 'irrelevant value2']
        ]
    }

    murmur_data = create_murmur_data_from(response)

    assert_equal 'Yahoo Web Mail', murmur_data.email_client_info
  end

  def test_should_extract_email_client_info_from_response_without_repetition_when_client_is_msowa
    response = {
        'stripped-text' => '',
        'message-headers' => [
            ['X-ms-irrelevant', 'irrelevant value'],
            ['X-microsoft-irrelevant', 'irrelevant value2']
        ]
    }

    murmur_data = create_murmur_data_from(response)

    assert_equal 'Microsoft Web Mail', murmur_data.email_client_info
  end

  def test_should_extract_email_client_info_when_all_info_present
    user_agent_string = 'User agent string'
    x_mailer_string = 'X Mailer String'
    mime_version_string = '1.0 mime version string'
    response = {
        'stripped-text' => '',
        'message-headers' => [
            ['User-agent', user_agent_string],
            ['x-mAileR', x_mailer_string],
            ['miME-veRSiOn', mime_version_string],
            ['X-ms-irrelevant', 'irrelevant value'],
            ['X-yahoo-irrelevant', 'irrelevant value'],
            ['X-micrOSoft-irrelevant', 'irrelevant value2'],
            ['X-gooGle-irrelevant', 'irrelevant value3']
        ]
    }

    murmur_data = create_murmur_data_from(response)
    client_info_parts = murmur_data.email_client_info.split(MurmurData::CLIENT_INFO_SEPARATOR)
    [user_agent_string, x_mailer_string, mime_version_string, 'Google Web Mail', 'Yahoo Web Mail', 'Microsoft Web Mail'].each do |part|
      assert_include part, client_info_parts
    end
  end

  def test_extract_email_client_info_should_return_unknown_when_no_info_found
    response = {
        'stripped-text' => '',
        'message-headers' => [
            ['foo', 'bar'],
            ['Mime-Version', '1.0']
        ]
    }

    murmur_data = create_murmur_data_from(response)

    assert_equal 'Unknown', murmur_data.email_client_info
  end

  def test_should_remove_mobile_signatures
    sent_from_signatures = [' Sent from my iPhone ', 'Sent from android', 'Sent from iphone', 'Sent from my blackberry',
                            ' Sent on the move   ', 'Sent on move']
    sent_from_signatures.each do |sent_from_signature|
      murmur_data = MurmurData.new({:murmur_text => "This is a murmur reply with a sent from signature.\n#{sent_from_signature}\n"})

      assert_equal 'This is a murmur reply with a sent from signature.', murmur_data.scrubbed_murmur_text
    end
  end

  def test_should_remove_mobile_signatures_when_murmur_text_is_nil
      murmur_data = MurmurData.new({:murmur_text => ""})
      assert_equal '', murmur_data.scrubbed_murmur_text
  end

  def test_should_not_remove_mobile_signature_when_not_at_the_end_of_message
    murmur_text_with_inline_signature = "This is a murmur reply with a sent from signature.\n Sent from my iPhone \n Hello yo"
    murmur_data = MurmurData.new({:murmur_text => murmur_text_with_inline_signature})

    assert_equal murmur_text_with_inline_signature, murmur_data.scrubbed_murmur_text
  end

  private
  def create_murmur_data_from(response)
    message = Mailgun::Message.new({:timestamp => Time.now.to_f})
    response['attachments'] ||= []
    MurmurData.create_from(response, message)
  end
end
