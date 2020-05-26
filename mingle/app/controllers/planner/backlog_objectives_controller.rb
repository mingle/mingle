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

class BacklogObjectivesController < PlannerApplicationController
  layout 'planner/application'

  allow :put_access_for => [:plan_objective, :update, :reorder], :get_access_for => [:index]
  privileges UserAccess::PrivilegeLevel::LIGHT_READONLY_TEAM_MEMBER => [:index]

  def index
    render :layout => "planner/in_program"
  end

  def destroy
    @backlog_objective = Objective.find(params[:id])
    if @backlog_objective.destroy
      flash[:notice] = "Feature #{@backlog_objective.name.bold} has been deleted."
    else
      flash[:error] = @backlog_objective.errors.full_messages.join("\n")
    end
    redirect_to program_backlog_objectives_path(@program)
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = "Invalid Backlog Feature, cannot continue to delete."
    redirect_to program_backlog_objectives_path(@program)
  end

  def plan_objective
    objective = @program.objectives.find(params[:id])
    @program.plan.plan_backlog_objective(objective)
    redirect_to program_plan_path(@program, :planned_objective => objective.name)
  end

  def update
    backlog_objective = @program.objectives.find(params[:id])
    values = params[:objective]
    values[:value_statement].delete!("\r") if values[:value_statement]
    if backlog_objective.update_attributes(values)
      render :nothing => true
    else
      render :text => backlog_objective.errors.full_messages.join("\n"), :status => 422
    end
  end

  def create
    @backlog_objective = @program.objectives.backlog.create(params["backlog_objective"])

    if @backlog_objective.valid?
      render :partial => 'backlog_objective', :locals => {:backlog_objective  => @backlog_objective}
    else
      flash.now[:error] = @backlog_objective.errors.full_messages.join("\n")
      render :partial => 'layouts/flash', :status => 422
    end
  end

  def reorder
    @program.reorder_objectives(params[:backlog_objective])
    render :nothing => true
  end

  def confirm_delete
    @objective = @program.objectives.backlog.find_by_id(params[:id].to_i)
    @destroy_params = {:action => 'destroy', :id => @objective.id}
    render_in_lightbox 'confirm_delete'
  end
end
