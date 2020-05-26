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
# lib/tasks/deadweight.rake
begin
  require 'deadweight'
rescue LoadError
end

desc "run Deadweight CSS check (requires script/server)"
task :deadweight do
  dw = Deadweight.new
  dw.stylesheets = ["/stylesheets/application.css"]
  dw.pages = ["/", "/feeds", "/about", "/episodes/archive", "/comments", "/episodes/1-caching-with-instance-variables"]
  dw.ignore_selectors = /flash_notice|flash_error|errorExplanation|fieldWithErrors/
  puts dw.run
end