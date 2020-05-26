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

if !defined?(MINGLE_MEMCACHED_PORT)
  MINGLE_MEMCACHED_PORT = ENV['MINGLE_MEMCACHED_PORT'] ? ENV['MINGLE_MEMCACHED_PORT'].to_s : '11211'
end
if !defined?(MINGLE_MEMCACHED_HOST)
  MINGLE_MEMCACHED_HOST = ENV['MINGLE_MEMCACHED_HOST'] ? ENV['MINGLE_MEMCACHED_HOST'].to_s : '127.0.0.1'
end
hosts = MINGLE_MEMCACHED_HOST.split(',')
ports = MINGLE_MEMCACHED_PORT.split(',')
servers = hosts.zip(ports).collect {|host, port| "#{host}:#{port}" }

# DO NOT CALL CACHE DIRECTLY, USE Cache.xxxx instead

# only enable spymemcached in production environment as it is not friend to no memcached server environments
Rails.logger.info("memcache client: spymemcached.jruby")
require 'spymemcached'
CACHE = Spymemcached.new(servers, {
  :timeout => 0.5,
  :namespace => lambda { MingleConfiguration.memcached_ns(Mingle::Revision::CURRENT) },
  :binary => MingleConfiguration.saas?
}).rails23

CACHE_STORE = ActiveSupport::Cache::MemCacheStore.new(CACHE)
MEMCACHED_TIMEOUT_CLASS = MemCache::MemCacheError

ActionController::Base.cache_store = CACHE_STORE, {}
require 'memcache_util'
