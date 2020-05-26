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

module Messaging
  module Mailbox

    mattr_accessor :sender

    def instance
      Thread.current['current_mail_box']
    end

    def transaction(&block)
      Thread.current['current_mail_box'] = Base.new(Mailbox.sender)
      yield
      Thread.current['current_mail_box'].commit
    ensure
      Thread.current['current_mail_box'] = nil
    end

    module_function :transaction, :instance

    def send_message(queue_name, messages)
      if Thread.current['current_mail_box']
        Thread.current['current_mail_box'].pend_queue_mail(queue_name, messages)
      else
        transaction do
          Thread.current['current_mail_box'].pend_queue_mail(queue_name, messages)
        end
      end
    end

    class Mail
      attr_reader :recipient, :messages

      def initialize(recipient, messages)
        @recipient = recipient
        @messages = messages
      end

      def store(suite)
        if suite[key]
          suite[key].merge!(messages)
        else
          suite[key] = self
        end
      end

      def merge!(messages)
        @messages.concat(messages)
      end

      def key
        @recipient.inspect
      end

      def ==(mail)
        return false unless mail
        @recipient == mail.recipient && @messages == mail.messages
      end

      def to_s
        "recipient: #{@recipient}; message: #{@messages.inspect}"
      end
    end

    class Suite

      def initialize
        @__mails__ = {}
      end

      def add_queue(recipient, messages)
        messages = messages.flatten.compact
        return if messages.blank?
        mail = Mail.new(recipient, messages)
        mail.store(@__mails__)
      end

      def deliver_queue_mails(&block)
        deliver_mails(&block)
      end

      def recipients
        mails.collect(&:recipient).uniq
      end

      def messages
        mails.collect(&:messages).flatten
      end

      def find_by_recipient(recipient)
        mails.detect {|m| m.recipient == recipient}
      end

      def find_all_by_recipient(recipient)
        mails.select {|m| m.recipient == recipient}
      end

      def to_a
        mails
      end

      def size
        mails.size
      end
      private
      def mails
        @__mails__.values
      end

      def deliver_mails
        @__mails__.each do |key, mail|
          yield(mail)
          @__mails__.delete(key)
        end
      end
    end

    class Base

      attr_reader :pending_mails

      def initialize(sender)
        @sender = sender
        reset
      end

      def pend_queue_mail(recipient, messages)
        @pending_mails.add_queue(recipient, messages)
      end

      def queue_messages(recipient)
        queue = @pending_mails.find_by_recipient(recipient)
        queue ? queue.messages : []
      end

      def commit
        @pending_mails.deliver_queue_mails do |mail|
          options = delay_seconds(@pending_mails.size)
          Messaging.logger.debug { "Sending #{mail.messages.size} messages to queue #{mail.recipient} with option => #{options.inspect}" }
          @sender.send_message(mail.recipient, mail.messages, options)
        end
      end

      def empty?
        @pending_mails.size == 0
      end

      def reset
        @pending_mails = Suite.new
      end
      private
      def delay_seconds(size)
        if MingleConfiguration.message_delay_seconds_rate
          {:delay_seconds => size * MingleConfiguration.message_delay_seconds_rate.to_i}
        else
          {}
        end
      end
    end
  end
end
