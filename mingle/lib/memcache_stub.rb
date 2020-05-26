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

class MemcacheStub
  def self.load
    return if CACHE.is_a?(MemcacheStub)
    Rails.logger.info "change CACHE and ActionController::Base.cache_store to memcached stub instance"
    CACHE.shutdown
    silence_warnings { Object.const_set "CACHE", MemcacheStub.new }
    silence_warnings { ActionController::Base.cache_store = MemcacheStub.new, {} }
  end

  attr_reader :store

  def initialize
    @store = {}
    @mutex = Mutex.new
  end

  def no_reply
    false
  end

  def get(key, raw = false)
    @mutex.synchronize do
      @store[ns(key)]
    end
  end
  alias_method :read, :get

  def get_multi(keys)
    values = {}
    @mutex.synchronize do
      keys.each do |key|
         values[key] = @store[ns(key)] if @store[ns(key)]
      end
    end

    values
  end
  alias_method :read_multi, :get_multi

  def exist?(key)
    @mutex.synchronize do
      @store.keys.include?(ns(key))
    end
  end

  def delete(key, expiry = 0)
    @mutex.synchronize do
      @store[ns(key)] = nil
    end
  end

  def add(key, value, expiry = 0, raw = false)
    @mutex.synchronize do
      @store[ns(key)] = value
    end
    "STORED\r\n"
  end

  def set(key, value, expiry = 0, raw = false)
    @mutex.synchronize do
      @store[ns(key)] = value
    end
  end
  alias_method :write, :set

  def flush_all
    @mutex.synchronize do
      @store.clear
    end
  end

  def incr(key, amount=1, expiry = 0)
    @mutex.synchronize do
      @store[ns(key)] = @store[ns(key)].to_i + 1
    end
  end
  alias_method :increment, :incr

  def desr(key, amount=1)
    @mutex.synchronize do
      @store[ns(key)] = @store[ns(key)].to_i - 1
    end
  end
  alias_method :decrement, :desr

  def without_connection
    silence_warnings { Object.const_set "CACHE", Object.new }
    def CACHE.method_missing(*args, &block)
      raise 'no connection'
    end
    yield
  ensure
    silence_warnings { Object.const_set "CACHE", self }
  end

  def ns(key)
    [MingleConfiguration.memcached_ns(Mingle::Revision::CURRENT), key].join(":")
  end

end
