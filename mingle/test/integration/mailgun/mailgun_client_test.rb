# encoding: utf-8

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


require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class MailgunClientTest < Test::Unit::TestCase

  def setup
    @domain = 'sandboxc1bc5bf660ed4f1298b88f61bd5e71f3.mailgun.org'
    @client = MailgunClient.new('key-a4f7abc901c56c8316f15a116ccd1ded', @domain)
    @from_address = "test@#{@domain}"
    @to_address = "test-receive@#{@domain}" # => this has been authorised on the mailgun test account
  end

  def test_fetch_stored_messages
    from_time = Time.now.to_f
    @client.send_email(:from => @from_address, :to => @to_address, :text =>'First test', :subject => 'First test email')
    @client.send_email(:from => @from_address, :to => @to_address, :text =>'Second test', :subject => 'Second test email')

    messages = nil
    retry_until_condition 5, 2 do
      messages = @client.fetch_stored_messages(5, {:begin => from_time})
      messages.size >= 2
    end
    assert_equal 2, messages.count
    first_message = messages.first
    assert_equal @from_address, first_message.from.address
    assert_equal 'First test email', first_message.subject
    assert_equal @to_address, first_message.recipient.address
    assert_equal @to_address, first_message.recipient.address
    assert first_message.storage_url =~ URI::regexp

    second_message = messages.second
    assert_equal @from_address, second_message.from.address
    assert_equal 'Second test email', second_message.subject
    assert_equal @to_address, second_message.recipient.address
    assert second_message.storage_url =~ URI::regexp
  end

  def test_fetch_stored_email_for_message
    from_time = Time.now.to_f
    @client.send_email(:from => @from_address, :to => @to_address, :text =>'First test', :subject => 'First test email')
    @client.send_email(:from => @from_address, :to => @to_address, :text =>'Second test', :subject => 'Second test email')

    messages = nil
    retry_until_condition 5, 2 do
      messages = @client.fetch_stored_messages(5, {:begin => from_time})
      messages.size >= 2
    end
    assert_equal 2, messages.count
    first_message = messages.first

    email = @client.fetch_email(first_message)
    assert_equal 'First test', email.scrubbed_murmur_text
    assert_equal first_message.timestamp, email.timestamp

    second_message = messages.second
    email = @client.fetch_email(second_message)
    assert_equal 'Second test', email.scrubbed_murmur_text
  end

  def test_fetch_stored_email_for_message_with_special_characters_in_email
    from_time = Time.now.to_f
    funky_email = "Jérémie DERUETTE <djer13@example.com>"
    @client.send_email(:from => funky_email, :to => @to_address, :text =>'First test', :subject => 'First test email')

    messages = nil
    retry_until_condition 5, 2 do
      messages = @client.fetch_stored_messages(5, {:begin => from_time})
      messages.size == 1
    end
    assert_equal 1, messages.count
    first_message = messages.first

    email = @client.fetch_email(first_message)
    assert_equal 'djer13@example.com', first_message.from.address
  end

  def test_fetch_stored_email_when_sent_in_cc
    from_time = Time.now.to_f
    email_body = "CC test - #{from_time}"
    @client.send_email(:from => @from_address, :cc => @to_address, :to => "minglea3@gmail.com", :text => email_body, :subject => 'CC test email')
    messages = nil
    retry_until_condition 5, 2 do
      messages = @client.fetch_stored_messages(5, {:begin => from_time})
      messages.size >= 1
    end
    assert_equal 1, messages.count
    message = messages.first
    assert_equal @from_address, message.from.address
    assert_equal 'CC test email', message.subject
    assert_equal @to_address, message.recipient.address
    assert message.storage_url =~ URI::regexp

    email = @client.fetch_email(message)
    assert_equal email_body, email.scrubbed_murmur_text
  end

  def test_fetch_stored_email_when_sent_in_bcc
    from_time = Time.now.to_f
    email_body = "BCC test - #{from_time}"
    @client.send_email(:from => @from_address, :bcc => @to_address, :to => "minglea3@gmail.com", :text => email_body, :subject => 'BCC test email')
    messages = nil
    retry_until_condition 5, 2 do
      messages = @client.fetch_stored_messages(5, {:begin => from_time})
      messages.size >= 1
    end
    assert_equal 1, messages.count
    message = messages.first
    assert_equal @from_address, message.from.address
    assert_equal 'BCC test email', message.subject
    assert_equal @to_address, message.recipient.address
    assert message.storage_url =~ URI::regexp

    email = @client.fetch_email(message)
    assert_equal email_body, email.scrubbed_murmur_text
  end

  def test_fetch_stored_email_when_email_url_is_invalid_or_expired
    invalid_url = "https://so.api.mailgun.net/v3/domains/#{@domain}/messages/eyJwIjpmYWxzZSwiayI6IjI1NGNkYmNlLTk2N2YtNDBmMy"
    message = Mailgun::Message.new({:storage_url => invalid_url})
    email = @client.fetch_email(message)
    assert_nil email
  end

  def test_download_should_raise_exception_when_response_code_is_error
    invalid_url = "https://so.api.mailgun.net/v3/domains/#{@domain}/messages/eyJwIjpmYWxzZSwiayI6IjI1NGNkYmNlLTk2N2YtNDBmMy/attachments/0"
    e = assert_raises(RuntimeError) do
      @client.download(invalid_url)
    end
    assert_equal "Failed to fetch #{invalid_url} from Mailgun.", e.message
  end
end
