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

class EnumerationValuesController < ProjectAdminController
  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  allow :get_access_for => [:list], :redirect_to => { :action => :list }
  helper :cards
  privileges UserAccess::PrivilegeLevel::PROJECT_ADMIN =>["create", "update_name", "destroy", "update_color", "confirm_delete"]

  def list
   @prop_def = @project.property_definitions_with_hidden.find(params[:definition_id])
   @enumeration_values = @prop_def.enumeration_values
  end

  def create
    p = params[:enumeration]
    p[:value] &&= p[:value].remove_html_tags
    enumeration_value = EnumerationValue.create(params[:enumeration])
    if enumeration_value.errors.any?
      set_rollback_only
      flash[:error] = enumeration_value.errors.full_messages
    end
    redirect_to :action  => 'list', :definition_id => enumeration_value.property_definition.id
  end

  def update_name
    enumeration_value = @project.find_enumeration_value(params[:id])
    original_enumeration_value = enumeration_value.value
    enumeration_value.value = params[:name].remove_html_tags
    unless enumeration_value.errors.empty? && enumeration_value.save
      set_rollback_only
      flash[:error] = enumeration_value.errors.full_messages
    end
    redirect_to :action => 'list', :definition_id => enumeration_value.property_definition
  end

  def update_color
    enumeration_value = @project.find_enumeration_value(params[:id])
    enumeration_value.nature_reorder_disabled = true
    enumeration_value.update_attributes(:color => params[:color_provider_color])
    render(:update) do |page|
      page.replace "color_panel_#{enumeration_value.id}", color_panel_for(enumeration_value)
    end
  end

  def confirm_delete
    @enumeration_value = @project.find_enumeration_value(params[:id])
    @used_by_project_variables = @enumeration_value.project_variables
    card_list_views = @enumeration_value.card_list_views
    @used_by_team_views, @used_by_personal_views = card_list_views.partition { |view| view.team? }
    destroy if @used_by_project_variables.empty? && @used_by_team_views.empty? && @used_by_personal_views.empty?
  end

  def destroy
    enumeration_value = @project.find_enumeration_value(params[:id]).destroy
    redirect_to :action  => 'list', :definition_id => enumeration_value.property_definition
  end

  def always_show_sidebar_actions_list
    ['list']
  end

end
