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

require 'storage'

class DailyHistoryCache
  class S3Cache
    attr_reader :key
    def initialize(key)
      @key = key
      @bucket_name = MingleConfiguration.daily_history_cache_bucket_name
      @store = Storage.store(:s3, prefix(key), {:bucket_name => @bucket_name})
    end

    def write_data(date, data)
      @store.write_to_file(data_key(date), data.join(","))
    end

    def cached_data_count
      @store.objects("cache").count
    end

    def data_for(date)
      data_key = data_key(date)
      return nil if !@store.exists?(data_key)
      @store.read(data_key).split(",").map(&:to_i)
    end

    def clear
      @store.clear
      @store = Storage.store(:s3, prefix(key.uniquify), {:bucket_name => @bucket_name})
    end

    private
    def prefix(key)
      File.join([MingleConfiguration.app_namespace, key].compact)
    end

    def data_key(date)
      File.join("cache", date_to_filename(date))
    end

    def date_to_filename(date)
      date.strftime("%Y%m%d")
    end

    def self.handle_errors_for(*methods)
      methods.each do |method|
        self.class_eval(gen_with_error_handling_method(method))
        self.alias_method_chain method, :error_handling
      end
    end

    def self.gen_with_error_handling_method(method)
      method,q = method.to_s =~ /\?$/ ? [method.to_s[0..-2],"?"] : [method.to_s,nil]

      %Q[
def #{method}_with_error_handling#{q}(*args)
  ret_value = nil
  5.times do
    begin
      ret_value = #{method}_without_error_handling#{q}(*args)
      break
    rescue => e
      Kernel.log_error(e, "error while executing #{method} on #{self.name}, retry")
    end
  end
  ret_value
end
]
    end

    handle_errors_for :write_data, :cached_data_count, :data_for

  end
end
