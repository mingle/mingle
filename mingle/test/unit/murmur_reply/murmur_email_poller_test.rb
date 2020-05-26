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
require 'webmock'

class MurmurEmailPollerTest < ActiveSupport::TestCase

  class FakeInvalidUserMessageFilter
    def filter?(_, data)
      User.find_by_id(data['user_id']).nil?
    end
  end

  def setup
    WebMock.reset!
    WebMock.disable_net_connect!
    setup_mingle_configs
    @from_time = Time.now.to_f
    @domain = MingleConfiguration.mailgun_domain
    @from_address = "test@#{@domain}"
    @to_address = "test-receive@#{@domain}"
    firebase_client = FirebaseClient.new(MingleConfiguration.firebase_app_url, MingleConfiguration.firebase_secret)
    @fb_murmur_email_client = FirebaseMurmurEmailClient.new(firebase_client)
  end

  def teardown
    MingleConfiguration.firebase_app_url = nil
    MingleConfiguration.firebase_secret = nil
    MingleConfiguration.mailgun_api_key = nil
    MingleConfiguration.mailgun_domain = nil
    MingleConfiguration.app_namespace = nil
    WebMock.allow_net_connect!
  end

  def setup_mingle_configs
    MingleConfiguration.firebase_app_url = 'https://mingle-test.firebaseio.com'
    MingleConfiguration.firebase_secret = 'cLhtT3Rr3Oxj4JXSheSy3uzgWEngZN7V6PNMo2qX'
    MingleConfiguration.mailgun_api_key = 'key-a4f7abc901c56c8316f15a116ccd1ded'
    MingleConfiguration.mailgun_domain = 'sandboxc1bc5bf660ed4f1298b88f61bd5e71f3.mailgun.org'
    MingleConfiguration.app_namespace = 'testing_murmur_poller'
  end


  def test_should_return_murmur_data_for_valid_message
    three_days_ago = 3.days.ago.to_f
    assertion_message = ''
    stub_fb_murmur_email_client(:get, {'timestamp' => three_days_ago, 'id' => 'murmurReplyEvent1'}.to_json.inspect)
    stub_fb_murmur_email_client(:put, {'timestamp' => @from_time + 1.second.to_f, 'id' => 'murmurReplyEvent2'}.to_json.inspect)
    stub_fb_murmur_email_client(:get, {'values' => {'tenant' => 'testing_murmur_poller', 'murmur_id' => 12, 'user_id' => 234}}.to_json, '/test-receive')

    data = create_message_data(@from_address, 'First test email', [@to_address], (@from_time + 1.second).to_f)
    stub_mailgun_message_store(data, three_days_ago)

    data = {'stripped-text' => 'First Murmur Email Poller Test', 'message-headers' => [['mime-version', '1.0']]}
    stub_mailgun_email_store(data)

    MurmurEmailPoller.new([]).on_email(1) do |filtered_message|
      assertion_message = assert_with_message(12, filtered_message.murmur_id) +
          assert_with_message('testing_murmur_poller', filtered_message.tenant) +
          assert_with_message(234, filtered_message.user_id) +
          assert_with_message('First Murmur Email Poller Test', filtered_message.scrubbed_murmur_text)
    end
    assert assertion_message.blank?, assertion_message
  end

  def test_should_ignore_messages_with_invalid_user_id
    three_days_ago = 3.days.ago.to_f
    stub_fb_murmur_email_client(:get, {'timestamp' => three_days_ago, 'id' => 'murmurReplyEvent1'}.to_json.inspect)
    stub_fb_murmur_email_client(:put, {'timestamp' => @from_time + 1.second.to_f, 'id' => 'murmurReplyEvent2'}.to_json.inspect)
    stub_fb_murmur_email_client(:get, {'values' => {'tenant' => 'testing_murmur_poller', 'murmur_id' => 12, 'user_id' => 234}}.to_json, '/test-receive')

    data = create_message_data(@from_address, 'First test email', [@to_address], (@from_time + 1.second).to_f)
    stub_mailgun_message_store(data, three_days_ago)

    data = {'stripped-text' => 'First Murmur Email Poller Test', 'message-headers' => [['mime-version', '1.0']]}
    stub_mailgun_email_store(data)

    block_never_called = true
    MurmurEmailPoller.new([FakeInvalidUserMessageFilter.new()]).on_email(1) do |_|
      block_never_called = false
    end
    assert block_never_called
  end

  def test_should_filter_message_if_email_does_not_exist
    three_days_ago = 3.days.ago.to_f
    stub_fb_murmur_email_client(:get, {'timestamp' => three_days_ago, 'id' => 'murmurReplyEvent1'}.to_json.inspect)
    stub_fb_murmur_email_client(:put, {'timestamp' => @from_time + 1.second.to_f, 'id' => 'murmurReplyEvent2'}.to_json.inspect)
    stub_fb_murmur_email_client(:get, {'values' => {'tenant' => 'testing_murmur_poller', 'murmur_id' => 123, 'user_id' => 2334}}.to_json, '/test-receive')
    data = create_message_data(@from_address, 'First test email', [@to_address], (@from_time + 1.second).to_f)
    stub_mailgun_message_store(data, three_days_ago)
    stub_mailgun_email_store({}, 404)

    block_never_called = true
    MurmurEmailPoller.new([]).on_email(1) do |_|
      block_never_called = false
    end
    assert block_never_called
  end

  def test_should_return_nil_when_recipient_data_not_found_on_firebase
    three_days_ago = 3.days.ago.to_f
    stub_fb_murmur_email_client(:get, {'timestamp' => three_days_ago, 'id' => 'murmurReplyEvent1'}.to_json.inspect)
    stub_fb_murmur_email_client(:put, {'timestamp' => @from_time + 1.second.to_f, 'id' => 'murmurReplyEvent2'}.to_json.inspect)

    data = create_message_data(@from_address, 'First test email', [@to_address], (@from_time + 1.second).to_f)
    stub_mailgun_message_store(data, three_days_ago)

    stub_fb_murmur_email_client(:get, '', '/test-receive')
    block_never_called = true

    MurmurEmailPoller.new([]).on_email(1) do |_|
      block_never_called = false
    end
    assert block_never_called
  end

  def test_should_send_auto_reply_when_user_replies_to_invalid_murmur_email
    three_days_ago = 3.days.ago.to_f
    stub_fb_murmur_email_client(:get, {'timestamp' => three_days_ago, 'id' => 'murmurReplyEvent1'}.to_json.inspect)
    stub_fb_murmur_email_client(:put, {'timestamp' => @from_time + 1.second.to_f, 'id' => 'murmurReplyEvent2'}.to_json.inspect)

    subject = 'First test email'
    data = create_message_data(@from_address, subject, [@to_address], (@from_time + 1.second).to_f)
    stub_mailgun_message_store(data, three_days_ago)

    stub_fb_murmur_email_client(:get, '', '/test-receive')
    block_never_called = true

    auto_reply_notification = mock
    auto_reply_notification.expects(:send_auto_reply_for_message).with do |message, error_type|
      assert_equal :invalid_operation, error_type
      assert_equal @from_address, message.from.address
      assert_equal @to_address, message.recipient.address
      assert_equal subject, message.subject
      true
    end

    MurmurEmailPoller.new([], auto_reply_notification).on_email(1) do |_|
      block_never_called = false
    end

    assert block_never_called
  end

  def test_should_not_process_last_event_again
    last_processed_event_id = 'murmurReplyEvent1'
    stub_fb_murmur_email_client(:get, {'timestamp' => @from_time + 1.second.to_f, 'id' => last_processed_event_id}.to_json.inspect)

    data = create_message_data(@from_address, 'First test email', [@to_address], (@from_time + 1.second).to_f, last_processed_event_id)
    stub_mailgun_message_store(data, (@from_time + 1.second.to_f))

    block_never_called = true
    MurmurEmailPoller.new([]).on_email(1) do |_|
      block_never_called = false
    end

    assert block_never_called
    assert_not_requested :put, fb_murmur_email_url
    assert_not_requested :get, mailgun_email_url
  end

  def test_should_retry_processing_failed_message_configured_number_of_times
    last_processed_event_id = 'murmurReplyEvent1'
    new_message_timestamp = @from_time + 2.second.to_f
    new_event_id = 'murmurReplyEvent2'
    retry_times = 2
    actual_try_count=0

    stub_fb_murmur_email_client(:get, {'timestamp' => @from_time, 'id' => last_processed_event_id}.to_json.inspect)
    stub_fb_murmur_email_client(:put, {'timestamp' => new_message_timestamp, 'id' => new_event_id}.to_json.inspect)
    stub_fb_murmur_email_client(:get, {'values' => {'tenant' => 'testing_murmur_poller', 'murmur_id' => 123, 'user_id' => 2334}}.to_json, '/test-receive')

    data = create_message_data(@from_address, 'First test email', [@to_address], new_message_timestamp, 'mummurReplyEvent2')
    stub_mailgun_message_store(data, @from_time)
    email_data = {'stripped-text' => 'Successful Murmur Email Poller Test', 'message-headers' => [['mime-version', '1.0']]}
    stub_mailgun_email_store(email_data)
    failing_filter = mock
    failing_filter.expects(:filter?).returns(false).times(retry_times)
    filters = [failing_filter]
    MingleConfiguration.with_failed_murmur_reply_retries_overridden_to(retry_times.to_s) do
      MurmurEmailPoller.new(filters).on_email(1) do |_|
        actual_try_count += 1
        raise Exception.new("blah")
      end
    end

    assert_equal retry_times, actual_try_count
  end

  def test_should_switch_tenant_when_in_multitenancy_mode
    holiday_name = 'holiday name'
    Multitenancy.add_tenant('testing-murmur-poller', 'database_username' => 'tenant_schema', 'mingle.config.holiday_name' => holiday_name)
    MingleConfiguration.overridden_to(multitenancy_mode: true) do
      three_days_ago = 3.days.ago.to_f
      assertion_message = ''
      stub_fb_murmur_email_client(:get, {'timestamp' => three_days_ago, 'id' => 'murmurReplyEvent1'}.to_json.inspect)
      stub_fb_murmur_email_client(:put, {'timestamp' => @from_time + 1.second.to_f, 'id' => 'murmurReplyEvent2'}.to_json.inspect)
      stub_fb_murmur_email_client(:get, {'values' => {'tenant' => 'testing-murmur-poller', 'murmur_id' => 12, 'user_id' => 234}}.to_json, '/test-receive')

      data = create_message_data(@from_address, 'First test email', [@to_address], (@from_time + 1.second).to_f)
      stub_mailgun_message_store(data, three_days_ago)

      data = {'stripped-text' => 'First Murmur Email Poller Test', 'message-headers' => [%w(mime-version 1.0)]}
      stub_mailgun_email_store(data)

      MurmurEmailPoller.new([]).on_email(1) do |filtered_message|
        assertion_message = assert_with_message(holiday_name, MingleConfiguration.holiday_name) +
          assert_with_message(12 , filtered_message.murmur_id) +
          assert_with_message('testing-murmur-poller' , filtered_message.tenant) +
          assert_with_message(234 , filtered_message.user_id) +
          assert_with_message('First Murmur Email Poller Test' , filtered_message.scrubbed_murmur_text)
      end
      assert assertion_message.blank?, assertion_message
    end
  end

  private

  def assert_with_message(expected, actual)
    assert_equal expected, actual
    return ''
  rescue Test::Unit::AssertionFailedError => e
    e.message + "\n"
  end

  def stub_fb_murmur_email_client_for_nil_response(fb_path)
    fb_secret = MingleConfiguration.firebase_secret
    url = "#{MingleConfiguration.firebase_app_url}/murmur_email_replies#{fb_path || '/last_email_fetch_timestamp'}.json?auth=#{fb_secret}"
    stub_request(:get, url).
        with(:headers => {'Content-Type' => 'application/json'}).
        to_return(:status => 503, :body => "", :headers => {})
  end

  def stub_fb_murmur_email_client(method, body, fb_path=nil, content_type=nil)
    expected_return_value = {:status => 200, :body => body, :headers => {'Content-Type' => content_type ||'application/json'}}
    stub_request(method, fb_murmur_email_url(fb_path)).
        with(:headers => {'Content-Type' => 'application/json'}).
        to_return(expected_return_value)
  end

  def fb_murmur_email_url(fb_path =nil, fb_secret = MingleConfiguration.firebase_secret)
    "#{MingleConfiguration.firebase_app_url}/murmur_email_replies#{fb_path || '/last_processed_event_details'}.json?auth=#{fb_secret}"
  end

  def stub_mailgun_email_store(data, response_code=200)
    data['attachments'] ||= []
    stub_request(:get, mailgun_email_url).
        to_return(:status => response_code, :body => data.to_json, :headers => {'Content-Type' => 'application/json'})
  end

  def mailgun_email_url
    "https://api:#{MingleConfiguration.mailgun_api_key}@api.fakemailgun.com/events/firstemail"
  end

  def stub_mailgun_message_store(data, begin_with, content_type=nil)
    api_key = MingleConfiguration.mailgun_api_key
    url = mailgun_message_store_url(api_key, begin_with)
    stub_request(:get, url).to_return(:status => 200, :body => data.to_json, :headers => {'Content-Type' => content_type || 'application/json'})
  end

  def mailgun_message_store_url(api_key, begin_with)
    "https://api:#{api_key}@api.mailgun.net/v3/#{@domain}/events?ascending=yes&begin=#{begin_with}&event=stored&limit=1"
  end

  def create_message_data(from_address, subject, recipients, timestamp, id = 'murmurReplyEvent')
    {
        'items' => [{
                        'message' => {
                            'headers' => {
                                'from' => from_address,
                                'subject' => subject
                            },
                            'recipients' => recipients
                        },
                        'storage' => {
                            'url' => 'https://api.fakemailgun.com/events/firstemail'
                        },
                        'timestamp' => timestamp,
                        'subject' => subject,
                        'id' => id
                    }]
    }
  end

end

