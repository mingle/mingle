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

class TimelineObjective
  attr_writer :total_work, :work_done
  delegate :id, :to => :@objective
  def initialize(objective)
    @objective = objective
  end
  
  def total_work
    @total_work.to_i
  end
  
  def work_done
    @work_done.to_i
  end

  def to_json(options={})
    {
      :id => @objective.id,
      :name => @objective.name,
      :vertical_position => @objective.vertical_position,
      :start_at => @objective.start_at,
      :end_at => @objective.end_at,
      :status => @objective.status,
      :url_identifier => @objective.url_identifier,
      :total_work => total_work,
      :work_done => work_done,
      :late => @objective.late?,
      :start_delayed => @objective.start_delayed?,
      :sync_finished => @objective.sync_finished?
    }.to_json(options)
  end

  def self.from(objective, plan)
    objectives_work_counts = plan.works.count(:group => 'objective_id')
    objectives_work_done_counts = plan.works.completed.count(:group => 'objective_id')

    timeline_objective = TimelineObjective.new(objective)

    timeline_objective.total_work = objectives_work_counts[objective.id]
    timeline_objective.work_done = objectives_work_done_counts[objective.id]

    timeline_objective
  end
end
