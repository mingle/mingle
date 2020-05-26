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

module ProgramProjectsHelper
  def define_done_message(plan, project)
    has_available_property = project.enum_property_definitions_with_hidden.any?
    if (!plan.program.status_mapped?(project)) && has_available_property
      link_to 'define done status', :action => :edit, :id => project.identifier
    elsif (!has_available_property)
      authorized?({controller: :program_projects, action: :edit}) ?
          "#{link_to('define a managed text property in this project', property_definitions_list_path(:project_id => project.identifier))}".html_safe :
          'define a managed text property in this project'
    elsif authorized?({controller: :program_projects, action: :edit})
      link_to("#{plan.program.status_property_of(project).name} >= #{plan.program.done_status_of(project).name}", :action => :edit, :id => project.identifier)
    else
      "#{plan.program.status_property_of(project).name} >= #{plan.program.done_status_of(project).name}"
    end
  end

  def associated_card_types(project, property_name)
    associated_card_types = @project.with_active_project do |project|
      card_type_names = project.find_property_definition(property_name, :with_hidden => true).card_type_names
      card_type_names.collect { |type| "\"" + escape_characters(type) + "\", " }
    end
  end

  def escape_characters(string)
     pattern = /(\'|\"|\.|\*|\/|\-|\\)/
     string.gsub(pattern) { |match| "\\"  + match }
   end
end
