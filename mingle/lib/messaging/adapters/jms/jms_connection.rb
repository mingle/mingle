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
    module JMS
      class JMSConnection
        def initialize(config)
          @config = config
          initialize_connection
          at_exit {
            begin; close; rescue => e; end
          }
        end

        def initialize_connection
          logger.debug "Initializing new JMS connection to #{connection_factory.broker_url}"
          @connection = connection_factory.create_connection
          @connection.start
          logger.debug "JMS Connection started."
        end

        def create_session
          begin
            logger.debug "Creating a javax.jms.Session"
            session = new_session
          rescue Exception => e
            logger.error "Failed to create a javax.jms.Session: #{e.backtrace.join("\n")}"
            logger.info "Retrying session creation..."

            # reinitialize the connection - this is usually the problem
            close
            initialize_connection

            session = new_session
            logger.info "Session created after successful retry."
          end
          session
        end

        def broker_name
          @connection.broker_name
        end

        def prefetch_size
          @connection.prefetch_policy.queue_prefetch
        end

        def close
          if @connection.nil?
            logger.debug "connection is nil, nothing to close"
          else
            logger.debug "Closing and cleaning up JMS Connection"
            @connection.cleanup
            @connection.close
            @connection = nil
            logger.debug "JMS Connection closed."
          end
        end

        private

        def connection_factory
          @connection_factory ||= org.apache.activemq.ActiveMQConnectionFactory.new(@config['username'], @config['password'], @config['uri'])
        end

        def new_session
          @connection.create_session(true, javax.jms.Session::AUTO_ACKNOWLEDGE)
        end

        def logger
          ActiveRecord::Base.logger
        end
      end
    end
  end
end
