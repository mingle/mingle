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
#Tags: mingle_admin
class Scenario176AddUserToMultipleProjectsFromProfilePageTest < ActiveSupport::TestCase
  fixtures :users, :login_access
  PROJECT_ADMINISTRATOR = "Project administrator"
  TEAM_MEMBER = "Team member"
  READ_ONLY_TEAM_MEMBER = "Read only team member"

  def setup
     destroy_all_records(:destroy_users => false, :destroy_projects => true)
     @mingle_admin = users(:admin)
     @project_admin = users(:proj_admin)
     @project_member = users(:project_member)
     @read_only_user = users(:read_only_user)
     @browser = selenium_session
  end

  # story 10148
  def test_proj_admin_can_open_user_profile_from_users_list_page
    project_one = create_project(:prefix => "proj_one", :admins => [@project_admin], :users => [@project_member])
    login_as_proj_admin_user

    open_mingle_admin_dropdown
    @browser.assert_text_present "Manage users"
    assert_link_present("/users/list")
    @browser.click_and_wait("link=Manage users")

    click_user_display_name(@project_member)
    assert_user_profile_is_opened(@project_member)
    assert_user_profile_in_show_mode
  end

  def test_proj_admin_cannot_modify_user_on_users_list
    project_one = create_project(:prefix => "proj_one", :admins => [@project_admin], :users => [@project_member])
    login_as_proj_admin_user

    project_one.with_active_project do |project|
      @browser.open("/users/list")
      assert_new_user_link_not_present
      assert_admin_check_box_disabled_for(@read_only_user)
      assert_light_check_box_disabled_for(@read_only_user)
      assert_activate_deactivate_link_not_present_for(@read_only_user)
      assert_change_password_link_not_present
    end
  end

  def test_non_admin_users_have_no_access_to_uses_list
    project_one = create_project(:prefix => "proj_one", :admins => [@project_admin], :users => [@project_member])
    login_as_project_member

    @browser.assert_text_not_present "Manage users"
    assert_link_not_present("/users/list")
  end

  def test_mingle_admin_can_open_user_profile_on_team_members_list
    project_one = create_project(:prefix => "proj_one", :admins => [@project_admin], :users => [@project_member])
    login_as_admin_user
    navigate_to_team_list_for(project_one)
    click_user_display_name(@project_member)
    assert_user_profile_is_opened(@project_member)
    assert_user_profile_in_full_control_mode
  end

  def test_proj_admin_can_open_team_member_profile
    project_one = create_project(:prefix => "proj_one", :admins => [@project_admin], :users => [@project_member])
    login_as_proj_admin_user
    navigate_to_team_list_for(project_one)
    click_user_display_name(@project_member)
    assert_user_profile_is_opened(@project_member)
    assert_user_profile_in_show_mode
  end

  def test_proj_admin_can_add_users_to_projects_he_is_admin_of
    project_one = create_project(:prefix => "proj_one", :admins => [@project_admin], :users => [@project_member])
    project_two = create_project(:prefix => "proj_two", :admins => [@project_admin])
    project_three = create_project(:prefix => "proj_three", :admins => [@project_admin])
    project_four = create_project(:prefix => "proj_four")

    login_as_proj_admin_user
    navigate_to_team_list_for(project_one)
    click_user_display_name(@project_member)

    click_add_to_projects_button
    open_select_project_droplist(0)
    assert_project_names_present_in_droplist(0, project_two, project_three)
    assert_project_names_not_present_in_droplist(0, project_four, project_one)
    select_project_from_droplist(0, project_two, false)

    click_add_another_project_button
    open_select_project_droplist(1)
    assert_project_names_present_in_droplist(1, project_three)
    assert_project_names_not_present_in_droplist(1, project_four, project_one, project_two)
    select_project_from_droplist(1, project_three, false)

    assert_add_another_project_button_is_disabled
    assign_project_to_the_user

    assert_table_cell(0, 3, 0, project_three.name)
    assert_table_cell(0, 4, 0, project_two.name)
  end

  def test_proj_admin_can_set_membership_type_when_add_user_to_projects
    project_one = create_project(:prefix => "proj_one", :admins => [@project_admin], :users => [@project_member])
    project_two = create_project(:prefix => "proj_two", :admins => [@project_admin])
    project_three = create_project(:prefix => "proj_three", :admins => [@project_admin])

    login_as_proj_admin_user
    navigate_to_team_list_for(project_one)
    click_user_display_name(@project_member)

    click_add_to_projects_button
    select_project_from_droplist(0, project_two)
    select_membership_type_from_droplist(0, READ_ONLY_TEAM_MEMBER)

    click_add_another_project_button
    select_project_from_droplist(1, project_three)
    select_membership_type_from_droplist(1, PROJECT_ADMINISTRATOR)
    assign_project_to_the_user

    login_as_project_member

    navigate_to_all_projects_page
    assert_project_links_present(project_one, project_two, project_three)

    navigate_to_team_list_for(project_two)
    assert_user_is_read_only_team_member(@project_member)
    navigate_to_team_list_for(project_three)
    assert_user_is_project_admin(@project_member)
  end

  def test_proj_admin_can_only_see_projects_he_is_admin_of_on_other_user_profile
    project_one = create_project(:prefix => "proj_one", :admins => [@project_admin], :users => [@project_member])
    project_two = create_project(:prefix => "proj_two", :users => [@project_member])

    login_as_proj_admin_user
    navigate_to_team_list_for(project_one)
    click_user_display_name(@project_member)
    assert_table_cell(0, 2, 0, project_one.name)
    @browser.assert_text_not_present_in("projects_content", project_two.name)

    project_three = create_project(:prefix => "proj_three", :admins => [@project_admin], :users => [@project_member])
    with_ajax_wait { reload_current_page }
    assert_table_cell(0, 3, 0, project_three.name)

    add_to_team_as_project_admin_via_model_for(project_two, @project_admin)
    with_ajax_wait { reload_current_page }

    assert_table_cell(0, 4, 0, project_two.name)
  end

  def test_add_to_projects_button_disabled_if_user_belongs_to_all_projects_proj_admin_is_admin_of
    project_one = create_project(:prefix => "proj_one", :admins => [@project_admin], :users => [@project_member])
    project_two = create_project(:prefix => "proj_two", :admins => [@project_admin])

    as_user('proj_admin') do
      navigate_to_team_list_for(project_one)
      click_user_display_name(@project_member)

      assert_add_to_projects_button_is_enabled
      click_add_to_projects_button
      select_project_from_droplist(0, project_two)
      assign_project_to_the_user
      assert_add_to_projects_button_is_disabled

      remove_several_users_from_team_permanently(project_two, @project_member)
      navigate_to_team_list_for(project_one)
      click_user_display_name(@project_member)

      assert_add_to_projects_button_is_enabled
    end
  end

  def test_the_add_project_assignment_button_is_invisible_for_non_mingle_admins
    project_one = create_project(:prefix => "proj_one")
    project_two = create_project(:prefix => "proj_two")
    login_as_proj_admin_user
    go_to_profile_page
    assert_add_to_projects_button_is_not_present
    login_as_project_member
    go_to_profile_page
    assert_add_to_projects_button_is_not_present
    login_as_read_only_user
    go_to_profile_page
    assert_add_to_projects_button_is_not_present
  end

  def test_proj_admin_has_full_control_when_opens_own_profile_from_team_members_list
    project_one = create_project(:prefix => "proj_one", :admins => [@project_admin], :users => [@project_member])
    login_as_proj_admin_user
    navigate_to_team_list_for(project_one)
    click_user_display_name(@project_admin)
    assert_user_profile_is_opened(@project_admin)
    assert_user_profile_in_full_control_mode
    assert_add_to_projects_button_is_disabled
  end

  def test_mingle_admin_can_add_user_to_multiple_projects_via_users_profile
    project_one = create_project(:prefix => "proj_one", :admins => [@mingle_admin, @project_admin], :read_only_users => [@read_only_user])
    project_two = create_project(:prefix => "proj_two", :admins => [@mingle_admin, @project_admin], :users => [@project_member])
    project_three = create_project(:prefix => "proj_three", :admins => [@project_admin])
    login_as_admin_user
    open_show_profile_for(@project_member)

    click_add_to_projects_button
    select_project_from_droplist(0, project_one)
    click_add_another_project_button

    select_project_from_droplist(1, project_three)
    assign_project_to_the_user
    @browser.assert_text_present("#{@project_member.name} has been added to projects #{project_one.name} and #{project_three.name} successfully.")
    assert_table_cell(0, 2, 0, project_one.name)
    assert_table_cell(0, 2, 1, "Team member")
    assert_table_cell(0, 3, 0, project_three.name)
    assert_table_cell(0, 3, 1, "Team member")
  end

  def test_light_user_can_only_be_added_to_one_project_as_read_only_user
    project_one = create_project(:prefix => "proj_one", :admins => [@mingle_admin, @project_admin], :read_only_users => [@read_only_user])
    project_two = create_project(:prefix => "proj_two", :admins => [@mingle_admin, @project_admin], :users => [@project_member])
    login_as_admin_user
    navigate_to_user_management_page
    check_light_user_check_box_for(@read_only_user)
    open_show_profile_for(@read_only_user)
    click_add_to_projects_button
    assert_membership_is_selected_from_droplist(0, "Read only team member")

    select_project_from_droplist(0, project_two)
    assign_project_to_the_user
    @browser.assert_text_present("#{@read_only_user.name} has been added to project #{project_two.name} successfully.")
    assert_table_cell(0, 3, 0, project_two.name)
    assert_table_cell(0, 3, 1, "Read only team member")
    assert_table_cell(0, 2, 0, project_one.name)
    assert_table_cell(0, 2, 1, "Read only team member")
  end

  def test_admin_can_add_or_remove_project_assignment_via_project_assignment_lightbox
    project_one = create_project(:prefix => "proj_one", :admins => [@mingle_admin, @project_admin], :read_only_users => [@read_only_user])
    project_two = create_project(:prefix => "proj_two", :admins => [@mingle_admin, @project_admin], :users => [@project_member])
    login_as_admin_user
    open_show_profile_for(@project_member)
    click_add_to_projects_button
    assert_add_another_project_button_is_disabled
    click_the_remove_link(0)
    assert_add_to_projects_button_is_enabled
    click_add_another_project_button
    select_project_from_droplist(1, project_one)
    assert_add_another_project_button_is_disabled

    click_the_remove_link(1)
    click_add_another_project_button

    select_project_from_droplist(2, project_one)
    assert_add_another_project_button_is_disabled
    assign_project_to_the_user
    @browser.assert_text_present("#{@project_member.name} has been added to project #{project_one.name} successfully.")
  end

  def test_add_project_assignment_button_is_disabled_when_user_already_belongs_to_all_projects
    project_one = create_project(:prefix => "proj_one", :admins => [@mingle_admin, @project_admin], :users => [@project_member], :read_only_users => [@read_only_user])
    project_two = create_project(:prefix => "proj_two", :admins => [@mingle_admin, @project_admin], :users => [@project_member], :read_only_users => [@read_only_user])
    login_as_admin_user
    go_to_profile_page
    assert_add_to_projects_button_is_disabled
    open_show_profile_for(@project_member)
    assert_add_to_projects_button_is_disabled
    open_show_profile_for(@read_only_user)
    assert_add_to_projects_button_is_disabled
  end

  def test_admin_can_add_project_assignment_or_modify_role_for_users
    project_one = create_project(:prefix => "proj_one")
    project_two = create_project(:prefix => "proj_two")
    project_three = create_project(:prefix => "proj_three")

    login_as_admin_user
    open_show_profile_for(@project_member)
    click_add_to_projects_button
    select_project_from_droplist(0, project_one)
    select_membership_type_from_droplist(0, PROJECT_ADMINISTRATOR)
    click_add_another_project_button

    select_project_from_droplist(1, project_three)
    select_membership_type_from_droplist(1, READ_ONLY_TEAM_MEMBER)
    assign_project_to_the_user

    @browser.assert_text_present("#{@project_member.name} has been added to projects #{project_one.name} and #{project_three.name} successfully.")
    assert_table_cell(0, 3, 0, project_three.name)
    assert_table_cell(0, 3, 1, "Read only team member")
    assert_table_cell(0, 2, 0, project_one.name)
    assert_table_cell(0, 2, 1, "Project administrator")
  end

  def test_user_should_be_able_to_login_to_the_newly_added_project
    project_one = create_project(:prefix => "proj_one", :admins => [@mingle_admin, @project_admin], :read_only_users => [@read_only_user])
    project_two = create_project(:prefix => "proj_two", :admins => [@mingle_admin, @project_admin], :users => [@project_member])
    login_as_admin_user
    open_show_profile_for(@project_member)
    click_add_to_projects_button
    select_project_from_droplist(0, project_one)
    select_membership_type_from_droplist(0, PROJECT_ADMINISTRATOR)
    assign_project_to_the_user
    login_as_project_member
    navigate_to_team_list_for(project_one)
    assert_user_is_project_admin(@project_member)
  end

  def test_stop_admin_from_trying_to_add_user_to_project_more_than_once
    project_one = create_project(:prefix => "proj_one")
    project_two = create_project(:prefix => "proj_two")
    project_three = create_project(:prefix => "proj_three")
    project_four  = create_project(:prefix => "proj_four")
    project_five  = create_project(:prefix => "proj_five")
    project_six   = create_project(:prefix => "proj_six")

    login_as_admin_user
    open_show_profile_for(@project_member)
    click_add_to_projects_button

    select_project_from_droplist(0, project_one)
    click_add_another_project_button

    open_select_project_droplist(1)
    assert_project_names_not_present_in_droplist(1, project_one)
    assert_project_names_present_in_droplist(1, project_two, project_three, project_four, project_five, project_six)

    select_project_from_droplist(1, project_two, false)
    click_add_another_project_button

    open_select_project_droplist(2)
    assert_project_names_not_present_in_droplist(2, project_one, project_two)
    assert_project_names_present_in_droplist(2, project_three, project_four, project_five, project_six)
    close_select_project_droplist(2)
  end
end
