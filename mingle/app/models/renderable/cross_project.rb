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

module Renderable
  module CrossProject
    def self.included(base)
      base.alias_method_chain :can_be_cached?, :cross_project_check
    end
    
    def can_be_cached_with_cross_project_check?
      detect_cross_project_macro
      rendered_projects.size > 0 ? false : can_be_cached_without_cross_project_check?
    end
  
    def rendered_projects
      @rendered_projects ||= []
    end
  
    def add_rendered_project(rendered_project)
      return if rendered_project.nil? || rendered_projects.include?(rendered_project) || project == rendered_project
      self.rendered_projects << rendered_project
    end
  
    def detect_cross_project_macro
      return unless content
      reset_rendered_projects
      CrossProjectMacroFinder.new({:content_provider => self, :project => owner}).apply(content.dup)    
    end

    private
  
    def reset_rendered_projects
      @rendered_projects = []
    end
  
    class CrossProjectMacroFinder < Renderable::MacroFindSubstitution
      def substitute(match)
        name = match.captures[0]
        parameters = Macro.parse_parameters(match.captures[1]) 
        
        if parameters && parameters['project']
          project_identifier = ValueMacro.project_identifier_from_parameters(parameters, context[:content_provider])
          content_provider.add_rendered_project(Project.find_by_identifier(project_identifier.to_s))
        end
        
        if parameters && parameters[Renderable::PROJECT_GROUP]
           parameters[Renderable::PROJECT_GROUP].split(",").each do |p|
             content_provider.add_rendered_project(Project.find_by_identifier(p.strip))                  
           end
        end
        
        if series = parameters && parameters['series']
          series.each do |single_series|
            content_provider.add_rendered_project(Project.find_by_identifier(single_series['project'])) if single_series['project'] 
          end
        end
      rescue StandardError => e
        # validating each parameter is tedious, and we don't really care about a failure here... 
        # this macro will be unrenderable and that can be dealt with on the actual attempt to render
      end
    end
  end
end
