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

begin
  require 'macro_development_toolkit'
rescue LoadError
  require 'rubygems'
  require 'macro_development_toolkit'
end

require File.dirname(__FILE__) + '/lib/dependency_tracker'

if defined?(RAILS_ENV) && defined?(MinglePlugins)
  MinglePlugins::Macros.register(DependencyTracker::CardMacro,
                                 'dependency-tracker-card')
  MinglePlugins::Macros.register(DependencyTracker::ProjectMacro,
                                 'dependency-tracker-project')
  MinglePlugins::Macros.register(DependencyTracker::ProgramMacro,
                                 'dependency-tracker-program')
end
