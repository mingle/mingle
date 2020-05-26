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
  class RetryOnError
    def initialize(options)
      @pattern = options[:match]
      @max_tries = options[:tries] || 3
      @interval = options[:interval] || 0.1
    end

    def new(endpoint)
      @endpoint = endpoint
      self
    end

    def send_message(*args)
      with_retry do
        @endpoint.send_message(*args)
      end
    end

    def receive_message(queue, options={}, &block)
      with_retry do
        @endpoint.receive_message(queue, options, &block)
      end
    end

    def with_retry(&block)
      tries = 1
      begin
        yield
      rescue => e
        if (e.class.to_s =~ @pattern || e.message =~ @pattern) && tries < @max_tries
          tries += 1
          sleep(@interval)
          Rails.logger.info { "The following error occurred interacting with the AWS SDK, retrying the operation: #{e.message} \n #{e.backtrace.join('\n')}" }
          retry
        else
          raise e
        end
      end
    end
  end
end
