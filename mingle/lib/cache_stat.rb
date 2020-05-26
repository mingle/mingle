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

require 'thread'
class CacheStat
  class View
    def initialize(stats)
      @stats = stats
    end

    def each_key(&block)
      @stats.keys.each(&block)
    end

    def [](key)
      @stats[key]
    end

    def total_hits(key=nil)
      total(key, :hit)
    end

    def total_gets(key=nil)
      total(key, :get)
    end

    def total(key, type)
      key ? self[key][type] : (@stats.values.map{|v| v[type]}.reduce(:+) || 0)
    end

    def hit_rate(key=nil)
      return "0%" if total_gets(key) < 1
      "#{total_hits(key) * 100/total_gets(key)}%"
    end
  end

  def initialize
    @states = Hash.new {|h, k| h[k]={:get => 0, :hit => 0}}
    @mutex = Mutex.new
  end

  def get(key)
    @mutex.synchronize { @states[key][:get] += 1 }
  end
  
  def hit(key)
    @mutex.synchronize { @states[key][:hit] += 1 }
  end
  
  def capture
    @mutex.synchronize do
      c = @states.dup
      c.each do |key, value|
        c[key] = value.dup
      end
      View.new(c)
    end
  end
end


