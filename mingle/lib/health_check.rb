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

module HealthCheck
  module_function
  def log_info_threshold
    (ENV["HEALTH_CHECK_LOG_THRESHOLD"] || 100).to_i
  end

  def run
    ms = Benchmark.ms do
      keepalive
    end
    Rails.logger.info("HealthCheck#run #{ms.to_i}ms") if ms > log_info_threshold
  end

  def keepalive
    memcache_keepalive
  end

  def memcache_keepalive
    Cache.get('health_check', 3600) { 'keepalive' }
  end
end
