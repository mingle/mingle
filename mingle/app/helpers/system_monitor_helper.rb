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

module SystemMonitorHelper
  class MemcachedServer
    
    def initialize(address, states)
      @address = address
      @states = states
    end
    
    def address
      @address
    end
    
    def version
      @states['version']
    end
    
    def uptime
      @states['uptime']
    end
    
    def get_hits
      @states['get_hits']
    end
    
    # c version memcached is cmd_get and jmemcached is cmd_gets
    def total_gets
      @states['cmd_gets'] || @states['cmd_get'] || 0
    end
    
    def hit_rate
      rate(get_hits, total_gets)
    end
    
    # c version memcached is bytes and jmemcached is current_bytes
    def bytes_used
      @states['bytes'] || @states['current_bytes'] || 0
    end
    
    def limit_max_bytes
      @states['limit_maxbytes']
    end
    
    def use_rate
      rate(bytes_used, limit_max_bytes)
    end
    
    def total_items
      @states['cur_items']
    end
    
    private

    def rate(left_int, right_int)
      return if right_int == 0
      percent = (((left_int.to_f / right_int.to_f) * 10000).round) /100.00
      "#{percent} %"
    end
  end
  
  
  def memcached_servers
    CACHE.stats.collect{ |address, state| MemcachedServer.new(address, state)  } rescue []
  end
end
