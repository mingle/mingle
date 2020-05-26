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

require File.expand_path(File.dirname(__FILE__) + '/../../../acceptance/acceptance_test_helper')
# Tags: scenario, user
class Scenario173BulkRemoveUsersTest < ActiveSupport::TestCase 
  fixtures :users, :login_access
    
  def setup
      destroy_all_records(:destroy_users => false, :destroy_projects => true)
      @mingle_admin = users(:admin)
      @project_admin = users(:proj_admin)
      @project_member = users(:project_member)
      @read_only_user = users(:read_only_user)
      @browser = selenium_session
      @project = create_project(:prefix => "sc173", :admins => [@mingle_admin, @project_admin], :users => [@project_member], :read_only_users => [@read_only_user])
   end

   def test_remove_link_is_disabled_when_auto_enroll_is_on
      login_as_proj_admin_user
      navigate_to_team_list_for(@project)
      auto_enroll_all_users_as_full_users(@project)
      assert_link_disabled('.remove-membership')
   end

   def test_remove_link_disabled_when_no_user_is_selected
      login_as_admin_user
      navigate_to_team_list_for(@project)
      select_team_members(@project_admin, @project_member)
      unselect_team_members(@project_admin, @project_member)
      assert_link_disabled('.remove-membership')
   end
     
   def test_bulk_remove_users_with_history
      login_as_admin_user
      user_property = setup_user_definition("owner")
      number_property = setup_allow_any_number_property_definition("size")
      
      create_user_plv(@project, "user plv", @project_member, [user_property])
      
      create_transition(@project, 'transition 1', :set_properties => {"owner" => @project_member.id})      
      create_transition(@project, 'transition 2', :set_properties => {"owner"=> @mingle_admin.id})
      create_transition_for(@project, "Open Story", :set_properties => {"size" => 2}, :for_team_members => [@project_member])      
      setup_card_type(@project, "Story", :properties => ["owner"])      
      open_edit_defaults_page_for(@project, "Story")
      set_property_defaults(@project, "owner" => @project_member.name)
      click_save_defaults
      
      new_card = create_card!(:name => 'card0', :card_type => "Story", "owner" => @project_member.id)
                
      login_as_proj_admin_user
      navigate_to_team_list_for(@project)     
      select_team_members(@mingle_admin, @read_only_user, @project_member)    
      @browser.click_and_wait("link=Remove")  

      @browser.assert_text_present_in(class_locator("warning-box"), "WARNING: You are about to remove 3 members with the following effects:")
      @browser.assert_text_present_in(class_locator("warning-box"), "2 Transitions Deleted: transition 1, transition 2")
      @browser.assert_text_present_in(class_locator("warning-box"), "1 Transition Modified: Open Story")
      @browser.assert_text_present_in(class_locator("warning-box"), "1 Card Defaults Modified: Story")
      @browser.assert_text_present_in(class_locator("warning-box"), "1 Project Variable changed to (not set): user plv")
      @browser.assert_text_present_in(class_locator("warning-box"), "Card Properties changed to (not set): owner")
      
      @browser.click_and_wait("link=Continue to remove")
      @browser.assert_text_present_in(class_locator("success-box"), "3 members have been removed from the #{@project.name} team successfully.")
            
      assert_users_not_present_in_team_list(@mingle_admin, @read_only_user, @project_member)      
   end
            
   def test_bulk_remove_users_without_history
     login_as_proj_admin_user
     navigate_to_team_list_for(@project)     
     select_team_members(@mingle_admin, @read_only_user, @project_member)    
     @browser.click_and_wait("link=Remove")  
     
     @browser.assert_text_present_in(class_locator("success-box"), "3 members have been removed from the #{@project.name} team successfully.")                
     assert_users_not_present_in_team_list(@mingle_admin, @read_only_user, @project_member)      
   end

   def test_remove_user_by_selecting_all
     login_as_admin_user
      (1..10).each do
        create_user!
      end
      navigate_to_team_list_for(@project)     
      auto_enroll_all_users_as_full_users(@project)
      disable_auto_enroll_all_user(@project)
      select_all
      @browser.click_and_wait("link=Remove")
      @browser.assert_text_present_in(class_locator("success-box"), "23 members have been removed from the #{@project.name} team successfully.")                
   end

   def test_check_and_uncheck_users
     login_as_proj_admin_user
     navigate_to_team_list_for(@project)
     select_team_members(@mingle_admin, @read_only_user, @project_member)             
     @browser.assert_does_not_have_classname("link=Remove", "disabled")
     unselect_team_members(@mingle_admin, @read_only_user, @project_member)
     assert_link_disabled('.remove-membership')
   end
   
   def test_users_remain_checked_after_cancelling_bulk_removal
      login_as_admin_user
      user_property = setup_user_definition("owner")
      create_transition(@project, 'transition 1', :set_properties => {"owner" => @project_member.id})      
      create_transition(@project, 'transition 2', :set_properties => {"owner"=> @mingle_admin.id})
      
      navigate_to_team_list_for(@project)
      select_team_members(@mingle_admin, @read_only_user, @project_member)
      @browser.click_and_wait("link=Remove")
      assert_current_url("/projects/#{@project.identifier}/team/destroy")      
      click_cancel_button
      assert_users_checked_in_team_list(@mingle_admin, @read_only_user, @project_member)
      assert_users_unchecked_in_team_list(@project_admin)
   end

end
