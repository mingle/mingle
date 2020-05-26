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

class ProgramProjectsController < PlannerApplicationController
  allow :get_access_for => [:index, :edit, :confirm_delete, :property_values_and_associations], :put_access_for => [:update, :update_accepts_dependencies], :delete_access_for => [:destroy]

  privileges UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER => ["index", "create", "destroy", "update", "edit", "confirm_delete", "property_values_and_associations"],
             UserAccess::PrivilegeLevel::LIGHT_READONLY_TEAM_MEMBER => [:index]

  def create
    @project = Project.find_by_identifier(params[:new_program_project][:id])
    @program.assign(@project)
    html_flash[:notice] = "Project #{@project.name.bold.escape_html} has been added to this plan. Go to #{@template.link_to('plan', program_plan_path(@plan.program))}?"
    redirect_to :action => 'index'
  end
  
  def index; end

  def update_accepts_dependencies
    project = @program.projects.find_by_identifier(params[:id])
    program_project = @program.program_project(project)
    program_project.accepts_dependencies = params[:accepts_dependencies]
    if program_project.save
      flash[:notice] = if program_project.accepts_dependencies
        "Projects in this program will now be able to select #{project.name} when raising a dependency."
                       else
        "Projects in this program will no longer be able to see or select #{project.name} when raising a dependency."
                       end
    else
      flash[:error] = program_project.errors.full_messages
    end
    render(:update) do |page|
      page.refresh_flash
    end
  end
  
  def update
    @project = @program.projects.find_by_identifier(params[:id])
    if @program.update_project_status_mapping(@project, params[:program_project])
      redirect_to params[:back_to_url]
    else
      flash[:error] = @plan.errors.full_messages
      redirect_to :action => 'edit'
    end
  end
  
  def edit
    @project = @program.projects.find_by_identifier(params[:id])
  end
  
  def destroy
    @project = @program.projects.find_by_identifier(params[:id])
    @program.unassign(@project)
    flash[:notice] = "Project #{@project.name.bold} has been removed from this program."
    redirect_to :action => 'index'
  end
  
  def confirm_delete
    @project = @program.projects.find_by_identifier(params[:id])
  end
  
  def property_values_and_associations
    @project = @program.projects.find_by_identifier(params[:id])
    json = ""
    @project.with_active_project do |project|
      property_definition = project.find_property_definition(params[:property_name], :with_hidden => true)
      json = {
        :values => property_definition.allowed_values,
        :card_types => property_definition.card_type_names
      }.to_json
    end
    render :json => json
  end
end
