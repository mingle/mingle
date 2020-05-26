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

module CardsPlansHelper
  def no_objectives_available_for_selection?(plan, project)
    plan.program.objectives.planned.empty? || plan.program.objectives.planned.all? {|objective| objective.auto_sync?(project) }
  end

  def plan_objectives_of_card(plan, card, plan_objectives=nil)
    if plan_objectives && plan_objectives.has_key?(plan.id.to_s)
      ids = plan_objectives[plan.id.to_s].to_s.split(',').map(&:to_i)
      plan.program.objectives.planned.find_all_by_id(ids).reject(&:blank?)
    else
      plan.works.find_all_by_project_id_and_card_number(card.project_id, card.number).map(&:objective)
    end
  end

  def plan_objectives_for_ui(objectives)
    objectives.blank? ? [Objective.not_set] : objectives
  end

  def programs(project)
    Program.find(:all, :joins => :program_projects, :conditions => ['program_projects.project_id = ?', project.id])
  end
end
