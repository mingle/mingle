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

module ManageUsersPage

 
  
  def assert_search_info_message_contains(text)
    @browser.assert_element_matches('info', /#{text}/)
  end

  def assert_user_login_and_name_present(user)
    @browser.assert_text_present_in("content", "#{user.login}")
    @browser.assert_text_present_in("content", "#{user.name}")
  end
  
  def assert_user_login_and_name_not_present(user)
    @browser.assert_text_not_present_in("content", "#{user.login}")
    @browser.assert_text_not_present_in("content", "#{user.name}")
  end

  def assert_user_is_present(user)
    @browser.assert_element_present(user_element(user))
    assert_user_login_and_name_present(user)
  end

  def assert_user_is_not_present(user)
    @browser.assert_element_not_present(user_element(user))
    assert_user_login_and_name_not_present(user)
  end

  def assert_users_are_present(*users)
    users.each {|user| assert_user_is_present(user)}
  end

  def assert_users_are_not_present(*users)
    users.each {|user| assert_user_is_not_present(user)}
  end

  def assert_search_user_result_info_present(search_pattern)
     @browser.assert_text_present("Search result for #{search_pattern}")
   end

   def assert_search_user_result_info_not_present(search_pattern)
     @browser.assert_text_not_present("Search result for #{search_pattern}")
   end
   
   def assert_user_is_in_user_management_page(user)
     @browser.assert_element_present(user_element(user))
   end

  
  def assert_user_is_not_in_user_management_page(user)
    @browser.assert_element_not_present(user_element(user))
  end
  
  def assert_users_are_in_user_management_page(*users)
     users.each do |user|
       assert_user_is_in_user_management_page(user)
     end
   end
   
  def assert_users_are_not_in_user_management_page(*users)
    users.each do |user|
      assert_user_is_not_in_user_management_page(user)
    end
  end
  
  def assert_light_user_check_box_present_for(user)
    @browser.assert_element_present(light_user_checkbox(user))
  end
  
  def assert_administrator_check_box_present_for(user)
     @browser.assert_element_present(admin_user_checkbox(user))
   end
  
   def assert_activate_deactivate_link_present_for(user)
     @browser.assert_element_present(activate_deactivate_link_id(user))
   end
   
   def assert_show_profile_link_present_for(user)
     @browser.assert_element_present(show_profile_link_id(user))
   end
   
   def assert_change_password_link_present_for(user)
     @browser.assert_element_present(change_password_link_id(user))
   end
   
   def assert_text_in_user_search_text_box(text)
     @browser.assert_value(search_box, text)
   end
   
   def assert_project_names_present_in_droplist(droplist_number, *projects)
     projects.each do |project|
       @browser.assert_element_present(select_project_droplist(droplist_number,project))
     end
   end

   def assert_project_names_not_present_in_droplist(droplist_number, *projects)
     projects.each do |project|
       @browser.assert_element_not_present(select_project_droplist(droplist_number,project))
     end
   end

   def assert_membership_is_selected_from_droplist(droplist_number, membership_type)
     assert_equal(@browser.get_eval("this.browserbot.getCurrentWindow().$('select_permission_#{droplist_number}_drop_link').innerHTML"), membership_type)
   end

   def assert_project_is_selected_from_droplist(droplist_number, project)
     assert_equal(@browser.get_eval("this.browserbot.getCurrentWindow().$('select_project_#{droplist_number}_drop_link').innerHTML"), project.name)
   end

   def assert_add_another_project_button_is_disabled
     assert_equal(@browser.get_eval("this.browserbot.getCurrentWindow().$('add_new_project_assignment').disabled"), "true")
   end 

   def assert_add_to_projects_button_is_enabled
     @browser.assert_does_not_have_classname(ManageUsersPageId::ADD_PROJECTS_BUTTON, "disabled")
   end  

   def assert_add_to_projects_button_is_disabled
     @browser.assert_has_classname(ManageUsersPageId::ADD_PROJECTS_BUTTON, "disabled")
   end 

   def click_the_remove_link(remove_link_number)
     @browser.click("project_assignment_remove_link_#{remove_link_number}") 
   end

   def assert_save_button_is_disabled
     @browser.assert_has_classname(ManageUsersPageId::ASSIGN_PROJECTS_SUBMIT_BUTTON, "disabled")
   end

   def assert_add_to_projects_button_is_not_present
     @browser.assert_element_not_present(ManageUsersPageId::ADD_USERS_TO_PROJECTS)
   end
   
   def assert_user_deleted_on_maagement_page(user)
         assert_user_is_not_in_user_management_page(user)
  end
  
  def assert_delete_link_not_present_for(user)
    @browser.assert_element_not_present(delete_user_link(user))
  end
  
  def assert_delete_link_not_present_for_users(*users)
    users.each do |user|
     assert_delete_link_not_present_for(user)
   end
  end  
  
  def assert_delete_link_present_for(user)
    @browser.assert_element_present(delete_user_link(user))
  end
  
  def assert_delete_link_present_for_users(*users)
    users.each do |user|
      assert_delete_link_present_for(user)
    end
  end
  
  def assert_users_deletable(*users)
    users.each do |user|
      @browser.assert_element_present(user_element(user))
    end
  end
  
  def assert_users_not_deletable(*users)
    users.each do |user|
      @browser.assert_element_not_present(user_element(user))
    end
  end
  
  
  def assert_user_is_mingle_admin(user)
    @browser.assert_checked(admin_user_checkbox(user))
  end
  
  def assert_user_is_full_user(user)
    @browser.assert_not_checked(admin_user_checkbox(user))
    @browser.assert_not_checked(light_user_checkbox(user))
  end
  
  def assert_user_is_light_user(user)
    @browser.assert_checked(light_user_checkbox(user))
  end
   
  def assert_user_deactivated(user)
    @browser.assert_element_matches(user_element(user), /deactivated/)
    assert_admin_check_box_disabled_for(user)
  end

  def assert_deactivation_notice_on_user_profile
    @browser.assert_element_present(css_locator(".deactivation-notice"))    
  end

  def assert_admin_check_box_disabled_for(user)
    assert_disabled(admin_user_checkbox(user))
  end
  
  def assert_light_check_box_disabled_for(user)
    assert_disabled(light_user_checkbox(user))   
  end
  
  def assert_admin_check_box_enabled_for(user)
    assert_enabled(admin_user_checkbox(user))
  end
  
  def assert_light_check_box_enabled_for(user)
    assert_enabled(light_user_checkbox(user))   
  end
  
  def assert_activate_deactivate_link_not_present_for(user)
     @browser.assert_element_not_present("#{user.html_id}_toggle_activation")  
  end
  
  def assert_light_user_created_message
    assert_notice_message("Light user was successfully created.")  
  end
  
  def assert_admin_user_created_message
    assert_notice_message("Administrator was successfully created.")  
  end
  
  def assert_full_user_created_message
    assert_notice_message("Full user was successfully created.")  
  end
  
  def assert_successful_user_deactivation_message(user)
    assert_notice_message("#{user.name} is now deactivated.")
  end
  
  def assert_deactivated_user_error_message(user)
    assert_error_message("The Mingle account for #{user.login} is no longer active. Please contact your Mingle administrator to resolve this issue.")
  end
  
  def assert_full_user_successfully_created_notice_present
    assert_notice_message("Full user was successfully created.")
  end
  
   
end
