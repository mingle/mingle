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

module ProjectRepositorySettingsAction
  
  def select_scm_type(scm_type)
     @browser.select_and_wait(ProjectRepositorySettingsPageId::REPOSITORY_TYPE_SELECT_BOX,scm_type)
   end

 
  
   def navigate_to_subversion_repository_settings_page(project)
     project = Project.find_by_identifier(project) unless project.respond_to?(:cards)
     @browser.open("/projects/#{project.identifier}/repository?repository_type=SubversionConfiguration")
   end

   def navigate_to_project_repository_settings_page(project)
     project = Project.find_by_identifier(project) unless project.respond_to?(:cards)
     @browser.open("/projects/#{project.identifier}/repository")
   end
  
end
