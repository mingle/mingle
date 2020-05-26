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

module TeamMembersAdminPage
  def assert_user_is_team_member(user)
     @browser.assert_element_present("#{user.html_id}")
   end

   def assert_user_is_not_team_member(user)
     @browser.assert_element_not_present("#{user.html_id}")
   end
   
   def assert_groups_button_is_diabled
     @browser.assert_has_classname(TeamMembersAdminPageId::ASSIGN_GROUPS, "disabled")
   end

   def assert_groups_button_is_enabled
     @browser.assert_does_not_have_classname(TeamMembersAdminPageId::ASSIGN_GROUPS, "disabled")
   end

   def assert_group_fully_checked(group_order_in_droplist)
     @browser.assert_has_classname(css_locator("#options-container li div", group_order_in_droplist), "tristate-checkbox-checked", "the group #{group_order_in_droplist} is not fully checked!")
   end

   def assert_group_patially_checked(group_order_in_droplist)
     @browser.assert_has_classname(css_locator("#options-container li div", group_order_in_droplist), "tristate-checkbox-partial", "the group #{group_order_in_droplist} is not partially checked!")
   end

   def assert_group_is_unchecked(group_order_in_droplist)
     @browser.assert_has_classname(css_locator("#options-container li div", group_order_in_droplist), "tristate-checkbox-unchecked", "the group #{group_order_in_droplist} is checked!")
   end

   def assert_message_shows_in_group_selector_popup(message)
     @browser.assert_text_present_in(TeamMembersAdminPageId::GROUP_SELECTOR, message)
   end
   
   def assert_add_team_member_link_present
     @browser.assert_element_present(TeamMembersAdminPageId::ADD_TEAM_MEMBER_LINK)
   end

   def assert_add_team_member_link_not_present
     @browser.assert_element_not_present(TeamMembersAdminPageId::ADD_TEAM_MEMBER_LINK)
   end


   def assert_user_table_not_present_on_the_page
     @browser.assert_element_not_present(TeamMembersAdminPageId::USERS_ID)   
   end

   def assert_user_table_present_on_the_page
     @browser.assert_element_present(TeamMembersAdminPageId::USERS_ID)   
   end

   def assert_add_full_and_readonly_member_link_present_for(user)
     @browser.assert_element_present(add_full_member_access_to_user(user))
     @browser.assert_element_present(add_read_only_access_to_user(user))
   end

   def assert_only_add_readonly_member_link_present_for(user)
     @browser.assert_element_not_present(add_full_member_access_to_user(user))
     @browser.assert_element_present(add_read_only_access_to_user(user))    
   end

   def assert_add_to_team_link_not_present_for(user)
     @browser.assert_element_not_present(add_full_member_access_to_user(user))
     @browser.assert_element_not_present(add_read_only_access_to_user(user))
   end

   #should clean up after changed the way to apply permission to users
   def assert_users_not_editable_or_removable(*users)
     assert_member_can_not_be_removed
     users.each do |user|
       assert_project_admin_check_box_disabled_for(user)
       assert_read_only_team_member_check_box_disabled_for(user)
     end
   end

   def assert_users_editable_and_removable(*users)
     assert_member_can_be_removed
     users.each do |user|
       assert_project_admin_check_box_enabled_for(user)
       assert_read_only_team_member_check_box_enabled_for(user)
     end
   end


   def assert_user_is_normal_team_member(user)
     assert ::PermissionsDropdown.new(user, @browser).full_member?
   end

   def assert_user_is_read_only_team_member(user)
     assert ::PermissionsDropdown.new(user, @browser).readonly?
   end

   def assert_user_is_project_admin(user)
     assert ::PermissionsDropdown.new(user, @browser).project_admin?
   end

   def assert_project_admin_check_box_enabled_for(user)
     assert ::PermissionsDropdown.new(user, @browser).modifications_enabled?
   end

   def assert_read_only_team_member_check_box_enabled_for(user)
     assert ::PermissionsDropdown.new(user, @browser).modifications_enabled?
   end

   def assert_project_admin_check_box_disabled_for(user)
     assert_false ::PermissionsDropdown.new(user, @browser).modifications_enabled?
   end  

   def assert_read_only_team_member_check_box_disabled_for(user)
     assert_false ::PermissionsDropdown.new(user, @browser).modifications_enabled?
   end

   def assert_member_can_be_removed
     @browser.assert_element_present(TeamMembersAdminPageId::REMOVE_MEMBERSHIP)
   end

   def assert_member_can_not_be_removed
     @browser.assert_element_not_present(TeamMembersAdminPageId::REMOVE_MEMBERSHIP)
   end

   def assert_mingle_user_not_team_member_for(project, user)
     navigate_to_team_list_for(project)
     assert_user_is_not_team_member(user)
   end

   def assert_mingle_user_is_team_member_for(project, user)
     navigate_to_team_list_for(project)
     assert_user_is_team_member(user)
   end

   def assert_error_user_is_not_a_project_member(user)
     assert_error_message("#{user.name} is not a project member")
   end

   def assert_enable_auto_enroll_button_is_present
     @browser.assert_element_present(TeamMembersAdminPageId::ENABLE_ENROLL_ALL_USERS_LINK)
   end

   def assert_enable_auto_enroll_button_is_not_present
     @browser.assert_element_not_present(TeamMembersAdminPageId::ENABLE_ENROLL_ALL_USERS_LINK)
   end

   def assert_disable_auto_enroll_button_is_present
     @browser.assert_element_present(TeamMembersAdminPageId::DISABLE_ENROLL_ALL_USERS_LINK)
   end

   def assert_disable_auto_enroll_button_is_not_present
     @browser.assert_element_not_present(TeamMembersAdminPageId::DISABLE_ENROLL_ALL_USERS_LINK)
   end

   def assert_add_team_member_disabled
     @browser.assert_element_present(add_user_disabled_id)   
   end

   def assert_add_team_member_enabled
     @browser.assert_element_not_present(add_user_disabled_id)   
   end

   def assert_remove_user_link_is_not_present
     @browser.assert_element_not_present(TeamMembersAdminPageId::REMOVE_MEMBERSHIP)   
   end

   def assert_users_not_present_in_team_list(*users)
      users.each do |user|
        @browser.assert_element_not_present(team_user_id(user))
      end
   end

   def assert_users_checked_in_team_list(*users)
     users.each do |user|
       @browser.assert_checked(selected_membership_user_id(user))
     end
   end

   def assert_users_unchecked_in_team_list(*users)
     users.each do |user|
       @browser.assert_not_checked(selected_membership_user_id(user))
     end
   end

   def assert_group_links_that_user_belong_to_prsent(user, groups=[])
     groups.each do |group|
        @browser.assert_text_present_in(user_groups_id(user), group.name, "cannot find the group name '#{group.name}' in Groups column of #{user.name}")
        assert_include("groups/#{group.id}?back_to_team=true", @browser.get_eval("this.browserbot.getCurrentWindow().$('#{user_groups_id(user)}').innerHTML"))
     end    
   end

   def assert_group_links_that_user_doesnot_belong_to_not_prsent(user, groups=[])
     groups.each do |group|
        @browser.assert_text_not_present_in(user_groups_id(user), group.name, "Found group name '#{group.name}' in the Groups column for user '#{user.name}'")
     end
   end

   def assert_current_on_team_member_page_for(project)
     @browser.assert_location("/projects/#{project.identifier}/team/list")
   end
   
end
