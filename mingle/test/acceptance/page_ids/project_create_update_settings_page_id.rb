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

module ProjectCreateUpdateSettingsPageId

  NEW_PROJECT_LINK="link=New project"
  WHY_NOT_CREATE_LINK="link=why not create one"
  PROJECT_EMAIL_SENDER_NAME_ID='project_email_sender_name'
  PROJECT_EMAIL_ADDRESS_ID='project_email_address'
  AS_MEMBER_ID='as_member'
  PROJECT_TIME_ZONE_DROPDOWN="project_time_zone"
  PROJECT_DATE_FORMAT_DROPDOWN="project_date_format"
  PROJECT_ADMIN_LINK='link=Project admin'
  PROJECT_SAVE_LINK="link=Save"
  PROJECT_IDENTIFIER_NAME='project[identifier]'
  PROJECT_NAME_ID='project_name'
  PROJECT_DESCRIPTION_NAME='project[description]'
  ADVANCED_OPTIONS_LINK='link=Advanced Options'
  PROJECT_MEMBERSHIP_REQUESTABLE_ID='project_membership_requestable'
  PROJECT_ANONYMOUS_ACCESSIBLE_ID='project_anonymous_accessible'
  CREATE_PROJECT_LINK='create_project'
  CANCEL_CREATE_PROJECT_LINK='link=Cancel'
  PROJECT_PRECISION_ID='project_precision'
  REPORSITORY_CONFIG_PATH_NAME='repository_config[repository_path]'
  PROJECT_ENROLL_USER_TYPE_READONLY_ID="project_auto_enroll_user_type_readonly"
  ENABLE_AUTO_ENROLL_ID="enable_auto_enroll"
  CANCEL_LINK="link=Cancel"
  CONTINUE_TO_EXPORT_LINK="link=Continue to export"

  def project_admin_link_for(menu_item)
    "link=#{menu_item}"
  end

  def template_name_identifier(template_identifier, origin = nil)
    if template_identifier == ProjectsController::BLANK
      "template_name_#{template_identifier}"
    else
      "template_name_#{origin || 'custom'}_#{template_identifier}"
    end
  end

  def template_name_from_current_project_name(current_project)
    "template_name_custom_#{current_project}"
  end

  def project_key_settings(key)
    "project_#{key}"
  end
end
