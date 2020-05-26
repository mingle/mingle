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

class PlansController < PlannerApplicationController
  allow :get_access_for => [:show, :edit],
        :put_access_for => [:update]
  
  privileges UserAccess::PrivilegeLevel::MINGLE_ADMIN => %w(destroy confirm_delete),
             UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER => %w(show update edit),
             UserAccess::PrivilegeLevel::LIGHT_READONLY_TEAM_MEMBER => [:show, :update, :edit]

  layout "planner/in_program"

  def show
    @timeline_objectives = @plan.timeline_objectives
  end
  
  def edit
    plan_admin = render_to_string(:partial => "edit")
    render(:update) do |page|
      page.inputing_contexts.update(plan_admin)
    end
  end
  
  def update
    if @plan.update_attributes(params[:plan].slice(:start_at, :end_at))
      flash[:notice] = "Plan has been updated"
      render(:update) do |page|
        page.redirect_to(program_plan_path(@plan.program))
      end
    else
      flash.now[:error] = @plan.errors.full_messages
      error_message = render_to_string(:partial => 'layouts/flash')
      render(:update) do |page|
        page.refresh_flash
      end
    end
  end
end
