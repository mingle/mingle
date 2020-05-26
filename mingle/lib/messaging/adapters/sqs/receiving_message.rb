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
  module Adapters
    module SQS
      class ReceivingMessage

        def initialize(message)
          @message = message
        end

        def [](key_for_body)
          to_h[key_for_body.to_sym]
        end

        def property(key)
          to_h[key.underscore.to_sym]
        end

        def to_h
          @body_hash ||= SendingMessage.parse_body_xml_as_hash(@message.body)
        end
        alias :body_hash :to_h

        def to_sending_message
          SendingMessage.new(to_h)
        end

      end
    end
  end
end
