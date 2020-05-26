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

module ManageUsersPageId
  SEARCH_USER_TEXT_BOX='search-query'
  SEARCH_USER_SUBMIT_BUTTON="user-search-submit"
  SEARCH_ALL_USERS="search-all-users"  
  SEARCH_BUTTON='search_button'
  ADD_USERS_TO_PROJECTS='link=Add to Projects'
  ADD_NEW_PROJECT_ASSIGNMENT='add_new_project_assignment'
  ADD_PROJECTS_BUTTON='add_projects'
  ASSIGN_PROJECTS_SUBMIT_BUTTON='assign_projects_submit'
  
  def select_project_option(droplist_number,project)
    "select_project_#{droplist_number}_option_#{project.name}"
  end
  
  def select_permission_option(droplist_number,membership_type)
    "select_permission_#{droplist_number}_option_#{membership_type}"
  end
  
  def select_project_drop_link(droplist_number)
    "select_project_#{droplist_number}_drop_link"
  end
  
  def select_permission_drop_link(droplist_number)
    "select_permission_#{droplist_number}_drop_link"
  end
  
  def select_project_droplist(droplist_number,project)
    "id=select_project_#{droplist_number}_option_#{project.name}"
  end
  
  def user_element(user)
     return "user_#{user.id}"
   end

   def light_user_checkbox(user)
     return "light-user-#{user.id}"
   end

   def admin_user_checkbox(user)
     return "admin-user-#{user.id}"
   end

   def activate_deactivate_link_id(user)
     return "user_#{user.id}_toggle_activation"
   end

   def show_profile_link_id(user)
     return "show-profile-#{user.id}"
   end

   def change_password_link_id(user)
     return "change-password-#{user.id}"
   end

   def search_box
     return 'search-query'
   end
   
   def delete_user_link(user)
     "user_#{user.id}_delete_user"
   end
    
  
end
