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

class DailyHistoryCache
  class << self
    def store(project, cache_path)
      if MingleConfiguration.daily_history_cache_bucket_name
        s3_store(cache_path)
      else
        file_store(cache_path)
      end
    end

    def file_store(key)
      self.new(FileBasedCache.new(key))
    end

    def s3_store(key)
      self.new(S3Cache.new(key))
    end
  end

  delegate :key, :cached_data_count, :to => :@store

  def initialize(store)
    @store = store
  end

  def data_for(date)
    Cache.get(key_for(date)) do
      @store.data_for(date)
    end
  end

  def clear_store
    @store.clear
  end

  def cached_data_values(dates)
    data = Cache.get_multi(dates.map { |date| key_for(date) }) || {}

    dates.map do |date|
      if value = data[key_for(date)]
        [*value].map(&:to_i)
      else
        if value = @store.data_for(date)
          Cache.put(key_for(date), value)
          [*value].map(&:to_i)
        else
          []
        end
      end
    end
  end

  def save(date, &block)
    unless data_for(date)
      data = block.call
      @store.write_data(date, data)
      Cache.put(key_for(date), data)
    end
  end

  private
  def key_for(date)
    "#{key}_#{date.strftime("%Y%m%d")}"
  end
end

require 'macro/daily_history_cache/file_based_cache'
require 'macro/daily_history_cache/s3_cache'
