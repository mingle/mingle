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

module Memcached
  def self.servers
    if !defined?(MINGLE_MEMCACHED_PORT)
      memcached_port = [ENV['MINGLE_MEMCACHED_PORT'], java.lang.System.getProperty("mingle.memcachedPort"), "11211"].find(&:present?)
    else
      memcached_port = MINGLE_MEMCACHED_PORT
    end
    if !defined?(MINGLE_MEMCACHED_HOST)
      memcached_hosts = [ENV['MINGLE_MEMCACHED_HOST'], java.lang.System.getProperty("mingle.memcachedHost"), "127.0.0.1"].find(&:present?)
    else
      memcached_hosts = MINGLE_MEMCACHED_HOST
    end
    hosts = memcached_hosts.split(',')
    ports = memcached_port.split(',')
    hosts.zip(ports).collect {|host, port| "#{host}:#{port}"}
  end
end
