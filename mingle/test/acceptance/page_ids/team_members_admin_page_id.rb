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

module TeamMembersAdminPageId
  
  FULL_LINK="link=Full"
  REMOVE_LINK="link=Remove"
  CONTINUE_TO_REMOVE_LINK="link=Continue to remove"
  ADD_TEAM_MEMBERS_LINK='link=Add team member'
  BACK_TO_TEAM_LIST_LINK="link=Back to team list"
  ENABLE_ALL_USERS_LINK="link=Enable enroll all users as team members"
  DISABLE_ALL_USERS_LINK="link=Disable enroll all users as team members"
  ASSIGN_GROUPS_BUTTON="assign_groups"
  APPLY_GROUP_MEMBERSHIP_BUTTON="apply_group_memberships_changes"
  AUTO_ENROLL_FULL_USER_ID="auto_enroll_user_type_full"
  AUTO_ENROLL_READONLY_USER_ID="auto_enroll_user_type_readonly"
  OPTIONS_CONTAINER_LI_DIV_ID="#options-container li div"
  ASSIGN_GROUPS = "assign_groups"
  GROUP_SELECTOR = "group-selector"
  ADD_TEAM_MEMBER_LINK = "link=Add team member"
  USERS_ID = 'users'
  REMOVE_MEMBERSHIP ="remove_membership"
  ENABLE_ENROLL_ALL_USERS_LINK = "link=Enable enroll all users as team members"
  DISABLE_ENROLL_ALL_USERS_LINK = "link=Disable enroll all users as team members"
  
  def select_group_toggle(group)
    "toggle_group_group_#{group.id}"
  end
  
  def selected_team_membership(user)
    "selected_membership_#{user.id}"
  end
  
  def add_full_member_access_to_user(user)
    "add-full-member-#{user.html_id}-to-team"
  end
  
  def add_read_only_access_to_user(user)
    "add-readonly-member-#{user.html_id}-to-team"
  end
  
  def enable_auto_enroll_form()
    css_locator("#enable_auto_enroll_form input[type=submit]")
  end
  
  def add_user_disabled_id
    class_locator("add-user-disabled")
  end
  
  def team_user_id(user)
    "user_#{user.id}"
  end
  
  def selected_membership_user_id(user)
    "selected_membership_#{user.id}"
  end
  
  def user_groups_id(user)
    "user_#{user.id}_groups"
  end
  
end
