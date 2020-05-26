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

module ProgramsHelper
  include IconHelper

  def backlog_description(program)
    if program.objectives.empty?
      "Start tracking your objectives."
    else
      "#{pluralize(program.objectives.size, "Objective")}"
    end
  end

  def plan_description(program)
    if program.objectives.planned.empty?
      "Start planning your features."
    else
      "#{pluralize(program.objectives.planned.size, "Feature")} planned"
    end
  end

  def dependencies_description(program)
    dep_count = program.dependencies.length
    p program.dependencies
    if dep_count == 1
      '1 dependency outstanding'
    elsif dep_count > 1
      "#{dep_count} dependencies outstanding"
    else
      'No dependencies'
    end
  end

  def plan_link(program)
    ['Plan', program_plan_path(program), {:title => program.plan.name, :class => 'plan-link'}]
  end

end
