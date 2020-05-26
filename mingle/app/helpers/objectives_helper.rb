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

module ObjectivesHelper
  def view_plan_objective_work_path(program, objective)
    plan_objective_work_path(program, objective, {:status => ['is not', 'done']})
  end

  def plan_objective_work_path(program, objective, filters={})
    options = {:filters => Work::Filter.encode(filters)} unless filters.empty?
    program_plan_objective_works_path(program, objective, options)
  end

  def work_progress_message
    if @objective.works.any?
      work_done = @objective.works.completed.count
      verb = work_done == 1 ? "is" : "are"
      "#{work_done} of #{work_items} #{verb} done"
    end
  end

  def work_items
    pluralize(@objective.works.count, "work item")
  end

  def work_progress_message_link
    if message = work_progress_message
      link_to message, plan_objective_work_path(@plan.program, @objective, :status => 'done')
    end
  end

  def objective_name_tag(objective)
    if objective.value_statement.blank?
      content_tag("span", objective.name)
    else
      link_to_remote(objective.name, :url => {:action => 'view_value_statement', :id => objective.identifier, :program_id => objective.program.identifier }, :method => :get)
    end
  end
end
