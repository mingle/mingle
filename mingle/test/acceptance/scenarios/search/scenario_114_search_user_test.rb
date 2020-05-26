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

# Tags: user, search
class Scenario114SearchUserTest < ActiveSupport::TestCase

  fixtures :users, :login_access

   ALIEN_USER= "Alien_user"
   SEARCH_FOR_USER='Search for user...'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @mingle_admin = users(:admin)
    @project_admin = users(:proj_admin)
    @team_member = users(:project_member)
    @read_only_user = users(:bob)
    @user_with_html = users(:user_with_html)
    @user_with_quotes = users(:user_with_quotes)
    @existingbob = users(:existingbob)
    @longbob = users(:longbob)
    @capitalized = users(:capitalized)
    @first = users(:first)
    @special_user = users(:admin_with_name_different_than_email_address)
    @project = create_project(:prefix => 'scenario_109_project', :users => [@team_member, @first], :admins => [@mingle_admin, @project_admin], :read_only_users => [@read_only_user])
    login_as_admin_user
  end

  #story 10148

  def test_proj_admin_can_search_user_on_user_list
    project_one = create_project(:prefix => "proj_one", :admins => [@project_admin], :users => [@team_member])
    login_as_proj_admin_user
    navigate_to_user_management_page
    search_user_in_user_management_page(@read_only_user.login)
    assert_search_info_message_contains("Search results for #{@read_only_user.login}")
    assert_users_are_present(@read_only_user)
  end

  #bug 5572
  def test_I_should_get_redirectd_to_all_user_list_if_I_created_one_user_from_New_User_link_on_user_search_page
    navigate_to_user_management_page
    search_user_in_user_management_page(@special_user.name)
    assert_search_user_result_info_present(@special_user.name)
    assert_user_is_in_user_management_page(@special_user)
    assert_users_are_not_in_user_management_page(@mingle_admin, @project_admin, @team_member, @read_only_user, @user_with_quotes, @user_with_html, @existingbob, @longbob, @capitalized, @first)
    click_link('New user')
    complete_new_user_fields('new@gmail.com', 'abc-123')
    click_create_profile_button
    assert_full_user_successfully_created_notice_present
    assert_search_user_result_info_not_present(@special_user.name)
    new_user = find_user_by_name('new@gmail.com')
    assert_users_are_in_user_management_page(@special_user, @mingle_admin, @project_admin, @team_member, @read_only_user, @user_with_quotes, @user_with_html, @existingbob, @longbob, @capitalized, @first, new_user)
  end

  def test_can_search_one_user_by_full_name
    navigate_to_user_management_page
    search_user_in_user_management_page(@special_user.name)
    assert_text_present("Search result for #{@special_user.name}")
    assert_user_is_in_user_management_page(@special_user)
    assert_users_are_not_in_user_management_page(@mingle_admin, @project_admin, @team_member, @read_only_user, @user_with_quotes, @user_with_html, @existingbob, @longbob, @capitalized, @first)
  end

  def test_can_search_one_user_by_email_address
    navigate_to_user_management_page
    search_user_in_user_management_page(@special_user.email)
    assert_text_present("Search result for #{@special_user.email}")
    assert_user_is_in_user_management_page(@special_user)
    assert_users_are_not_in_user_management_page(@mingle_admin, @project_admin, @team_member, @read_only_user, @user_with_quotes, @user_with_html, @existingbob, @longbob, @capitalized, @first)
  end

  def test_can_search_one_user_by_login_name
    navigate_to_user_management_page
    search_user_in_user_management_page(@special_user.login)
    assert_text_present("Search result for #{@special_user.login}")
    assert_user_is_in_user_management_page(@special_user)
    assert_users_are_not_in_user_management_page(@mingle_admin, @project_admin, @team_member, @read_only_user, @user_with_quotes, @user_with_html, @existingbob, @longbob, @capitalized, @first)
  end

  def test_can_search_one_user_by_version_control_user_name
    navigate_to_user_management_page
    search_user_in_user_management_page(@special_user.version_control_user_name)
    assert_text_present("Search result for #{@special_user.version_control_user_name}")
    assert_user_is_in_user_management_page(@special_user)
    assert_users_are_not_in_user_management_page(@mingle_admin, @project_admin, @team_member, @read_only_user, @user_with_quotes, @user_with_html, @existingbob, @longbob, @capitalized, @first)
  end

  def test_provide_no_result_message_if_search_did_not_match_any_users_and_clicking_show_all_users_button_will_return_all_users
    navigate_to_user_management_page
    search_user_in_user_management_page(ALIEN_USER)
    assert_text_present("Your search for #{ALIEN_USER} did not match any users.")
    @browser.assert_text_not_present("Search result for #{ALIEN_USER}")
    assert_users_are_not_in_user_management_page(@special_user, @mingle_admin, @project_admin, @team_member, @read_only_user, @user_with_quotes, @user_with_html, @existingbob, @longbob, @capitalized, @first)

    show_all_users
    assert_users_are_in_user_management_page(@special_user, @mingle_admin, @project_admin, @team_member, @read_only_user, @user_with_quotes, @user_with_html, @existingbob, @longbob, @capitalized, @first)
  end

  #bug 5565
  def test_search_for_Search_for_user_should_not_return_all_users
    navigate_to_user_management_page
    search_user_in_user_management_page(SEARCH_FOR_USER)
    assert_text_present("Your search for #{SEARCH_FOR_USER} did not match any users.")
    assert_users_are_not_in_user_management_page(@special_user, @mingle_admin, @project_admin, @team_member, @read_only_user, @user_with_quotes, @user_with_html, @existingbob, @longbob, @capitalized, @first)
  end

  def test_users_in_search_result_should_have_the_same_actions_availabe_to_them_as_when_they_were_shown_in_the_full_list
    navigate_to_user_management_page
    search_user_in_user_management_page(@project_admin.name)
    assert_light_user_check_box_present_for(@project_admin)
    assert_administrator_check_box_present_for(@project_admin)
    assert_activate_deactivate_link_present_for(@project_admin)
    assert_show_profile_link_present_for(@project_admin)
    assert_change_password_link_present_for(@project_admin)
  end
  # story #8990
  def test_search_team_member_on_team_list_page
    login_as_team_member
    navigate_to_team_list_for(@project)
    search_user_in_user_management_page(@read_only_user.login)
    assert_search_info_message_contains("Search result for #{@read_only_user.login}")
    assert_users_are_present(@read_only_user)
  end

  def test_update_team_member_role_will_not_lose_current_search
    login_as_proj_admin_user
    navigate_to_team_list_for(@project)
    search_user_in_user_management_page(@team_member.login)
    make_project_admin(@team_member)
    assert_text_in_user_search_text_box(@team_member.login)
  end

  private

  def login_as_team_member
    login_as("#{@team_member.login}")
  end
end
