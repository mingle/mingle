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

# Tags: scenario, user, project, #1097, #1581
class Scenario37ProjectAdminTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @admin_user = users(:admin)
    @non_admin_user = users(:longbob)
    @project_admin_user = users(:proj_admin)
    @initial_project_member = users(:first)
    @project = create_project(:prefix => 'scenario_37', :users => [@initial_project_member, @admin_user], :admins => [@project_admin_user])
    setup_property_definitions(:status => ['new'])
    @decoy_project = create_project(:prefix => 'decoy_project', :users => [@admin_user])
  end

  def test_project_admin_cannot_create_or_delete_new_project_or_template
    login_as_admin_user
    create_template_for(@project)
    logout
    login_as_project_admin
    @browser.assert_element_not_present("action-bar")
    assert_link_not_present_and_cannot_access_via_browser("/admin/projects/new")
    assert_link_not_present_and_cannot_access_via_browser("/admin/projects/import")
    assert_link_not_present_and_cannot_access_via_browser("/admin/templates")
    @browser.assert_element_not_present("create_template_#{@project.identifier}")
    assert_link_not_present_and_cannot_access_via_browser("/admin/templates/templatize/#{@project.identifier}")
    assert_link_not_present_and_cannot_access_via_browser("/admin/templates/delete/#{@project.identifier}_template") # bug 1581
    assert_link_not_present_and_cannot_access_via_browser("/projects/#{@project.identifier}/admin/delete")
  end

  def test_clicking_create_template_from_project_disables_the_link
    login_as_admin_user
    create_template_for(@project)
    assert @browser.is_visible("create_template_#{@project.identifier}")
    assert_false @browser.is_visible("disabled_create_template_#{@project.identifier}")
    @browser.click "create_template_#{@project.identifier}"
    assert_false @browser.is_visible("create_template_#{@project.identifier}")
    assert @browser.is_visible("disabled_create_template_#{@project.identifier}")
  end

  def test_project_admin_cannot_see_or_access_projects_they_are_not_members_of
    login_as_project_admin
    assert_link_not_present_and_cannot_access_via_browser("/projects/#{@decoy_project.identifier}")
    assert_link_not_present_and_cannot_access_via_browser("/projects/#{@decoy_project.identifier}/admin/delete")
  end

  def test_project_admin_cannot_create_new_or_edit_exisiting_users
    login_as_project_admin
    open_mingle_admin_dropdown
    assert_link_present("/users/list")
    assert_cannot_access_via_browser("/users/new")
    assert_cannot_access_via_browser("/users/edit_profile/#{@non_admin_user.id}")
    assert_cannot_access_via_browser("/users/edit_profile/#{@admin_user.id}")
  end

  def test_project_admin_can_edit_project_settings
    new_name = unique_project_name
    new_description = 'foo foo'
    new_sender_name = 'project admin'
    new_sender_email = @project_admin_user.email
    new_repos_path = 'repos'

    login_as_project_admin
    open_project_admin_for(@project)
    type_project_name(new_name)
    type_project_description(new_description)
    type_project_email_sender_name(new_sender_name)
    type_project_email_address(new_sender_email)
    click_save_link

    open_project_admin_for(new_name)
    @browser.assert_value('project_name', new_name)
    @browser.assert_value('project_description', new_description)
    @browser.assert_value('project_email_sender_name', new_sender_name)
    @browser.assert_value('project_email_address', new_sender_email)
  end

  def test_project_admin_can_delete_properties
    login_as_project_admin
    navigate_to_property_management_page_for(@project)
    delete_property_for(@project, 'status')
    assert_notice_message("Property status has been deleted.")
  end


  # bug 1097
  def test_project_admin_can_make_changes_to_team
    login_as_project_admin
    navigate_to_team_list_for(@project)
    assert_user_is_not_team_member(@non_admin_user)
    add_full_member_to_team_for(@project, @non_admin_user)
    # remove initial project member from team
    remove_from_team_for(@project, @initial_project_member)

    logout
    login_as(@non_admin_user.login, 'longtest')
    assert_link_present("/projects/#{@project.identifier}")

    logout
    login_as(@initial_project_member.login)
    assert_link_not_present("/projects/#{@project.identifier}")
  end

  #bug 2433
  def test_password_field_in_project_admin_page_should_be_empty_when_no_password_supplied
    login_as_project_admin
    navigate_to_subversion_repository_settings_page(@project)
    assert_project_repository_password_is_blank
  end

  #bug 11435
  def test_unable_to_delete_card_or_transition_unless_user_is_proj_admin
    project_finance = create_project(:prefix => 'finance', :users => [@initial_project_member, @project_admin_user, @admin_user])
    project_account = create_project(:prefix => 'account', :users => [@initial_project_member, @project_admin_user], :admins => [@admin_user])
    login_as_admin_user
    @project.activate
    card = create_card!(:name => 'card')
    create_transition_for(@project, 'transition',  :type => 'Card', :set_properties => {:status => 'new'})
    project_finance.activate
    card_finance = create_card!(:name => 'card_finance')
    project_account.activate
    setup_property_definitions(:status => ['new', 'open', 'fixed'])
    transition_account = create_transition_for(project_account, 'new transition',  :type => 'Card', :set_properties => {:status => 'fixed'})
    login_as_project_admin

    open_card(@project, card.number)
    @browser.assert_element_present('link=Delete')
    navigate_to_transition_management_for(@project)
    @browser.assert_element_present(class_locator('delete-transition'))

    open_card(project_finance, card_finance.number)
    @browser.assert_element_not_present('link=Delete')

    navigate_to_transition_management_for(project_account)
    @browser.assert_element_not_present('delete-transition')
  end

  def test_project_admin_can_only_see_users_option_on_admin_pill
    login_as_project_admin
    navigate_to_programs_page
    open_mingle_admin_dropdown
    assert_only_users_option_is_present
    assert_admin_dropdown_option_not_present("License")
    assert_admin_dropdown_option_not_present("Project templates")
    assert_admin_dropdown_option_not_present("Email settings")
  end

  protected

  def assert_only_users_option_is_present
    @browser.assert_element_present("link=Manage users")
  end

  def assert_admin_dropdown_option_not_present(option_name)
    @browser.assert_element_not_present("link=#{option_name}")
  end

  def assert_project_repository_password_is_blank
    @browser.click("link=Change password")
    @browser.assert_text('project_repository_password', '')
  end

  def assert_link_not_present_and_cannot_access_via_browser(url)
    assert_link_not_present(url)
    assert_cannot_access_via_browser(url)
  end

  def assert_cannot_access_via_browser(url)
    @browser.open(url)
    assert_cannot_access_resource_error_message_present
  end

  def login_as_project_admin
    login_as("#{@project_admin_user.login}")
  end

  def test_advanced_admin_page_is_visiable_for_project_admin
    login_as_project_admin
    open_project_admin_for(@project)
    assert_advanced_project_admin_link_is_present(@project)
  end
end
