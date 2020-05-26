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

# task missing for running a set of tests hierarchyly
# eg. by rake test:unit:foo
# you can run all you test under test/unit/foo/ without actually define the foo task

module Rake
  module TaskManager
    # the patch add an extra behavior onto rake tasks looking up: 
    # when rake cannot locate a task, a method named 'task_missing' will be called, then retry locating for once.
    # which gives you chance to actually define the missing task
    alias_method :old_selector, :[]
    def [](task_name, scopes=nil)
      begin
        old_selector(task_name, scopes)
      rescue RuntimeError => e
        raise(e) unless e.message =~ /^Don't know how to build task/
        task_missing(task_name, scopes) 
        raise(e) unless Task.task_defined?(task_name)
        retry
      end        
    end
  end
end

def task_missing(task_name, scope)
  test_path = File.join(*(task_name.split(":")))
  return unless File.exist?(test_path)
  Rake::TestTask.new(task_name) do |t|
    t.libs << "test"
    t.pattern = "#{test_path}/**/*_test.rb"
    t.verbose = true
  end
end
