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
  class MigrationGuard
    def initialize(endpoint, database=Database)
      @endpoint = endpoint
      @database = database
    end

    def send_message(*args)
      @endpoint.send_message(*args)
    end

    def receive_message(queue, options={}, &block)
      @endpoint.receive_message(queue, options) do |msg|
        if need_db_schema_consistent?(queue) && @database.need_migration?
          send_message(queue, [msg.to_sending_message])
        else
          block.call(msg) if block
        end
      end
    end

    private
    def need_db_schema_consistent?(queue)
      ProjectImportProcessor::QUEUE == queue ||
        ProgramImportProcessor::QUEUE == queue
    end
  end
end
