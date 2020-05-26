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

class ProjectVariableMacro < Macro
  parameter :name, :required => true, :example => "project_variable_name"
  parameter :project
  
  def execute_macro
    all_variables = project.project_variables
    variable = 
      all_variables.detect{|pv| pv.name.downcase == name.downcase} || 
      all_variables.detect{|pv| pv.display_name.downcase == name.downcase}
    raise "Project variable #{name.bold} does not exist" unless variable
    render_value(variable)
  end
  
  def render_value(project_variable)
    if project_variable.display_card_link?
      card = project.cards.find_by_id(project_variable.value)
      view_helper.link_to(project_variable.display_value, :project_id => project.identifier, :controller => 'cards', :action =>'show', :number => card.number)
    else
      (project_variable.charting_value || PropertyValue::NOT_SET).escape_html
    end  
  end
  
  def can_be_cached?
    true
  end
  
end

Macro.register('project-variable', ProjectVariableMacro)
