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

  # MessageGroup is designed for group all messages that are sent for processing a specific job, which will be split into several small jobs or messages in different queues.
  # MessageGroup groups messages sending out within an active group, and log the processed messages in the group.
  # When all messages in group are processed, we'll destory the group.
  # The MailboxExt extendes Mailbox to group message as current active group
  # The GatewayExt extendes Gateway to process message marked as group
  module Group
    module MailboxExt
      def send_message_with_message_group(queue_name, messages)
        if group = ::MessageGroup.active_group
          messages.compact.each { |message| group.mark(message) }
        end
        super(queue_name, messages)
      end
    end
  end
end
