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

class ProjectCache
  DEFAULT_OPTIONS = {:expires => 8.hours, :max => 100}
  class CachedObject
    attr_reader :obj, :expires_at

    def initialize(obj, expires)
      @obj = obj
      @expires_at = Time.now + expires
    end

    def expired?
      Time.now >= @expires_at
    end
  end

  class Stat < Struct.new(:key, :total_gets, :total_hits)
    def self.sum(name, stats)
      summary = stats.inject(Stat.new(name, 0, 0)) do |sum, stat|
        sum + stat
      end
      [summary].concat(stats)
    end
    def +(stat)
      Stat.new(key, total_gets + stat.total_gets, total_hits + stat.total_hits)
    end
    def hit_rate
      return "0%" if total_gets < 1
      "#{total_hits * 100/total_gets}%"
    end
  end

  class UnsychronizedCache
    attr_reader :expires
    def initialize(options={})
      options = DEFAULT_OPTIONS.merge(options)
      @expires = options[:expires]
      @max = options[:max]
      @store = Hash.new {|h, k| h[k] = []}
      @project_version_key_store = options[:project_version_key_store]
    end

    def turn_off?
      @max < 1
    end

    def total_count
      @store.collect {|key, values| values.size}.inject(0) {|sum, value| sum + value}
    end

    def in_cache_projects
      @store.collect do |key, value| 
        key.split('/').first unless @store[key].empty?
      end.compact.uniq
    end

    def [](key)
      return nil if @project_version_key_store.project_version_key(key).nil?
      @store[project_cache_key(key)].pop.try(:obj)
    end

    def []=(key, object)
      @store["#{key}/#{object.project_cache_key}"] << CachedObject.new(object, self.expires)
    end

    def clear
      @store.clear
    end

    def clear_garbage_objects
      deleted_objects = evicted_objects

      @store.delete_if do |key, cached_objects|
        cached_objects.delete_if { |object| object.expired? || deleted_objects.include?(object) }
        project_identifier = key.split("/").first
        key != project_cache_key(project_identifier)
      end
    end

    private

    def evicted_objects
      sorted_objects = @store.values.flatten.sort_by {|o| o.expires_at}.reverse
      sorted_objects[@max..-1] || []
    end

    def project_cache_key(project_identifier)
      "#{project_identifier}/#{@project_version_key_store.project_version_key(project_identifier)}"
    end

  end

  def initialize(options={})
    @store = UnsychronizedCache.new(options)
    @stats = Hash.new {|h,k| h[k] = Stat.new(k, 0, 0)}
    @mutex = Mutex.new
  end

  

  def stats
    @mutex.synchronize do
      @stats.values.collect{|stat| stat.dup}
    end
  end

  def start_reaping_invalid_objects(interval=10 * 60) #10 minutes, do not use 10.minutes which does not work with sleep
    Thread.start do
      loop do
        sleep(interval)
        clear_garbage_objects

        #clear everything in thread local, the key segments may cache something inside
        Thread.current.keys.each do |key|
          Thread.current[key] = nil
        end
      end
    end
    self
  end

  def total_count
    @mutex.synchronize do
      @store.total_count
    end
  end
  
  def in_cache_projects
    @mutex.synchronize do
      @store.in_cache_projects
    end
  end

  def [](key)
    return nil if @store.turn_off?
    @mutex.synchronize do
      stat = @stats[key]
      stat.total_gets += 1
      @store[key].tap {|r| stat.total_hits += 1 if r}
    end
  end

  def []=(key, value)
    return if @store.turn_off?
    @mutex.synchronize do
      @store[key] = value
    end
  end

  def clear
    @mutex.synchronize do
      @store.clear
    end
  end
  
  def clear_garbage_objects
    @mutex.synchronize do
      @store.clear_garbage_objects
    end
  end
end
