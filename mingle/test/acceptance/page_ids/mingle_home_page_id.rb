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

module MingleHomePageId

ALL_PROJECTS_LINK='css=.logo'
PROJECT_LIST_ID='projects_list'
REQUEST_MEMBERSHIP_LINK="link=Request membership"
NEW_PROJECT_LINK="link=New project"
CONTINUE_TO_DELETE_LINK="link=Continue to delete"
DELETE_THIS_LINK="link=Delete this"
EDIT_PROFILE_LINK="edit-profile"
ABOUT_LINK='link=About'
CREATE_TEMPLATE_FROM_PROJECT_LINK="link=Create template from this project"
NO_PROJECTS_WARNING_ID="no-projects-in-instance-warning"
NO_PROJECTS_AVAILABLE_WARNING_ID="no-projects-available-warning"
ADMIN_DROPDOWN_LINK='id=admin-drop-down'

  def project_link_on_mingle_home(project)
    "link=#{project.name}"
  end

  def project_name_link(project_name)
    "link=#{project_name}"
  end

  def create_template_for_project(project)
    "create_template_#{project}"
  end

  def login_name_on_warning_link(login_name)
    "link=#{login_name}"
  end

  def delete_project_link(project)
    return css_locator("a[href='/admin/projects/delete/#{project}']")
  end

  def project_identifier_link(project)
    "link=#{project.identifier}"
  end
end
