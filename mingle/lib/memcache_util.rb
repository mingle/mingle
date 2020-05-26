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

##
# A utility wrapper around the memcache client to simplify cache access.  All
# methods silently ignore memcache errors.

module Cache

  ##
  # Returns the object at +key+ from the cache if successful, or nil if either
  # the object is not in the cache or if there was an error attermpting to
  # access the cache.
  #
  # If there is a cache miss and a block is given the result of the block will
  # be stored in the cache with optional +expiry+, using the +add+ method rather
  # than +set+.

  def self.get(key, expiry = 0, raw = false)
    expiry = expiry.to_i
    value = benchmark_log("Get #{key}") do
      CACHE.get key, raw
    end
    if value.nil? and block_given? then
      value = yield
      add key, value, expiry, raw
    end
    value
  rescue MEMCACHED_TIMEOUT_CLASS, RuntimeError => err
    log { "Memcache Error[get]: #{err.message}" }
    if block_given? then
      value = yield
      put key, value, expiry
    end
    value
  end

  def self.get_multi(keys)
    benchmark_log("Get #{keys.inspect}") do
      CACHE.get_multi(keys)
    end
  rescue MEMCACHED_TIMEOUT_CLASS, RuntimeError => err
    log { "Memcache Error[get]: #{err.message}" }
  end

  ##
  # Sets +value+ in the cache at +key+, with an optional +expiry+ time in
  # seconds.

  def self.put(key, value, expiry = 0, raw = false)
    expiry = expiry.to_i
    benchmark_log("Set #{key}") do
      CACHE.set key, value, expiry, raw
    end
    value
  rescue MEMCACHED_TIMEOUT_CLASS, RuntimeError => err
    log { "Memcache Error[put]: #{err.message}" }
    nil
  end

  ##
  # Sets +value+ in the cache at +key+, with an optional +expiry+ time in
  # seconds.  If +key+ already exists in cache, returns nil.

  def self.add(key, value, expiry = 0, raw = false)
    expiry = expiry.to_i
    response = benchmark_log("Add #{key}") do
      CACHE.add key, value, expiry, raw
    end
    (response == "STORED\r\n") ? value : nil
  rescue MEMCACHED_TIMEOUT_CLASS, RuntimeError => err
    log { "Memcache Error [add]: #{err.message}" }
    nil
  end

  ##
  # Deletes +key+ from the cache in +delay+ seconds.

  def self.delete(key, delay = nil)
    benchmark_log("Delete #{key} #{delay.inspect}") do
      CACHE.delete key, delay
    end
    nil
  rescue MEMCACHED_TIMEOUT_CLASS, RuntimeError => err
    log {"Memcache Error[delete]: #{err.message}"}
    nil
  end

  def self.incr(key, amount = 1, expiry = 0)
    benchmark_log("incr #{key} #{amount}") do
      CACHE.incr(key, amount, expiry)
    end
  rescue MEMCACHED_TIMEOUT_CLASS, RuntimeError => err
    log {"Memcache Error[incr]: #{err.message}"}
    nil
  end

  ##
  # Resets all connections to memcache servers.

  def self.reset
    benchmark_log('Reset') do
      CACHE.reset
    end
    nil
  end

  def self.flush_all
    benchmark_log('Reset') do
      CACHE.flush_all
    end
    nil
  end


  def self.benchmark_log(msg, threshold=100, &block)
    result = nil
    elapsed = Benchmark.ms { result = block.call }.round
    Kernel.logger.send(elapsed > threshold ? :info : :debug) do
      ret_info = if msg =~ /^Get/i
        ", #{result.nil? ? 'got result' : 'no result'}"
      end
      "Memcache #{msg} Completed in #{elapsed}ms#{ret_info}."
    end
    result
  end

  def self.log(&block)
    @level ||= Rails.env.production? ? :info : :debug
    Kernel.logger.send(@level, &block)
  end
end
