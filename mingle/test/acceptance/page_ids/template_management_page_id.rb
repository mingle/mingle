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

module TemplateManagementPageId
  
  PROJECT_ADMIN_LINK='link=Project admin'
  DELETE_THIS_LINK="link=Delete this"
  CONTINUE_TO_DELETE_LINK='link=Continue to delete'
  AGILE_HYBRID_TEMPLATE_ID="Agile_hybrid_template"
  SCRUM_TEMPLATE_ID="Scrum_template"
  STORY_TRACKER_TEMPLATE="Story_tracker_template"
  XP_TEMPLATE="Xp_template"
  
  def template_name_link(template_name) 
    "link=#{template_name}"
  end
  
  def project_identifier_template_link(project) 
    "link=#{@project.identifier} template"
  end
end
