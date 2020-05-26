#!/usr/bin/env ruby

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

#
# You may specify the path to the FastCGI crash log (a log of unhandled
# exceptions which forced the FastCGI instance to exit, great for debugging)
# and the number of requests to process before running garbage collection.
#
# By default, the FastCGI crash log is RAILS_ROOT/log/fastcgi.crash.log
# and the GC period is nil (turned off).  A reasonable number of requests
# could range from 10-100 depending on the memory footprint of your app.
#
# Example:
#   # Default log path, normal GC behavior.
#   RailsFCGIHandler.process!
#
#   # Default log path, 50 requests between GC.
#   RailsFCGIHandler.process! nil, 50
#
#   # Custom log path, normal GC behavior.
#   RailsFCGIHandler.process! '/var/log/myapp_fcgi_crash.log'
#
require File.dirname(__FILE__) + "/../config/environment"
require 'fcgi_handler'

RailsFCGIHandler.process!
