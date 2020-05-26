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

class FirebaseMurmurEmailClientTest < ActiveSupport::TestCase
  def setup
    @fb_client = FirebaseMurmurEmailClient.new(FirebaseClient.new("https://mingle-test.firebaseio.com", "cLhtT3Rr3Oxj4JXSheSy3uzgWEngZN7V6PNMo2qX"))

  end

  def test_should_push_murmur_data
    tenant = 'FirebaseMurmurEmailClientTest_murmur_data'
    MingleConfiguration.overridden_to(:app_namespace => tenant) do
      sender_email = "test_#{Time.now.to_i}@email.com"
      @fb_client.push_murmur_data(:murmur_id =>2, :reply_to_email => sender_email, :user_id => 31)

      murmur_data = @fb_client.fetch_murmur_data(sender_email)
      assert_not_nil murmur_data
      assert_equal tenant, murmur_data['tenant']
      assert_equal 2, murmur_data['murmur_id']
      assert_equal 31, murmur_data['user_id']
    end

  end

  def test_should_return_nil
    sender_email = "test_#{Time.now.to_i}@email.com"

    murmur_data = @fb_client.fetch_murmur_data(sender_email)
    assert_nil murmur_data

  end

  def test_should_set_last_processed_event_details
    timestamp = Time.now.to_f
    expected_details = {:timestamp => timestamp, :id => 'testId1'}
    message = Mailgun::Message.new(expected_details)

    @fb_client.set_last_processed_event_details(message)

    details = @fb_client.fetch_last_processed_event_details
    assert_equal expected_details.stringify_keys, details
  end

  def test_should_default_to_3_days_ago_timestamp_when_no_details_are_found
    Timecop.freeze
    fb_client = FirebaseClient.new('https://mingle-test.firebaseio.com', 'cLhtT3Rr3Oxj4JXSheSy3uzgWEngZN7V6PNMo2qX')
    fb_client.delete(FirebaseKeys.murmur_last_processed_event_details)

    details = @fb_client.fetch_last_processed_event_details

    assert_equal({ 'timestamp' => 3.days.ago.to_f }, details)
    Timecop.return
  end

end
