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

require 'monitor'

Clock
class Clock
  class <<self
    @@now = []
    @@now.extend(MonitorMixin)
    
    @@client_timezone_offset = []
    @@client_timezone_offset.extend(MonitorMixin)
    
    def now_is(options, &block)
      fake_now(options)
      yield now
    ensure  
      reset_fake
    end
    
    def fake_now(options)
      return fake_now(options.to_s(:db)) if Time === options
      
      if String === options
        begin
          t = DateTime.strptime(options, Time::DATE_FORMATS[:db])
        rescue ArgumentError
          t = DateTime.strptime(options, DateTime::DATE_FORMATS[:db])
        end
        
        return fake_now(:year => t.year, :month => t.month, :day => t.day, :hour => t.hour, :min => t.min, :sec => t.sec)
      end
      
      options = options.with_indifferent_access
      
      @@now.synchronize do
        @@now << Time.utc(options[:year].to_i, options[:month].to_i, options[:day].to_i, 
          options[:hour].to_i, options[:min].to_i, options[:sec].to_i, options[:usec])
      end
      @@now.last
    end
    
    def fake_client_timezone_offset(options)
      options = HashWithIndifferentAccess.new(options)
      @@client_timezone_offset.synchronize do
        @@client_timezone_offset << options[:offset]
      end
    end

    def reset_fake
      @@now.synchronize do
        @@now.clear
      end
      @@client_timezone_offset.synchronize do
        @@client_timezone_offset.clear
      end
    end

    def now
      @@now.synchronize do
        if @@now.empty?
          Time.now.utc
        else
          @@now.last
        end
      end
    end
    
    def client_timezone_offset
      @@client_timezone_offset.synchronize do
        @@client_timezone_offset.last
      end
    end
  end
end
