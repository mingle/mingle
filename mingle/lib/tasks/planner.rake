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

namespace :db do
  namespace :test do
    desc 'short name for prepare_simple_program'
    task :prepare_sp => ['prepare_simple_program']

    desc "do db test prepare, only load simple_program script"
    task :prepare_simple_program => [:setup_prepare_simple_program, 'db:test:prepare']
    task :setup_prepare_simple_program do
      ENV['LP'] = 'simple_program'
    end
  end
end

namespace :test do
  desc "Run planner related unit & functional tests"
  task :planner => ['test:unit:planner', 'test:functional:planner']
  task :planner_ruby => ['test:unit:planner', 'test:functional:planner']
end
