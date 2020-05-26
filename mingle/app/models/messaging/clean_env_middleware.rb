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
  class CleanEnvMiddleware
    def initialize(endpoint)
      @endpoint = endpoint
    end

    def send_message(*args)
      @endpoint.send_message(*args)
    end

    def receive_message(*args, &block)
      @endpoint.receive_message(*args) do |message|
        clear_db_connections do
          clear_thread_local do
            clear_active_project do
              block.call(message)
            end
          end
        end
      end
    end

    private
    def clear_active_project(&block)
      previous_active_project = Project.current_or_nil
      block.call
    ensure
      Project.clear_active_project!
      previous_active_project.try(:activate)
    end

    def clear_db_connections(&block)
      block.call
    ensure
      ActiveRecord::Base.clear_active_connections!
    end

    def clear_thread_local(&block)
      block.call
    ensure
      ThreadLocalCache.clear!
    end
  end
end
