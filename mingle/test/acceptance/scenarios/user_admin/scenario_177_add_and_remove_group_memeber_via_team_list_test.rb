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

class Scenario177AddAndRemoveGroupMemeberViaTeamListTest < ActiveSupport::TestCase 
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
    
    @project = create_project(:prefix => 'scenario_177', :read_only_users => [@read_only_user], :users => [@team_member, @user1, @user2, @user3, @user4, @user5, @user6, @user7], :admins => [@project_admin], :anonymous_accessible => true)
  end
  
  # story 8990
  def test_add_users_to_group_from_search_result
    login_as_proj_admin_user
    create_group('BAs')
    navigate_to_team_list_for(@project)
    type_search_user_text("bob")
    click_search_user_button
    assert_users_are_present(@user4, @user5, @user3)
    
    select_team_members(@user4, @user5)
    click_groups_button  
    select_group_by_order(0)
    click_apply_group_memberships_button
    assert_text_in_user_search_text_box("bob")
    open_group(@project, "BAs")
    assert_user_is_present_in_group("BAs", @user5)
    assert_user_is_present_in_group("BAs", @user4)  
  end
    
  def test_groups_button_is_disabled_when_no_user_is_selected
    login_as_proj_admin_user
    create_group('Admin')
    navigate_to_team_list_for(@project)
    assert_groups_button_is_diabled
    select_team_members(@project_admin, @read_only_user)
    assert_groups_button_is_enabled
  end  
 
  def test_should_show_no_group_message_when_there_is_no_group
    login_as_proj_admin_user
    navigate_to_team_list_for(@project)
    assert_groups_button_is_diabled
    select_team_members(@project_admin, @read_only_user)
    click_groups_button
    assert_message_shows_in_group_selector_popup('There are currently no groups to list.')
  end
    
  def test_add_one_user_to_multiple_groups
    login_as_proj_admin_user
    create_group(FIRST_GROUP)
    create_group(SECOND_GROUP)
    create_group(THIRD_GROUP)

    navigate_to_team_list_for(@project)
    select_team_members(@project_admin)

    click_groups_button
  
    select_group_by_order(0)
    select_group_by_order(1)

    click_apply_group_memberships_button

    
    select_team_members(@project_admin)
    click_groups_button
    assert_group_fully_checked(0)
    assert_group_fully_checked(1)
  end
  
  def test_add_multiple_users_to_one_group
    login_as_proj_admin_user
    create_group(FIRST_GROUP)
    create_group(SECOND_GROUP)
    
    navigate_to_team_list_for(@project)
    select_team_members(@project_admin, @read_only_user, @team_member, @user1, @user2, @user3, @user4, @user5)
    click_groups_button
    
    select_group_by_order(0)

    click_apply_group_memberships_button
    @browser.assert_text_present("8 members have been added to #{FIRST_GROUP}.")
    
    select_team_members(@read_only_user)
    click_groups_button
    assert_group_fully_checked(0)    
  end
  
  def test_add_multiple_users_to_multiple_groups
    login_as_proj_admin_user
    create_group(FIRST_GROUP)
    create_group(SECOND_GROUP)
    create_group(THIRD_GROUP)
    
    navigate_to_team_list_for(@project)
    select_team_members(@project_admin, @read_only_user, @team_member, @user1, @user2, @user3, @user4, @user5)
    click_groups_button
    
    select_group_by_order(0)
    select_group_by_order(1)
    select_group_by_order(2)
    
    click_apply_group_memberships_button
    @browser.assert_text_present("8 members have been added to #{FIRST_GROUP}, #{SECOND_GROUP}, #{THIRD_GROUP}.")
    
    select_team_members(@read_only_user, @user1, @user2)
    click_groups_button
    assert_group_fully_checked(0)
    assert_group_fully_checked(1)
    assert_group_fully_checked(2)
  end
  
  
  def test_remove_one_user_from_group
    login_as_admin_user
    create_group_and_add_its_members(FIRST_GROUP, [@team_member])
    navigate_to_team_list_for(@project)
    select_team_members(@team_member)
    click_groups_button
    click_group_name_in_droplist(0)
    click_apply_group_memberships_button
    @browser.assert_text_present("#{@team_member.name} has been removed from #{FIRST_GROUP}.")
  end
  
  def test_remove_multiple_users_from_groups
    login_as_admin_user
    create_group_and_add_its_members(FIRST_GROUP, [@team_member, @user1, @user2])
    create_group_and_add_its_members(SECOND_GROUP, [@read_only_user, @user1, @user2])
    navigate_to_team_list_for(@project)
    select_team_members(@user1, @user2)
    click_groups_button
    click_group_name_in_droplist(0)
    click_group_name_in_droplist(1)
    click_apply_group_memberships_button
    @browser.assert_text_present("2 members have been removed from #{FIRST_GROUP}, #{SECOND_GROUP}.")
  end
  
  def test_show_partial_check_when_some_of_the_selected_users_belong_to_this_group
    login_as_admin_user
    create_group_and_add_its_members(FIRST_GROUP, [@user1, @user2, @user3])
    create_group_and_add_its_members(SECOND_GROUP, [@user1, @user2])
    create_group(THIRD_GROUP)
    navigate_to_team_list_for(@project)
    select_team_members(@user1, @user2, @user3)
    click_groups_button
    assert_group_fully_checked(0)
    assert_group_patially_checked(1)
    assert_group_is_unchecked(2)
  end

  def test_if_the_group_checkbox_is_initially_partially_checked_then_it_will_cylce_through_patially_checked_then_checked_then_unchecked
    login_as_admin_user
    create_group_and_add_its_members(FIRST_GROUP, [@user1])
    navigate_to_team_list_for(@project)
    select_team_members(@user1, @user2)
    click_groups_button
    assert_group_patially_checked(0)
    
    click_group_name_in_droplist(0)
    assert_group_fully_checked(0)
    
    click_group_name_in_droplist(0)    
    assert_group_is_unchecked(0)
    
    click_group_name_in_droplist(0)
    assert_group_patially_checked(0)
  end
  
  def test_add_member_and_remove_members_from_group_at_same_time
    login_as_admin_user
    create_group_and_add_its_members(FIRST_GROUP, [@user1])
    create_group(SECOND_GROUP)
    create_group(THIRD_GROUP)
    
    navigate_to_team_list_for(@project)
    select_team_members(@user1, @user2, @user3)
    click_groups_button
    
    click_group_name_in_droplist(0)
    click_group_name_in_droplist(0)
    
    click_group_name_in_droplist(1)
    click_group_name_in_droplist(2)
    
    click_apply_group_memberships_button
    
    @browser.assert_text_present("3 members have been removed from #{FIRST_GROUP} and added to #{SECOND_GROUP}, #{THIRD_GROUP}.")
  end
  
  def test_the_groups_column_show_the_group_links_that_user_belong_to
    login_as_admin_user
    first_group = create_group(FIRST_GROUP)
    second_group = create_group(SECOND_GROUP)
    third_group = create_group(THIRD_GROUP)
    
    navigate_to_team_list_for(@project)
    select_team_members(@user1, @user2, @user3)
    click_groups_button
    click_group_name_in_droplist(0)
    click_apply_group_memberships_button
    
    assert_group_links_that_user_belong_to_prsent(@user1, [first_group])
        
    assert_group_links_that_user_belong_to_prsent(@user2, [first_group])
    assert_group_links_that_user_belong_to_prsent(@user3, [first_group])
    
    assert_group_links_that_user_doesnot_belong_to_not_prsent(@user2, [second_group, third_group])
    assert_group_links_that_user_doesnot_belong_to_not_prsent(@user2, [second_group, third_group])
    assert_group_links_that_user_doesnot_belong_to_not_prsent(@user3, [second_group, third_group])
    
    select_team_members(@user1, @user2)
    click_groups_button
    click_group_name_in_droplist(1)
    click_apply_group_memberships_button
    
    assert_group_links_that_user_belong_to_prsent(@user1, [first_group, second_group])
    assert_group_links_that_user_belong_to_prsent(@user2, [first_group, second_group])
    assert_group_links_that_user_belong_to_prsent(@user3, [first_group])
    
    assert_group_links_that_user_doesnot_belong_to_not_prsent(@user1, [third_group])
    assert_group_links_that_user_doesnot_belong_to_not_prsent(@user2, [third_group])
    assert_group_links_that_user_doesnot_belong_to_not_prsent(@user3, [second_group, third_group])
    
    select_team_members(@user1)
    click_groups_button
    click_group_name_in_droplist(2)
    click_apply_group_memberships_button
    
    
    assert_group_links_that_user_belong_to_prsent(@user1, [first_group, second_group, third_group])
    assert_group_links_that_user_belong_to_prsent(@user2, [first_group, second_group])
    assert_group_links_that_user_belong_to_prsent(@user3, [first_group])
    
    assert_group_links_that_user_doesnot_belong_to_not_prsent(@user2, [third_group])
    assert_group_links_that_user_doesnot_belong_to_not_prsent(@user3, [second_group, third_group])
  end
  
  #bug 10865
  def test_escape_the_html_tags_in_group_name_on_team_list_page
    login_as_admin_user
    group_name = "<h1> foo </h1>"
    first_group = create_group_and_add_its_members(group_name, [@user1])
    navigate_to_team_list_for(@project)
    assert_group_links_that_user_belong_to_prsent(@user1, [first_group])
  end
  
  
  def test_the_group_link_should_take_user_to_individual_group_page
    login_as_admin_user
    first_group = create_group_and_add_its_members(FIRST_GROUP, [@user1])
    second_group = create_group_and_add_its_members(SECOND_GROUP, [@user1])
    assert_can_see_and_use_the_group_link_in_team_list(@project, first_group)
    assert_can_see_and_use_the_group_link_in_team_list(@project, second_group)    
  end
  
  def test_all_kinds_of_users_can_see_the_group_links
    register_license_that_allows_anonymous_users
    login_as_admin_user
    first_group = create_group_and_add_its_members(FIRST_GROUP, [@user1])
    login_as_read_only_user
    assert_can_see_and_use_the_group_link_in_team_list(@project, first_group)
    login_as_project_member
    assert_can_see_and_use_the_group_link_in_team_list(@project, first_group)
    logout
    assert_can_see_and_use_the_group_link_in_team_list(@project, first_group)
  end
  
  def test_still_show_go_back_to_team_list_button_after_user_update_something_for_group_if_user_was_come_from_the_team_list
    login_as_proj_admin_user
    first_group = create_group_and_add_its_members(FIRST_GROUP, [@user1])
    navigate_to_team_list_for(@project)
    click_group_name_on_group_list_page(first_group.name)
    @browser.assert_location("/projects/#{@project.identifier}/groups/#{first_group.id}?back_to_team=true")
    assert_back_to_team_list_button_present
    change_group_name_to(SECOND_GROUP)
    click_back_to_team_list_button
    @browser.assert_location("/projects/#{@project.identifier}/team")
  end

  # bug 10879   
  def test_should_be_able_to_add_members_to_group_when_auto_enroll_is_on
    login_as_proj_admin_user
    qa_group = @project.user_defined_groups.create(:name => 'QAs')
    auto_enroll_all_users_as_full_users(@project)

    select_team_members(@project_admin, @read_only_user)
    assert_groups_button_is_enabled
    click_groups_button
    click_group_name_in_droplist(0)
    click_apply_group_memberships_button
    assert_link_present("/projects/#{@project.identifier}/groups/#{qa_group.id}?back_to_team=true")
  end
  
  private
  def assert_can_see_and_use_the_group_link_in_team_list(project,group)
    navigate_to_team_list_for(project)
    click_group_name_on_group_list_page(group.name)
    @browser.assert_location("/projects/#{project.identifier}/groups/#{group.id}?back_to_team=true")
    assert_back_to_team_list_button_present
    click_back_to_team_list_button
    @browser.assert_location("/projects/#{project.identifier}/team")
  end
end
