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

class MurmurEmailPoller

  DEFAULT_FILTERS = [InvalidUserMessageFilter.new, MessageExpiredFilter.new]

  def initialize(message_filters=DEFAULT_FILTERS, auto_reply_notifier=MurmurAutoReplyNotification.new)
    @mailgun_client = MailgunClient.new(MingleConfiguration.mailgun_api_key, MingleConfiguration.mailgun_domain)
    @fb_client = FirebaseMurmurEmailClient.new(FirebaseClient.new(MingleConfiguration.firebase_app_url, MingleConfiguration.firebase_secret))
    @message_filters = message_filters
    @auto_reply_notifier = auto_reply_notifier
  end

  def on_email(batch_size=100, &block)
    last_processed_event_details = @fb_client.fetch_last_processed_event_details
    messages = @mailgun_client.fetch_stored_messages(batch_size, {:begin => last_processed_event_details[:timestamp]})
    unprocessed_messages = messages.select { |message| message.id != last_processed_event_details[:id] }

    Rails.logger.debug("Found #{unprocessed_messages.count} new messages for murmur reply processing")  if unprocessed_messages.count > 0
    unprocessed_messages.each do |message|
      with_retry(MingleConfiguration.failed_murmur_reply_retry_count) do
        murmur_data = filtered_murmur_data(message)

        process_murmur_data(murmur_data, &block) unless murmur_data.nil?
      end
      @fb_client.set_last_processed_event_details(message)
    end
  end

  private

  def process_murmur_data(murmur_data, &block)
    if MingleConfiguration.multitenancy_mode?
      Multitenancy.activate_tenant(murmur_data.tenant) do
        Rails.logger.info("Switched to tenant: #{murmur_data.tenant} in murmur email poller")
        block.call(murmur_data) if block_given?
      end
    else
      block.call(murmur_data) if block_given?
    end
  end

  def filtered_murmur_data(message)
    return unless message.recipient
    data = @fb_client.fetch_murmur_data(message.recipient.address)
    if data.nil?
      @auto_reply_notifier.send_auto_reply_for_message(message, :invalid_operation)
      Rails.logger.info("*********** No murmur data found for message(#{message.id}). Auto Reply sent.")
      return
    end
    return if @message_filters.any? do |message_filter|
      message_filtered = message_filter.filter?(message, data)
      Rails.logger.info("*********** Message(#{message.id}) filtered for #{message_filter.class.name}") if message_filtered
      message_filtered
    end
    murmur_data = @mailgun_client.fetch_email(message)
    if murmur_data.nil?
      Rails.logger.info("*********** No email data found for message(#{message.id})")
      return
    end
    murmur_data.set_firebase_data(data['tenant'], data['murmur_id'], data['user_id'])
    murmur_data
  end

  def with_retry(tries, &block)
    count=0
    begin
      block.call
    rescue Exception => e
      count += 1
      retry if count < tries
      Rails.logger.info("Murmur Reply Processing failed after #{tries} retries. Reason: #{e.message} : #{e.backtrace}")
    end
  end
end
