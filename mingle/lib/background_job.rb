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

class BackgroundJob
  def initialize(task, worker_name=nil, alarms=nil)
    @task = task
    @worker_name = worker_name || 'unknown'
    @alarms = alarms || Alarms
  end

  def run_once
    @task.call
  rescue => e
    @alarms.notify(e, {:task => task_name})
    raise e
  end

  def task_name
    @worker_name.gsub(/-\d+$/, '')
  end
end
