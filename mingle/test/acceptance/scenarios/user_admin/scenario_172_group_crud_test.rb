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
# Tags: user, group
class Scenario172GroupsCrudTest < ActiveSupport::TestCase 
  fixtures :users, :login_access

    def setup
      destroy_all_records(:destroy_users => false, :destroy_projects => true)
      @browser = selenium_session
      @project = create_project(:prefix => "sc172", :admins => [users(:proj_admin)], :users => [users(:project_member)], :read_only_users => [users(:read_only_user)])
      login_as_proj_admin_user
    end

    def test_admin_can_create_groups
      navigate_to_group_list_page(@project)
      create_a_group('BA Group')
      create_a_group('QA Group')
      assert_group_name(1, 'BA Group')
      assert_group_name(2, 'QA Group')       
    end      

    def test_admin_can_delete_groups
      navigate_to_group_list_page(@project)
      create_a_group('BA Group')
      create_a_group('QA Group')
      delete_group(@project, 'BA Group')
      @browser.assert_text_not_present_in('project_groups', "BA Group")

      delete_group(@project, 'QA Group')
      @browser.assert_text_not_present_in('project_groups', "QA Group")
    end

    def test_delete_a_group_and_create_same_name_group
      navigate_to_group_list_page(@project)
      create_a_group("BA Group")
      navigate_to_team_list_for(@project)
      select_team_members(users(:proj_admin), users(:project_member))
      click_groups_button
      click_group_name_in_droplist(0)
      click_apply_group_memberships_button
      navigate_to_group_list_page(@project)
      assert_numbers_of_users_in_group(0, 2)
      delete_group(@project, "BA Group")
      click_continue_to_delete_link
      create_a_group("BA Group")
      assert_numbers_of_users_in_group(0, "0")
    end
    
    def test_show_warning_message_if_there_are_users_in_group
      create_group_and_add_its_members("BA Group", [users(:proj_admin), users(:project_member)])
      navigate_to_group_list_page(@project)
      delete_group(@project, "BA Group")
      @browser.assert_text_present_in("group_membership_deletion_warning", "2 team members will lose their group membership.")
      @browser.assert_text_present_in("transitions_affected_warning", "Used by no transitions.")
    end
    
    def test_show_warning_message_if_there_are_tied_transtions
      setup_property_definitions("status" => ["new", "open"])
      group = create_group("BA Group")
      transition_for_QAs = create_transition_for(@project, 'transition for QAs', :set_properties => {"status" => "new"}, :for_groups => [group])
      navigate_to_group_list_page(@project)
      delete_group(@project, "BA Group")
      @browser.assert_text_present_in("group_membership_deletion_warning", "no team members will lose their group membership.")
      @browser.assert_text_present_in("transitions_affected_warning", "Used by 1 transition.")
    end

    def test_admin_can_edit_group_name
      navigate_to_group_list_page(@project)
      create_a_group('Awesome Group')
      click_group_name_on_group_list_page('Awesome Group')
      change_group_name_to('Lame Group')
      @browser.assert_text_not_present "Awesome Group"
      @browser.assert_text_present "Lame Group"
    end
    
    def test_cannot_edit_group_name_to_be_blank
      navigate_to_group_list_page(@project)
      create_a_group('Group One')
      click_group_name_on_group_list_page('Group One')   
      change_group_name_to('') 
      assert_error_message("Name cannot be blank.")
      cancel_edit
      @browser.assert_text_present 'Group One'
    end

    def test_anonymous_cannot_create_or_edit_group
      register_license_that_allows_anonymous_users
      login_as_admin_user
      @project.update_attributes(:anonymous_accessible => true)
      navigate_to_group_list_page(@project)
      create_a_group('BA Group')
      logout
      navigate_to_group_list_page(@project)
      assert_cannot_create_a_group
      assert_edit_group_button_not_present
    end
    
    def test_full_member_cannot_delete_group
      login_as_admin_user
      navigate_to_group_list_page(@project)
      create_a_group('BA Group')
      
      login_as_project_member
      navigate_to_group_list_page(@project)
      assert_cannot_see_delete_a_group_link(@project, 'BA Group')
    end
    
    def test_users_but_admin_can_view_group_but_cannot_edit
      login_as_admin_user
      create_a_group_for_project(@project, "New Group")
      
      login_as_read_only_user
      open_group(@project, "New Group")
      assert_edit_group_button_not_present
      
      login_as_project_member
      open_group(@project, "New Group")
      assert_edit_group_button_not_present
    end    
    
    def test_cannot_create_duplicate_group
      navigate_to_group_list_page(@project)
      create_a_group('BA Group')
      @browser.type('group_name', 'bA Group')
      @browser.click_and_wait('submit-quick-add')
      
      assert_error_message('Name has already been taken')
    end
    
    def test_group_name_cannot_be_blank
      navigate_to_group_list_page(@project)
      @browser.click_and_wait('submit-quick-add')
      
      assert_error_message("Name cannot be blank.")
    end
    
    def test_group_name_cannot_be_created_with_comma
      navigate_to_group_list_page(@project)
      create_a_group("foo, bar")
      assert_error_message("Name cannot contain comma.")
    end

    def test_group_name_cannot_be_edited_with_comma
      navigate_to_group_list_page(@project)
      create_a_group('Group One')
      click_group_name_on_group_list_page('Group One')
      change_group_name_to("Group ,")
      assert_error_message("Name cannot contain comma.")
      cancel_edit
      @browser.assert_text_present 'Group One'
    end    

    def test_correct_groups_page_headers
      navigate_to_group_list_page(@project)
      @browser.assert_text_present_in(class_locator('main_inner'), "#{@project.name} user groups")
      assert_table_column_headers_and_order('project_groups', 'Group name', 'Number of users')
    end
    
    def test_group_names_are_smart_sorted
      navigate_to_group_list_page(@project)
      create_a_group('z group')
      create_a_group('123 group')
      create_a_group('B group')
      assert_group_name(1, '123 group')
      assert_group_name(2, 'B group')
      assert_group_name(3, 'z group')
    end
    
    def test_messages_when_no_groups
      navigate_to_group_list_page(@project)
      @browser.assert_text_present_in('project_groups', "There are currently no groups to list.")
      create_a_group('A Group')
      delete_group(@project, 'A Group')
      @browser.assert_text_present_in('project_groups', "There are currently no groups to list.")
    end
    
    def test_show_user_count_in_groups_page
      navigate_to_group_list_page(@project)
      create_a_group("456 Group")
      navigate_to_team_list_for(@project)
      select_team_members(users(:proj_admin), users(:project_member))
      click_groups_button
      click_group_name_in_droplist(0)
      click_apply_group_memberships_button
      navigate_to_group_list_page(@project)
      assert_numbers_of_users_in_group(0, 2)
    end
    
    def test_no_groups_column_on_edit_group_page
      navigate_to_group_list_page(@project)
      create_a_group('Grouper')
      click_group_name_on_group_list_page('Grouper')
      @browser.assert_text_not_present_in('group-members', 'Groups')
    end    
    
    def test_show_back_to_groups_list_button_when_user_go_individual_group_via_groups_page
      group = create_group("New Group")
      open_group(@project, "New Group")
      assert_back_to_groups_list_button_present
      click_back_to_groups_list_button
      assert_location_url("/projects/#{@project.identifier}/groups")
    end
    
    # def test_show_back_to_groups_list_button_when_user_go_individual_group_via_groups_page
    #   group = create_group("New Group")
    #   open_group(@project, "New Group")
    #   assert_back_to_groups_list_button_present
    #   click_back_to_groups_list_button
    #   assert_location_url("/projects/#{@project.identifier}/groups")
    # end
      
end
