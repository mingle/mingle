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

if defined?(ActiveRecord::Base.logger)
  Log = ActiveRecord::Base.logger
else
  require 'rubygems'
  require_gem 'log4r'

  Log = Log4r::Logger.new("rscm")
  Log.level = ENV["LOG4R_LEVEL"] ? ENV["LOG4R_LEVEL"].to_i : 0
  Log.add Log4r::Outputter.stderr
end
