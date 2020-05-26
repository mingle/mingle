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

module DependencyAccess

  private

  def authorized_to_access_dependency(dependency)
    authorized_to_access(dependency.raising_project) || authorized_to_access(dependency.resolving_project)
  end

  def authorized_to_edit_dependency(dependency)
    allowed_to_edit(dependency.raising_project) || allowed_to_edit(dependency.resolving_project)
  end

  def authorized_to_access(project)
    return false if project.nil?
    return true if User.current.api_user? || User.current.admin? || project.anonymous_accessible? || project.member?(User.current) || authorized_programs(project).length > 0
  end

  def authorized_programs(project)
    project.programs.select { |p| authorized_for?(p, :controller => 'program_dependencies', :action => 'update') }
  end

  def allowed_to_edit(project)
    return false if project.nil?
    authorized_for?(project, :controller => 'dependencies', :action => 'update') || authorized_programs(project).length > 0
  end

end
