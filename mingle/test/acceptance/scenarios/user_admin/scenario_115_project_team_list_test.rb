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
class Scenario115ProjectTeamListTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @mingle_admin = users(:admin_not_on_project)
    @admin_user = users(:admin)
    @project_admin_user = users(:proj_admin)
    @read_only_user = users(:existingbob)
    @team_member = users(:first)
    @project = create_project(:prefix => 'scenario_115', :users => [@team_member], :admins => [@project_admin_user], :read_only_users => [@read_only_user])
  end



  # test for story "Auto Enroll all users as team members"
  def test_only_admin_can_turn_on_or_off_auto_enroll
    login_as_team_member
    navigate_to_team_list_for(@project)
    assert_enable_auto_enroll_button_is_not_present

    login_as_project_admin
    navigate_to_team_list_for(@project)
    assert_enable_auto_enroll_button_is_present
    auto_enroll_all_users_as_full_users(@project)
    assert_disable_auto_enroll_button_is_present
    assert_member_can_not_be_removed
    assert_add_team_member_disabled

    login_as_team_member
    navigate_to_team_list_for(@project)
    assert_disable_auto_enroll_button_is_not_present
    assert_remove_user_link_is_not_present

    login_as_mingle_admin
    navigate_to_team_list_for(@project)
    assert_disable_auto_enroll_button_is_present
    disable_auto_enroll_all_user(@project)
    assert_enable_auto_enroll_button_is_present
    assert_member_can_be_removed
    assert_add_team_member_enabled

    login_as_team_member
    navigate_to_team_list_for(@project)
    assert_enable_auto_enroll_button_is_not_present
  end

  def test_auto_enroll_user_as_full_team_member_on_full_user_and_light_user
    login_as_mingle_admin
    navigate_to_user_management_page
    light_user = users(:bob)
    check_light_user_check_box_for(light_user)
    full_user = users(:longbob)
    navigate_to_team_list_for(@project)
    assert_user_is_not_team_member(light_user)
    assert_user_is_not_team_member(full_user)

    auto_enroll_all_users_as_full_users(@project)
    assert_user_is_read_only_team_member(light_user)
    assert_user_is_normal_team_member(full_user)
  end

  def test_auto_enroll_user_as_readonly_team_member_on_full_user_and_light_user
    login_as_mingle_admin
    navigate_to_user_management_page
    light_user = users(:bob)
    check_light_user_check_box_for(light_user)
    full_user = users(:longbob)
    navigate_to_team_list_for(@project)
    assert_user_is_not_team_member(light_user)
    assert_user_is_not_team_member(full_user)
    auto_enroll_all_users_as_readonly_users(@project)
    navigate_to_team_list_for(@project)
    assert_user_is_read_only_team_member(light_user)
    assert_user_is_read_only_team_member(full_user)
  end

  def test_auto_enroll_as_full_team_member_should_not_change_previous_user_role
    login_as_project_admin
    auto_enrolled_user = users(:longbob)
    navigate_to_team_list_for(@project)
    assert_user_is_normal_team_member(@team_member)
    assert_user_is_read_only_team_member(@read_only_user)
    assert_user_is_project_admin(@project_admin_user)
    auto_enroll_all_users_as_full_users(@project)
    assert_user_is_normal_team_member(@team_member)
    assert_user_is_read_only_team_member(@read_only_user)
    assert_user_is_project_admin(@project_admin_user)
  end

  def test_auto_enroll_as_readonly_team_member_should_not_change_previous_user_role
    login_as_project_admin
    auto_enrolled_user = users(:longbob)
    navigate_to_team_list_for(@project)
    assert_user_is_normal_team_member(@team_member)
    assert_user_is_read_only_team_member(@read_only_user)
    assert_user_is_project_admin(@project_admin_user)
    auto_enroll_all_users_as_readonly_users(@project)
    assert_user_is_normal_team_member(@team_member)
    assert_user_is_read_only_team_member(@read_only_user)
    assert_user_is_project_admin(@project_admin_user)
  end

  def test_full_team_membered_auto_enrolled_should_be_able_to_switch_to_other_role
    login_as_project_admin
    auto_enrolled_user = users(:longbob)
    navigate_to_team_list_for(@project)
    auto_enroll_all_users_as_full_users(@project)
    assert_user_is_normal_team_member(auto_enrolled_user)
    make_project_admin(auto_enrolled_user)
    assert_user_is_project_admin(auto_enrolled_user)
    make_read_only(auto_enrolled_user)
    assert_user_is_read_only_team_member(auto_enrolled_user)
    make_full_member(auto_enrolled_user)
    assert_user_is_normal_team_member(auto_enrolled_user)
  end

  def test_read_only_team_membered_auto_enrolled_should_be_able_to_switch_to_other_role
    login_as_project_admin
    auto_enrolled_user = users(:longbob)
    navigate_to_team_list_for(@project)
    auto_enroll_all_users_as_readonly_users(@project)
    assert_user_is_read_only_team_member(auto_enrolled_user)
    make_project_admin(auto_enrolled_user)
    assert_user_is_project_admin(auto_enrolled_user)
    make_full_member(auto_enrolled_user)
    assert_user_is_normal_team_member(auto_enrolled_user)
    make_read_only(auto_enrolled_user)
    assert_user_is_read_only_team_member(auto_enrolled_user)
  end


  def test_newly_added_users_should_be_auto_enrolled_only_when_auto_enroll_is_on
    login_as_mingle_admin
    auto_enroll_all_users_as_full_users(@project)
    navigate_to_user_management_page
    click_new_user_link
    new_user = add_new_user("new_user@gmail.com", "password1.")
    navigate_to_team_list_for(@project)
    assert_user_is_team_member(new_user)

    disable_auto_enroll_all_user(@project)
    navigate_to_user_management_page
    click_new_user_link
    new_user_2 = add_new_user("new_user_2@gmail.com", "password1.")
    navigate_to_team_list_for(@project)
    assert_user_is_not_team_member(new_user_2)


    auto_enroll_all_users_as_readonly_users(@project)
    navigate_to_user_management_page
    click_new_user_link
    new_user_3 = add_new_user("new_user_3@gmail.com", "password1.")
    navigate_to_team_list_for(@project)
    assert_user_is_read_only_team_member(new_user_3)
  end

  def test_project_admin_can_add_team_member_as_read_only_or_full_user
    login_as_project_admin
    navigate_to_team_list_for(@project)
    click_add_team_member_link_on_team_member_list
    show_all_users
    assert_add_full_and_readonly_member_link_present_for(@admin_user)
    click_add_to_team_link_on_all_member_list(@admin_user)
    click_back_to_team_list
    assert_user_is_normal_team_member(@admin_user)
    remove_from_team_for(@project, @admin_user, :update_permanently => true)
    click_add_team_member_link_on_team_member_list
    show_all_users
    click_add_readonly_to_team_link_on_all_member_list(@admin_user)
    click_back_to_team_list
    assert_user_is_read_only_team_member(@admin_user)
  end

  def test_light_user_can_be_only_added_as_read_only
    login_as_mingle_admin
    navigate_to_team_list_for(@project)
    click_add_team_member_link_on_team_member_list
    show_all_users
    assert_add_full_and_readonly_member_link_present_for(@admin_user)
    navigate_to_user_management_page
    check_light_user_check_box_for(@admin_user)
    navigate_to_team_list_for(@project)
    click_add_team_member_link_on_team_member_list
    show_all_users
    assert_only_add_readonly_member_link_present_for(@admin_user)
  end

  def test_project_admin_can_update_team_member_to_read_only
    login_as_project_admin
    navigate_to_team_list_for(@project)
    assert_user_is_normal_team_member(@team_member)
    assert_read_only_team_member_check_box_enabled_for(@team_member)
    make_read_only(@team_member)
    assert_user_is_read_only_team_member(@team_member)
    assert_notice_message("#{@team_member.name} is now a read only team member")
  end

  def test_project_admin_can_update_read_only_to_normal_team_member
    make_team_member_as_read_only
    assert_user_is_read_only_team_member(@team_member)
    make_full_member(@team_member)
    assert_user_is_normal_team_member(@team_member)
    assert_notice_message("#{@team_member.name} is now a team member")
  end

  def test_project_admin_can_update_project_admin_to_normal_team_member
    make_team_member_as_project_admin
    assert_user_is_project_admin(@team_member)
    make_full_member(@team_member)
    assert_user_is_normal_team_member(@team_member)
    assert_notice_message("#{@team_member.name} is now a team member")
  end

  def test_project_admin_can_update_team_member_to_project_admin
    login_as_project_admin
    navigate_to_team_list_for(@project)
    assert_user_is_normal_team_member(@team_member)
    assert_project_admin_check_box_enabled_for(@team_member)
    make_project_admin(@team_member)
    assert_user_is_project_admin(@team_member)
    assert_notice_message("#{@team_member.name} is now a project administrator")
  end

  def test_project_admin_can_switch_other_project_admin_to_read_only
    make_team_member_as_project_admin
    assert_user_is_project_admin(@team_member)
    make_read_only(@team_member)
    assert_user_is_read_only_team_member(@team_member)
    assert_notice_message("#{@team_member.name} is now a read only team member")
  end

  def test_project_admin_can_add_team_member
    login_as_project_admin
    navigate_to_team_list_for(@project)
    assert_user_is_not_team_member(@admin_user)
    assert_add_team_member_link_present

    add_full_member_to_team_for(@project, @admin_user,:back_to_team_list => false,:already_on_team_page => true)
    assert_notice_message("#{@admin_user.name} has been added to the #{@project.identifier} team successfully")
    click_back_to_team_list
    assert_user_is_team_member(@admin_user)
  end

  def test_project_admin_can_remove_team_member
    login_as_project_admin
    navigate_to_team_list_for(@project)
    assert_user_is_team_member(@team_member)
    click_add_team_member_link_on_team_member_list
    show_all_users
    assert_add_to_team_link_not_present_for(@team_member)

    click_back_to_team_list
    assert_member_can_be_removed
    remove_from_team_for(@project, @team_member, :update_permanently => true)
    assert_notice_message("1 member has been removed from the #{@project.identifier} team successfully")
    assert_user_is_not_team_member(@team_member)

    navigate_to_team_list_for(@project)
    click_add_team_member_link_on_team_member_list
    show_all_users
    assert_add_full_and_readonly_member_link_present_for(@team_member)
  end

  def test_project_admin_can_cancel_or_confirm_remove_team_member
    login_as_project_admin
    user_property_name = 'owner'
    setup_user_definition(user_property_name)
    transition_setting_user_property = create_transition_for(@project, 'setting only user property', :set_properties => {user_property_name => @team_member.name})
    navigate_to_team_list_for(@project)
    assert_user_is_team_member(@team_member)

    remove_from_team_for(@project, @team_member, :update_permanently => false)
    assert_warning_box_message("1 Transition Deleted: #{transition_setting_user_property.name}.")
    click_cancel_link
    assert_user_is_team_member(@team_member)

    remove_from_team_for(@project, @team_member, :update_permanently => false)
    assert_warning_box_message("1 Transition Deleted: #{transition_setting_user_property.name}.")
    click_continue_to_remove
    assert_notice_message("1 member has been removed from the #{@project.identifier} team successfully")
    assert_user_is_not_team_member(@team_member)
  end

  # bug 1097
  def test_project_admin_cannot_remove_themselves_from_team_or_as_admin
    login_as_project_admin
    navigate_to_team_list_for(@project)
    assert_user_is_project_admin(@project_admin_user)

    select_team_members(@project_admin_user)
    @browser.click("link=Remove")
    assert_error_message 'Cannot remove yourself from team'

    navigate_to_team_list_for(@project)
    assert_user_is_project_admin(@project_admin_user)
  end

  def test_non_project_admin_can_not_add_remove_update_team_member
    login_as_team_member
    navigate_to_team_list_for(@project)
    assert_add_team_member_link_not_present
    assert_users_not_editable_or_removable(@project_admin_user,@team_member)

    make_team_member_as_read_only
    login_as_team_member
    navigate_to_team_list_for(@project)
    assert_add_team_member_link_not_present
    assert_users_not_editable_or_removable(@project_admin_user,@team_member)
  end

  def test_mingle_admin_can_add_and_update_team_member
    login_as_mingle_admin
    navigate_to_team_list_for(@project)
    assert_add_team_member_link_present
    assert_users_editable_and_removable(@project_admin_user,@team_member)
  end

  private

  def login_as_mingle_admin
    login_as("#{@mingle_admin.login}")
  end

  def login_as_project_admin
    login_as("#{@project_admin_user.login}")
  end

  def login_as_team_member
    login_as("#{@team_member.login}")
  end

  def make_team_member_as_read_only
    login_as_project_admin
    navigate_to_team_list_for(@project)
    make_read_only(@team_member)
  end

  def make_team_member_as_project_admin
    login_as_project_admin
    navigate_to_team_list_for(@project)
    make_project_admin(@team_member)
  end

end
