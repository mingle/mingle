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


#make sure it loaded
ActiveRecord::ConnectionAdapters::ConnectionPool
# ActiveRecord::Base.connection_pool.instance_variable_set("@reserved_connections", ThreadsafeHash.new)
 module ActiveRecord
  module ConnectionAdapters
    #code is copied from activerecord 2.3.5
    class ConnectionPool
      def initialize(spec)
        @spec = spec

        # The cache of reserved connections mapped to threads
        @reserved_connections = ThreadsafeHash.new                  #changed this line

        # The mutex used to synchronize pool access
        @connection_mutex = Monitor.new
        @queue = @connection_mutex.new_cond

        #(changed) using spec config timeout
        @timeout = spec.config[:wait_timeout] || 5

        # default max pool size to 5
        @size = (spec.config[:pool] && spec.config[:pool].to_i) || 5

        @connections = []
        @checked_out = []
      end

      def disconnect!
        @reserved_connections.each do |name,conn|
          checkin conn
        end
        @reserved_connections = ThreadsafeHash.new                  #changed this line
        @connections.each do |conn|
          conn.disconnect!
        end
        @connections = []
      end

      def checkout
        # Checkout an available connection
        @connection_mutex.synchronize do
          loop do
            conn = if @checked_out.size < @connections.size
                     checkout_existing_connection
                   elsif @connections.size < @size
                     checkout_new_connection
                   end
            return conn if conn
            # No connections available; wait for one
            # changing 3 lines below this , see https://github.com/rails/rails/commit/444aa9c7350f243a6b4b2a3ff1601493a812872a https://rails.lighthouseapp.com/projects/8994/tickets/5736
            Rails.logger.info { "Entering wait in connection pool queue for a timeout of #{@timeout}-"}
            t = @queue.wait(@timeout)
            Rails.logger.info { "Leaving wait in connection pool queue after a timeout of #{@timeout} after #{t}-"}
            if(@checked_out.size < @connections.size)
              next
            else
              clear_stale_cached_connections!
              if @size == @checked_out.size
                raise ConnectionTimeoutError, "could not obtain a database connection#{" within #{@timeout} seconds" if @timeout}.  The max pool size is currently #{@size}; consider increasing it."
              end
            end
          end
        end
      end

      # Clears the cache which maps classes
      def clear_reloadable_connections!
        @reserved_connections.each do |name, conn|
          checkin conn
        end
        @reserved_connections = ThreadsafeHash.new                  # changed this line
        @connections.each do |conn|
          conn.disconnect! if conn.requires_reloading?
        end
        @connections = []
      end

      def release_connection
        conn = @reserved_connections.delete(current_connection_id)
        checkin conn if conn
      end

    end
  end
end
