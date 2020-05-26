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

module Planner
  module HasManyProjects
    def self.included(base)
      base.has_many :program_projects, :dependent => :destroy
      base.has_many :projects, :through => :program_projects
      base.named_scope :associated_with, lambda { |project| {:conditions => ['program_projects.project_id = ?', project.id], :include => {:program_projects => [:status_property, :done_status]}} }
    
    end
  
    def update_project_status_mapping(project, status_mapping)
      project.with_active_project do |project|
        enum_text_props = project.enum_property_definitions_with_hidden.reject(&:is_numeric?)
        status_name = status_mapping[:status_property_name]
        done_value = status_mapping[:done_status]

        unless status_prop = enum_text_props.detect{|prop| prop.name.downcase == status_name.to_s.downcase.trim}
          self.errors.add_to_base("Property #{status_name} not found.")
          return false
        end
        unless done_status = status_prop.values.detect { |value| value.value.downcase == done_value.to_s.downcase.trim }
          self.errors.add_to_base("Property value #{done_value} not found.")
          return false
        end
        program_project = program_project(project)
        updated = program_project.update_attributes(:status_property => status_prop, :done_status => done_status)

        program_project.errors.each { |error| errors.add_to_base(error[1]) } unless updated
        updated
      end
    end

    def dependencies
      deps = []
      projects.each do |project|
        deps = deps | project.raised_dependencies
        deps = deps | project.resolving_dependencies
      end
      deps
    end

    def projects_with_work_in(objective)
      return [] unless objective.id
      Project.find(:all, :joins => "INNER JOIN (SELECT w.project_id FROM #{Work.table_name} w WHERE w.objective_id = #{objective.id} 
                                          GROUP BY w.project_id) works on works.project_id = #{Project.table_name}.id")
    end

    def assign(project)
      program_projects.create(:project_id => project.id)
      plan.program.reload
    end

    def unassign(project)
      program_projects.find_by_project_id(project.id).destroy
    end

    def assignable_projects
      # todo performance issue?, should not smart sort here
      (Project.all_available - self.projects).smart_sort_by(&:name)
    end

    def program_project(project)
      program_projects.detect {|pp| pp.project_id == project.id}
    end

    def with_done_status_definition(project)
      if done_status_definition = program_project(project).done_status_definition
        yield(done_status_definition)
      end
    end

    def status_mapped?(project)
      !program_project(project).status_property.nil?
    end

    def status_property_of(project)
      program_project(project).status_property
    end

    def done_status_of(project)
      program_project(project).done_status
    end
  end
end
