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
  class ErrorHandling
    attr_reader :handler

    def initialize(endpoint, handler=nil, reraise_errors=[])
      @endpoint = endpoint
      @handler = handler
      @reraise_errors = reraise_errors
    end

    def send_message(*args)
      @endpoint.send_message(*args)
    end

    def receive_message(queue, *args, &block)
      @endpoint.receive_message(queue, *args) do |message|
        begin
          block.call(message)
        rescue => e
          msg = build_text_message(queue, message, e)
          Messaging.logger.error(msg)
          @handler.notify(e, {:queue => queue}) if @handler
          raise(e) if @reraise_errors.include?(e.class)
        end
      end
    end

    private
    def build_text_message(queue, message, e)
      %Q{Got error while processing message: #{e.message}
queue: #{queue}
message: #{message.inspect}
backtrace:
#{e.backtrace.join("\n")}
}
    end
  end
end
