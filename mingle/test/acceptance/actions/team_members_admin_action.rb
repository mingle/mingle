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

module TeamMembersAdminAction
  def project_admin_use_link_from_last_email_add_requestor_as_full_team_member
    login_as_proj_admin_user
    path = last_email.body.scan(/http:\/\/.*(\/projects\/.*)\b/).first.first
    @browser.open(path)
    @browser.with_ajax_wait do
      @browser.click(TeamMembersAdminPageId::FULL_LINK)      
    end
  end
  
  def navigate_to_team_list_for(project)
    project = project.identifier if project.respond_to? :identifier
    @browser.open("/projects/#{project}/team/list")
  end
  
  def add_user_to_group(project, users = [], groups = [])
    navigate_to_team_list_for(project)  
    users.each {|user| select_team_members(user)}
    click_groups_button
    groups.each {|group| select_group(group)}
    click_apply_group_memberships_button
  end
  
  def click_group_name_in_droplist(group_order_in_droplist)
    @browser.click(css_locator(TeamMembersAdminPageId::OPTIONS_CONTAINER_LI_DIV_ID, group_order_in_droplist)) 
  end
  
  def click_groups_button
    @browser.click(TeamMembersAdminPageId::ASSIGN_GROUPS_BUTTON)
  end
  
  def click_apply_group_memberships_button
    @browser.click_and_wait(TeamMembersAdminPageId::APPLY_GROUP_MEMBERSHIP_BUTTON)    
  end
  
  def select_group_by_order(group_order_in_droplist)
    @browser.click(css_locator(TeamMembersAdminPageId::OPTIONS_CONTAINER_LI_DIV_ID, group_order_in_droplist))    
  end
  
  def select_group(group)
    @browser.click(select_group_toggle(group))
  end


   def add_to_team_via_model_for(project, user)
     project.add_member(user)
   end

   def add_read_only_user_to_team_via_model_for(project, user)
     project.add_member(user, :readonly_member)
   end

   def add_to_team_as_project_admin_via_model_for(project, user)
     project.add_member(user, :project_admin)
   end

   def add_full_member_to_team_for(project, user, options={:back_to_team_list => true,:already_on_team_page => false})
     add_to_team_with(project, user, options) { click_add_to_team_link_on_all_member_list(user) }
   end

   def add_readonly_member_to_team_for(project, user, options={:back_to_team_list => true,:already_on_team_page => false})
     add_to_team_with(project, user, options) { click_add_readonly_to_team_link_on_all_member_list(user) }
   end

   def add_to_team_with(project, user, options, &block)
     unless options[:already_on_team_page]
       project = project.identifier if project.respond_to? :identifier
       navigate_to_team_list_for(project)
     end
     click_add_team_member_link_on_team_member_list
     show_all_users
     yield   
     if options[:back_to_team_list]
       click_back_to_team_list
     end
   end

   def add_several_users_to_team_for(project, *users)
     project = project.identifier if project.respond_to? :identifier
     navigate_to_team_list_for(project)
     click_add_team_member_link_on_team_member_list
     show_all_users
     users.each do |user|
       click_add_to_team_link_on_all_member_list(user)
     end
     click_back_to_team_list
   end

   def add_to_team_as_project_admin_for(project, user)
     add_full_member_to_team_for(project, user)
     make_project_admin(user)

   end

   def add_to_team_as_read_only_user_for(project, user)
     add_full_member_to_team_for(project, user)
     make_read_only(user)

   end 

   def make_project_admin(user)
     PermissionsDropdown.new(user, @browser).set_project_admin
     @browser.wait_for_text_present("#{user.name} is now a project administrator")
   end

   def make_full_member(user)
     PermissionsDropdown.new(user, @browser).set_full_member
     @browser.wait_for_text_present("#{user.name} is now a team member")
   end

   def make_read_only(user)
     PermissionsDropdown.new(user, @browser).set_read_only_member
     @browser.wait_for_text_present("#{user.name} is now a read only team member")
   end

   def remove_from_team_for(project, user, options={})
     project = project.identifier if project.respond_to? :identifier
     navigate_to_team_list_for(project)
     select_team_members(user)
     @browser.click_and_wait(TeamMembersAdminPageId::REMOVE_LINK)
     if @browser.is_element_present(TeamMembersAdminPageId::CONTINUE_TO_REMOVE_LINK) && options[:update_permanently]
       @browser.click_and_wait(TeamMembersAdminPageId::CONTINUE_TO_REMOVE_LINK)
     end
   end

   def select_team_members(*users)
     users.each do |user|
       @browser.click(selected_team_membership(user))
     end
   end

   def unselect_team_members(*users)
     users.each do |user|
       @browser.click(selected_team_membership(user))
     end
   end


   def remove_several_users_from_team_permanently(project, *users)
     users.each do |user|
       remove_from_team_for(project, user)
     end
   end

   def click_continue_to_remove
     @browser.click_and_wait(TeamMembersAdminPageId::CONTINUE_TO_REMOVE_LINK)
   end



   def click_add_team_member_link_on_team_member_list
     @browser.click_and_wait(TeamMembersAdminPageId::ADD_TEAM_MEMBERS_LINK)     
   end

   def click_add_to_team_link_on_all_member_list(user)
     @browser.with_ajax_wait do
       @browser.click(add_full_member_access_to_user(user))
     end
   end

   def click_add_readonly_to_team_link_on_all_member_list(user)
     @browser.with_ajax_wait do
       @browser.click(add_read_only_access_to_user(user))
     end
   end

   def click_back_to_team_list
     @browser.click_and_wait(TeamMembersAdminPageId::BACK_TO_TEAM_LIST_LINK)    
   end

   def auto_enroll_all_users_as_full_users(project)
     navigate_to_team_list_for(project)
     @browser.click(TeamMembersAdminPageId::ENABLE_ALL_USERS_LINK)
     @browser.click(TeamMembersAdminPageId::AUTO_ENROLL_FULL_USER_ID)    
     @browser.click(enable_auto_enroll_form())
     @browser.wait_for_element_present("css=.disable-enroll")
     @browser.assert_text_present("Enroll all users as team members currently is enabled")
   end

   def auto_enroll_all_users_as_readonly_users(project)
     navigate_to_team_list_for(project)
     @browser.click(TeamMembersAdminPageId::ENABLE_ALL_USERS_LINK)
     @browser.click(TeamMembersAdminPageId::AUTO_ENROLL_READONLY_USER_ID)    
     @browser.click(enable_auto_enroll_form())
     @browser.wait_for_element_present("css=.disable-enroll")
     @browser.assert_text_present("Enroll all users as team members currently is enabled")
   end

   def disable_auto_enroll_all_user(project)
     navigate_to_team_list_for(project)
     @browser.click(TeamMembersAdminPageId::DISABLE_ALL_USERS_LINK)
     @browser.wait_for_page_to_load
   end

   def remove_user_from_team_and_add_it_back_as_full_team_member(project, user)
     remove_from_team_for(project, user, :update_permanently => true)
     @browser.assert_text_present("1 member has been removed from the #{project.identifier} team successfully")
     add_full_member_to_team_for(project, user)
   end

end
