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
  class FileBasedCache
    attr_reader :key
    def initialize(key)
      @key = key
      @dir = SwapDir::DailyHistoryChart.chart_path(key).pathname
      FileUtils.mkdir_p(@dir)
    end

    def cached_data_count
      Dir.glob(File.join(@dir, '*.cache')).size
    end

    def cached_data_values(dates)
      dates.collect { |date| data_for(date) }
    end

    def data_for(date)
      return nil unless File.exists?(cache_file_path(date))
      File.read(cache_file_path(date)).to_s.split(',').map(&:to_i)
    end

    def write_data(date, data)
      File.open(cache_file_path(date), 'w') do |file|
        file.print data.join(',')
      end
    end

    def clear
      FileUtils.rm_rf(@dir)
      FileUtils.mkdir_p(@dir)
    end

    private
    def cache_file_path(date)
      File.join(@dir, "#{data_path(date)}.cache")
    end

    def data_path(date)
      date.strftime("%Y%m%d")
    end
  end
end
