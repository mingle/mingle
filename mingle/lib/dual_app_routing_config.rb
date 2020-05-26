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

class DualAppRoutingConfig
  if !defined?(MULTI_APP_ROUTING_DISABLED)
    ::MULTI_APP_ROUTING_DISABLED = 'MULTI_APP_ROUTING_DISABLED'
  end

  class << self
    def disable_routing
      with_client {|client| client.set(MULTI_APP_ROUTING_DISABLED, 0, 'true')}
    end

    def enable_routing
      with_client {|client| client.set(MULTI_APP_ROUTING_DISABLED, 0, 'false')}
    end

    def routing_enabled?
      with_client {|client| !(client.get(MULTI_APP_ROUTING_DISABLED) == 'true')}
    end

    def clear
      unless @memcache_client_without_namespace.nil?
        @memcache_client_without_namespace = nil
      end
    end

    private

    def with_client(&block)
      @memcache_client_without_namespace ||= create_client
      yield @memcache_client_without_namespace
    end

    def create_client
      host = MINGLE_MEMCACHED_HOST.split(',').first
      port = MINGLE_MEMCACHED_PORT.split(',').first
      inetAddr = Java::JavaNet.InetSocketAddress.new(host, port.to_i)
      Java::NetSpyMemcached::MemcachedClient.new(inetAddr)
    end
  end

end
