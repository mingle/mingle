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
#Tags: user, group

class Scenario182AddAndRemoveGroupMemeberViaGroupPageTest < ActiveSupport::TestCase 
  fixtures :users, :login_access
  
  PROJECT_ADMINISTRATOR = "Project administrator"
  TEAM_MEMBER = "Team member"
  READ_ONLY_TEAM_MEMBER = "Read only team member"
   
  FIRST_GROUP="0_group"
  SECOND_GROUP="A_Group"
  THIRD_GROUP="b_Group"
  FOURTH_GROUP="C_Group"
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @project_admin_user = users(:proj_admin)
    @browser = selenium_session
    @mingle_admin = users(:admin)
    @project_admin = users(:proj_admin)
    @team_member = users(:project_member)
    @read_only_user = users(:read_only_user)
    @user1 = users(:user_with_html)
    @user2 = users(:user_with_quotes)
    @user3 = users(:bob)
    @user4 = users(:existingbob)
    @user5 = users(:longbob)
    @user6 = users(:admin_not_on_project)
    @user7 = users(:first)
    @project = create_project(:prefix => 'scenario_182', :read_only_users => [@read_only_user], :users => [@team_member, @user1, @user2, @user3, @user4, @user5, @user6, @user7], :admins => [@project_admin], :anonymous_accessible => true)
  end

  def test_add_user_to_group_from_group_page
    login_as_proj_admin_user
    create_a_group_for_project(@project, FIRST_GROUP)
    open_group(@project, FIRST_GROUP)
    click_add_group_member_button
    assert_back_to_group_button_present    
    click_add_to_group_link(@user3)
    asssert_adding_group_member_from_group_page_successfull_message_present(@user3, FIRST_GROUP)
    click_add_to_group_link(@user4)
    asssert_adding_group_member_from_group_page_successfull_message_present(@user4, FIRST_GROUP)
    open_group(@project, FIRST_GROUP)
    assert_user_is_present_in_group(FIRST_GROUP, @user3)
    assert_user_is_present_in_group(FIRST_GROUP, @user4)
    assert_table_values("group-members", 1, 1, @user3.name)
    assert_table_values("group-members", 1, 2, @user3.login)
    assert_table_values("group-members", 1, 3, @user3.email)
  end
  
  
  def test_non_admin_users_cannot_see_the_add_group_member_button
    register_license_that_allows_anonymous_users
    login_as_admin_user
    first_group = create_group_and_add_its_members(FIRST_GROUP, [@user1, @user2, @user3, @user4, @user5, @user6])
    login_as_read_only_user
    open_group(@project, FIRST_GROUP)
    assert_add_group_member_button_not_present
    login_as_project_member
    open_group(@project, FIRST_GROUP)
    assert_add_group_member_button_not_present
    logout
    open_group(@project, FIRST_GROUP)
    assert_add_group_member_button_not_present
  end
  
  def test_show_correct_page_name_on_the_adding_group_member_page
    login_as_proj_admin_user
    create_a_group_for_project(@project, FIRST_GROUP)
    open_group(@project, FIRST_GROUP)
    click_add_group_member_button
    @browser.assert_text_present("Add team member to #{FIRST_GROUP} group")
  end
  
  def test_show_notice_when_no_member_in_current_group
    login_as_proj_admin_user
    create_a_group_for_project(@project, FIRST_GROUP)
    open_group(@project, FIRST_GROUP)
    assert_no_group_memember_message_present    
  end
  
  def test_show_go_back_to_group_button
    login_as_proj_admin_user
    create_a_group_for_project(@project, FIRST_GROUP)
    open_group(@project, FIRST_GROUP)
    click_add_group_member_button
    assert_back_to_group_button_present    
    click_back_to_group_button
    assert_no_group_memember_message_present
  end
  
  def test_dont_show_the_add_to_group_link_for_user_who_already_been_added_in_group
    login_as_proj_admin_user
    create_a_group_for_project(@project, FIRST_GROUP)
    open_group(@project, FIRST_GROUP)
    click_add_group_member_button
    click_add_to_group_link(@user3)
    assert_dont_show_the_add_to_group_link_for_user_who_already_been_added_in_group(@user3)
  end
  
  def test_can_add_user_to_group_from_the_search_result
    login_as_proj_admin_user
    create_a_group_for_project(@project, FIRST_GROUP)
    open_group(@project, FIRST_GROUP)
    click_add_group_member_button
    type_search_user_text("#{@user1.name}")
    click_search_user_button
    click_add_to_group_link(@user1)
    asssert_adding_group_member_from_group_page_successfull_message_present(@user1, FIRST_GROUP)
    assert_dont_show_the_add_to_group_link_for_user_who_already_been_added_in_group(@user1)
  end
  
  def test_should_be_able_to_clear_the_search_results_and_return_to_list_of_all_team_members
    login_as_proj_admin_user
    create_a_group_for_project(@project, FIRST_GROUP)
    open_group(@project, FIRST_GROUP)
    click_add_group_member_button
    assert_users_are_present(@user1, @user2, @user3, @user4, @user5, @user6, @user7, @project_admin, @read_only_user)
    type_search_user_text("#{@user1.name}")
    click_search_user_button
    assert_users_are_present(@user1)
    assert_users_are_not_present(@user2, @user3, @user4, @user5, @user6, @user7, @project_admin, @read_only_user)
    click_clear_search_user_button
    assert_users_are_present(@user1, @user2, @user3, @user4, @user5, @user6, @user7, @project_admin, @read_only_user)
  end
  
  def test_provide_back_to_team_list_button_if_user_come_from_team_list_page
    login_as_proj_admin_user
    create_group_and_add_its_members(FIRST_GROUP, [@user1])
    navigate_to_team_list_for(@project)
    click_group_name_on_group_list_page(FIRST_GROUP)
    click_add_group_member_button
    click_back_to_group_button
    assert_back_to_team_list_button_present
  end
  
  def test_provide_back_to_group_list_button_if_user_come_from_group_page
    login_as_proj_admin_user
    create_group_and_add_its_members(FIRST_GROUP, [@user1])
    open_group(@project, FIRST_GROUP)
    click_add_group_member_button
    click_back_to_group_button
    assert_back_to_group_list_button_present    
  end
    
  def test_remove_user_from_group_via_group_page
    login_as_proj_admin_user
    create_group_and_add_its_members(FIRST_GROUP, [@user1, @user2, @user3])
    open_group(@project, FIRST_GROUP)
    select_team_members(@user1, @user2)
    click_remove_from_group_button
    assert_remove_multiple_users_from_group_successfull_message_present(2, FIRST_GROUP)
  end
  
  
  def test_the_remove_from_group_button_should_be_disabled_when_no_user_is_selected
    login_as_proj_admin_user
    create_group_and_add_its_members(FIRST_GROUP, [@user1, @user2, @user3])
    open_group(@project, FIRST_GROUP)
    assert_remove_from_group_button_is_disabled
    select_team_members(@user1)
    assert_remove_from_group_button_is_enabled
  end
  
  #Remmeber we are mocking the page size for group members in acc tests: show 3 members in each page --> check mocking.rb for more details.
  def test_remove_all_users_in_current_page_from_groups
    with_page_size(3) do
      login_as_proj_admin_user
      create_group_and_add_its_members(FIRST_GROUP, [@user1, @user2, @user3, @user4, @user5, @user6])
      open_group(@project, FIRST_GROUP)
      select_all
      click_remove_from_group_button
      assert_remove_multiple_users_from_group_successfull_message_present(3, FIRST_GROUP)
      select_all
      click_remove_from_group_button
      assert_remove_multiple_users_from_group_successfull_message_present(3, FIRST_GROUP)
      assert_no_group_memember_message_present
    end
  end
  
  def test_keep_the_pagination_in_group_member_list_when_remove_group_member
    with_page_size(3) do
      login_as_proj_admin_user
      first_group = create_group_and_add_its_members(FIRST_GROUP, [@user1, @user2, @user3, @user4, @user5, @user6])
      open_group(@project, FIRST_GROUP)
      click_next_page_link
      assert_on_the_group_member_page(@project, first_group, 2)
      select_team_members(@user1, @user2)
      click_remove_from_group_button
      assert_remove_multiple_users_from_group_successfull_message_present(2, FIRST_GROUP)
      assert_on_the_group_member_page(@project, first_group, 2)
    end
  end
  
  def test_non_admin_users_cannot_see_the_remove_group_member_button
    register_license_that_allows_anonymous_users
    login_as_admin_user
    first_group = create_group_and_add_its_members(FIRST_GROUP, [@user1, @user2, @user3, @user4, @user5, @user6])
    
    login_as_read_only_user
    open_group(@project, FIRST_GROUP)
    assert_remove_from_group_button_not_present
    
    login_as_project_member
    open_group(@project, FIRST_GROUP)
    assert_remove_from_group_button_not_present
    
    logout
    open_group(@project, FIRST_GROUP)
    assert_remove_from_group_button_not_present
  end
 end
