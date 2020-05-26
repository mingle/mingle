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

class ProgramDependenciesController < PlannerApplicationController
  allow :get_access_for => [:dependencies, :popup_show, :popup_history]

  privileges UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER => ["popup_show"],
             UserAccess::PrivilegeLevel::LIGHT_READONLY_TEAM_MEMBER => [:dependencies, :popup_show, :popup_history]
  include DependenciesHelper
  include DependencyActions

  def dependencies
    @view = @program.dependency_views.current
    @view.update_params(params)
  end

  def date_format_context
    @plan
  end

  def popup_history
    dependency = Dependency.find(params[:id])
    dependency.raising_project.with_active_project do |project|
      history = History.for_versioned(project, dependency)
      render :partial => 'shared/events',
        :locals => {:include_object_name => false, :include_version_links => false, :show_initially => true, :history => history, :project => project, :popup => true, program_dependency: true}
    end
  end
end
