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

# this is back porting rails 4.0 method so that we use db connection more effectively

if ActiveRecord::ConnectionAdapters::ConnectionPool.methods.include?(:active_connection?)
  raise "Trying to define an existing method active_connection? Are you doing a rails upgrade? If so, please consider removing the patch instead."
end

module ActiveRecord
  module ConnectionAdapters
    class ConnectionPool
      def active_connection?
        @reserved_connections[current_connection_id] != nil
      end
    end

    class ConnectionHandler
      def active_connections?
        @connection_pools.values.any?(&:active_connection?)
      end
    end
  end
end
