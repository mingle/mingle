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
  class Benchmarking
    def initialize(endpoint)
      @endpoint = endpoint
    end

    def send_message(*args)
      @endpoint.send_message(*args)
    end

    def receive_message(*args, &block)
      @endpoint.receive_message(*args) do |message|
        ret = nil
        ms = Benchmark.ms do
          ret = block.call(message)
        end
        Rails.logger.debug { "Processed one message in #{ms.to_i}ms (DB: #{db_run_time.to_i})" }
        if ms.to_i >= 2000
          Rails.logger.info("One message took 2s+: #{ms.to_i}ms (DB: #{db_run_time.to_i})")
        end
        ret
      end
    end

    private
    def db_run_time
      if active_connection?
        ActiveRecord::Base.connection.reset_runtime
      end
    end

    def active_connection?
      ActiveRecord::Base.connection_handler.active_connections?
    end

  end
end
