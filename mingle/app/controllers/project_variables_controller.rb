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

class ProjectVariablesController < ProjectAdminController

  ANY_CARD_TYPE = 'Any card type'

  allow :get_access_for => [:list, :new, :edit, :select_data_type], :redirect_to => { :action => :list }

  privileges UserAccess::PrivilegeLevel::PROJECT_ADMIN =>["create", "new", "edit", "update", "confirm_delete", "delete", "select_data_type", "confirm_update", "select_card_type"]

  def new
    @project_variable = ProjectVariable.new :project => @project
  end

  def confirm_delete
    @project_variable = @project.project_variables.find(params[:id])
  end

  def delete
    project_variable = @project.project_variables.find(params[:id])
    project_variable.destroy
    flash[:notice] = "Project variable #{project_variable.name.bold} was successfully deleted"
    redirect_to :action => 'list'
  end

  def edit
    @project_variable = @project.project_variables.find(params[:id])
  end

  def create
    @project_variable = ProjectVariable.new :project_id => @project.id
    update_project_variable(@project_variable, 'create')
  end

  def confirm_update
    params[:project_variable][:property_definition_ids] = [] if params[:project_variable][:property_definition_ids].blank?
    @project_variable = @project.project_variables.find(params[:id])
    new_name = params[:project_variable].delete(:name)
    @project_variable.attributes = params[:project_variable]
    params[:project_variable].merge!(:name => new_name)
    if @project_variable.smooth_update?
      update
    else
      set_rollback_only
    end
  end

  def update
    @project_variable = @project.project_variables.find(params[:id])
    if @project_variable.name != params[:project_variable][:name]
      card_context.on_project_variable_name_changed(@project_variable.name, params[:project_variable][:name])
    end
    update_project_variable(@project_variable, 'update')
  end

  def list
    @project_variables = @project.project_variables.smart_sort_by(&:name)
  end

  def select_data_type
    @project_variable = ProjectVariable.new(params[:project_variable].merge(:project_id => @project.id))
    render(:update) do |page|
      page['value_field_container'].replace_html :partial => @project_variable.value_field_container
      page['available_property_definitions_container'].replace_html :partial => 'available_property_definitions'
    end
  end

  def select_card_type
    params[:project_variable] ||= {}
    card_type = @project.card_types.find_by_id(params[:card_type_id])
    checked_property_definitions = PropertyDefinition.find(params[:project_variable][:property_definition_ids] || [])
    @project_variable = ProjectVariable.new(:project_id => @project.id, :card_type => card_type, :data_type => params[:data_type], :property_definitions => checked_property_definitions)

    render(:update) do |page|
      page['card_selector_drop_link_container'].replace_html :partial => 'card_selector'
      page['available_property_definitions_container'].replace_html :partial => 'available_property_definitions', :locals => { :checked_property_definitions => checked_property_definitions }
    end
  end

  def always_show_sidebar_actions_list
    ['list']
  end

  private

  def update_project_variable(project_variable, action)
    params[:project_variable][:property_definition_ids] = [] if params[:project_variable][:property_definition_ids].blank?
    if project_variable.update_attributes(params[:project_variable])
      flash[:notice] = "Project variable #{project_variable.name.bold} was successfully #{action}d."
      redirect_to :action => :list
    else
      set_rollback_only
      flash.now[:error] = project_variable.errors.full_messages
      render :action => action == 'create' ? 'new' : 'edit'
    end
  end

end
