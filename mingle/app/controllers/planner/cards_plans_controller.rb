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

class CardsPlansController < ProjectApplicationController
  allow :put_access_for => [:assign_to_objectives]

  def show
    program = Program.find_by_identifier(params[:program_id])
    card = @project.cards.find_by_number(params[:number])
    objectives = selected_objectives(program.plan)

    render_in_lightbox "assign_to_objectives", :locals => {
      :program => program,
      :card => card,
      :project => @project,
      :selected_objectives => Array(objectives),
      :editing => params[:editing]
    }
  end

  def assign_to_objectives
    selected_objectives = params[:selected_objectives] || []
    program = Program.find_by_identifier(params[:program_id])
    objectives = selected_objectives.map{|objective_id| program.objectives.find_by_id(objective_id) }
    if params[:editing] != 'true' && params[:number]
      card = @project.cards.find_by_number(params[:number])
      program.plan.assign_card_to_objectives(@project, card, objectives)
    end
    render :update do |page|
      page << "InputingContexts.pop();"
      page.replace_html "plan_#{program.identifier}_objectives", :partial => 'objectives', :locals => {:plan => program.plan, :objectives => objectives}
    end
  end

  private
  def selected_objectives(plan)
    ids = params[:selected_objectives].to_s.split(',').map(&:to_i)
    plan.program.objectives.find_all_by_id(ids).reject(&:blank?)
  end
end
