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
# A utility wrapper around the rails cache store to simplify cache access.  All
# methods silently cache errors.

module Cache
  TIMEOUT_CLASS = StandardError
  ##
  # Returns the object at +key+ from the cache if successful, or nil if either
  # the object is not in the cache or if there was an error attermpting to
  # access the cache.

  def self.get(key, expiry = nil)
    value = benchmark_log("Get #{key}") do
      Rails.cache.read key
    end
    if value.nil? and block_given? then
      value = yield
      Rails.cache.write key, value, expires_in: expiry
    end
    value
  rescue TIMEOUT_CLASS, RuntimeError => err
    log { "Cache Error[get]: #{err.message}" }
    if block_given? then
      value = yield
      put key, value, expiry
    end
    value
  end

  def self.get_multi(keys)
    benchmark_log("Get #{keys.inspect}") do
      Rails.cache.read_multi(keys)
    end
  rescue TIMEOUT_CLASS, RuntimeError => err
    log { "Cache Error[get]: #{err.message}" }
  end

  ##
  # Sets +value+ in the cache at +key+, with an optional +expiry+ time in
  # seconds.

  def self.put(key, value, expiry = nil)
    benchmark_log("Set #{key}") do
      Rails.cache.write key, value, expires_in: expiry
    end
    value
  rescue TIMEOUT_CLASS, RuntimeError => err
    log { "Cache Error[put]: #{err.message}" }
    nil
  end

  ##
  # Sets +value+ in the cache at +key+, with an optional +expiry+ time in
  # seconds.  If +key+ already exists in cache, returns nil.

  def self.add(key, value, expiry = nil)
    benchmark_log("Add #{key}") do
      Rails.cache.write key, value, expires_in: expiry
    end
  rescue TIMEOUT_CLASS, RuntimeError => err
    log { "Cache Error [add]: #{err.message}" }
    nil
  end

  ##
  # Deletes +key+ from the cache in +delay+ seconds.

  def self.delete(key)
    benchmark_log("Delete #{key}") do
      Rails.cache.delete key
    end
  rescue TIMEOUT_CLASS, RuntimeError => err
    log {"Cache Error[delete]: #{err.message}"}
    nil
  end

  def self.incr(key, amount = 1, expiry = nil)
    benchmark_log("incr #{key} #{amount}") do
      Rails.cache.increment(key, amount, expires_in: expiry)
    end
  rescue TIMEOUT_CLASS, RuntimeError => err
    log {"Cache Error[incr]: #{err.message}"}
    nil
  end

  def self.flush_all
    benchmark_log('Reset') do
      Rails.cache.clear
    end
  end

  def self.benchmark_log(msg, threshold=100, &block)
    result = nil
    elapsed = Benchmark.ms { result = block.call }.round
    Rails.logger.send(elapsed > threshold ? :info : :debug) do
      ret_info = if msg =~ /^Get/i
        ", #{result.nil? ? 'got result' : 'no result'}"
      end
      "Cache #{msg} Completed in #{elapsed}ms#{ret_info}."
    end
    result
  end

  def self.log(&block)
    @level ||= Rails.env.production? ? :info : :debug
    Rails.logger.send(@level, &block)
  end
end
