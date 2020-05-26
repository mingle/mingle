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
class Scenario40DeactivateUserTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @admin = users(:admin)
    @project_admin = users(:proj_admin)
    @project_member = users(:project_member)
    @project = create_project(:prefix => 'scenario_40', :users => [@project_member], :admins => [@project_admin])
    @project_name = @project.identifier
  end

  def test_deactivated_user_cannot_login
    login_as_admin_user
    toggle_activation_for(@project_admin)
    logout

    login_as_proj_admin_user
    assert_deactivated_user_error_message(@project_admin)
  end
  
  # bug 2716
  def test_deactivated_user_does_not_see_tabs_and_search_box_when_attempting_to_login
    login_as_admin_user
    toggle_activation_for(@project_admin)
    logout

    login_as_proj_admin_user
    assert_deactivated_user_error_message(@project_admin)
    assert_search_input_box_and_button_not_present
    assert_all_tab_not_present
    assert_tab_not_present('History')
    assert_tab_not_present('Project Admin')
    assert_tab_not_present('Overview')
  end

  def test_reactivated_user_can_log_back_in_and_access_project
    login_as_admin_user
    toggle_activation_for(@project_member)
    logout

    login_as_project_member
    assert_deactivated_user_error_message(@project_member)

    login_as_admin_user
    toggle_activation_for(@project_member)
    logout

    login_as_proj_admin_user
    navigate_to_all_projects_page
    assert_project_link_present(@project)
  end

  def test_can_add_deactivated_users_to_a_team_and_set_them_as_values_on_user_properties
    login_as_admin_user
    toggle_activation_for(@project_member)
    remove_from_team_for(@project, @project_member)
    add_full_member_to_team_for(@project, @project_member)
    
    user_property_name = 'owner'
    create_property_definition_for(@project, user_property_name, :type => 'user')
    card = create_card!(:name => 'setting user property')
    @project.reload.activate
    open_card(@project, card.number)
    set_properties_on_card_show(user_property_name => @project_member.name)
    @browser.run_once_history_generation
    open_card(@project, card.number)
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {user_property_name => @project_member.name})
    navigate_to_user_management_page
    assert_user_deactivated(@project_member)
  end

  # bug 2606
  def test_can_deactivate_user_when_there_is_saved_view_with_user_property_set_to_them
    login_as_admin_user
    user_property_name = 'owner'
    create_property_definition_for(@project, user_property_name, :type => 'user')
    @project.reload.activate
    navigate_to_card_list_by_clicking(@project)
    filter_card_list_by(@project, user_property_name => "#{@project_member.name}")
    project_member_owner_view = create_card_list_view_for(@project, 'owned by view')
    toggle_activation_for(@project_member)
    assert_successful_user_deactivation_message(@project_member)
    assert_admin_check_box_disabled_for(@project_member)
    login_as_project_member
    assert_deactivated_user_error_message(@project_member)
  end

  #bug 1843
  def test_deactivating_user_should_disable_the_administrator_check_box
    login_as_admin_user
    toggle_activation_for(@project_member)
    assert_admin_check_box_disabled_for(@project_member)
  end
  
  def test_admin_can_filter_deactivated_users
    login_as_admin_user
    toggle_activation_for(@project_member)
    @browser.click_and_wait('show_deactivated_users')
    @browser.assert_text_not_present_in('content', "#{@project_member.name}") 
  end  
  
  def test_search_can_include_or_exclude_deactivated_users
    login_as_admin_user    
    navigate_to_user_management_page
    @browser.click_and_wait('show_deactivated_users')
    toggle_activation_for(@project_admin)
    toggle_activation_for(@project_member)
    search_user_in_user_management_page(@project_admin.name)
    @browser.click_and_wait('show_deactivated_users')
    @browser.assert_text_present_in('content', "#{@project_admin.name}") 
    search_user_in_user_management_page(@project_member.name)
    @browser.assert_text_present_in('content', "#{@project_member.name}") 
  end
  
  def test_show_deactivated_users_is_an_admin_preference
    login_as_admin_user    
    navigate_to_user_management_page
    @browser.click_and_wait('show_deactivated_users')
    
    login_as_admin_user
    navigate_to_user_management_page
    @browser.assert_not_checked('show_deactivated_users')
  end
  
  def test_deactivated_users_consistently_styled_user_management
    login_as_admin_user
    toggle_activation_for(@project_member)
    logout

    login_as_proj_admin_user
    navigate_to_user_management_page
    @browser.assert_has_classname("user_#{@project_member.id}", "deactivated")
    search_user_in_user_management_page(@project_member.name)
    @browser.assert_has_classname("user_#{@project_member.id}", "deactivated")
  end

  def test_deactivated_users_consistently_styled_team_list
    login_as_admin_user
    toggle_activation_for(@project_member)
    logout

    login_as_proj_admin_user
    navigate_to_team_list_for(@project)
    type_search_user_text(@project_member.name)
    click_search_user_button
    @browser.assert_has_classname("user_#{@project_member.id}", "deactivated")
    click_add_team_member_link_on_team_member_list
    @browser.assert_has_classname("user_#{@project_member.id}", "deactivated")    
  end
  
  def test_deactivated_users_consistently_styled_group_page
    login_as_admin_user
    toggle_activation_for(@project_member)
    navigate_to_group_list_page(@project)
    create_a_group_for_project(@project, '<b>grouper</b>')
    logout

    login_as_proj_admin_user
    navigate_to_group_list_page(@project)
    open_group(@project, '<b>grouper</b>')
    @browser.click_and_wait("link=Add user as member")
    @browser.assert_has_classname("user_#{@project_member.id}", "deactivated")
    type_search_user_text(@project_member.name)
    click_search_user_button
    @browser.assert_has_classname("user_#{@project_member.id}", "deactivated")    
  end
  
  def test_deactivated_display_names_remain_clickable
    login_as_admin_user
    toggle_activation_for(@project_member)

    login_as_proj_admin_user
    navigate_to_user_management_page    
    @browser.assert_element_present("link=#{@project_member.name}")
    navigate_to_team_list_for(@project)
    @browser.assert_element_present("link=#{@project_member.name}")
  end
  
end
