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

require File.expand_path('../../../acceptance/acceptance_test_helper.rb', File.dirname(__FILE__))
require File.expand_path('user_crud_acceptance_support.rb', File.dirname(__FILE__))

# Tags: user
class Scenario07CRUDUser1Test < ActiveSupport::TestCase

  include UserCrudAcceptanceSupport

  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @admin = users(:admin)
    @project_member = users(:project_member)
    @project = create_project(:prefix => 'scenario_07', :users => [@project_member, @admin])
    @browser = selenium_session
    navigate_to_all_projects_page
    login_as_admin_user
  end

  # story 8989
  def test_should_show_deactivated_on_profile_for_deacticated_user
    deactive_user(@project_member)
    navigate_to_team_list_for(@project)

    click_user_display_name(@project_member)
    assert_deactivation_notice_on_user_profile
  end

  # Story 12754 -quick add on funky tray
  def test_quick_add_link_on_funky_tray_not_present_on_user_profile_pages
    navigate_to_user_management_page
    assert_quick_add_link_not_present_on_funky_tray
    click_new_user_link
    assert_quick_add_link_not_present_on_funky_tray
    navigate_to_user_management_page
    click_user_display_name(@project_member)
    assert_quick_add_link_not_present_on_funky_tray
  end

  # story 9948
  def test_admin_can_go_to_user_profile_on_user_list_page
    navigate_to_user_management_page

    click_user_display_name(@project_member)
    assert_user_profile_is_opened(@project_member)
  end

  def test_admin_can_indicate_user_type_on_creation_and_full_type_is_default_when_license_allows
    navigate_to_user_management_page
    click_new_user_link
    assert_user_type_options_present
    assert_full_type_checked
    new_user = add_new_user("foobar@email.com", "password1.")
    assert_full_user_created_message
    assert_user_is_full_user(new_user)

    assert_admin_check_box_enabled_for(new_user)
    check_administrator_check_box_for(new_user)
    assert_user_is_mingle_admin(new_user)

    assert_light_check_box_enabled_for(new_user)
    check_light_user_check_box_for(new_user)
    assert_user_is_light_user(new_user)

    new_user.destroy
  end

  def test_admin_can_indicate_light_type_on_creation
    navigate_to_user_management_page
    click_new_user_link
    assert_user_type_options_present
    change_user_type_to("light")
    new_user = add_new_user("foobar@email.com", "password1.")
    assert_light_user_created_message
    assert_user_is_light_user(new_user)

    assert_light_check_box_enabled_for(new_user)
    check_light_user_check_box_for(new_user)
    assert_user_is_full_user(new_user)

    assert_admin_check_box_enabled_for(new_user)
    check_administrator_check_box_for(new_user)
    assert_user_is_mingle_admin(new_user)

    new_user.destroy
  end

  def test_admin_can_indicate_admin_type_on_creation
    navigate_to_user_management_page
    click_new_user_link
    assert_user_type_options_present
    change_user_type_to("admin")
    new_user = add_new_user("foobar@email.com", "password1.")
    assert_admin_user_created_message
    assert_user_is_mingle_admin(new_user)

    assert_admin_check_box_enabled_for(new_user)
    check_administrator_check_box_for(new_user)
    assert_user_is_full_user(new_user)

    assert_light_check_box_enabled_for(new_user)
    check_light_user_check_box_for(new_user)
    assert_user_is_light_user(new_user)

    new_user.destroy
  end

  def test_crud_user
    navigate_to_all_projects_page
    open_mingle_admin_dropdown
    @browser.click_and_wait("link=Manage users")
    @browser.click_and_wait("link=New user")
    @browser.type('user_login', VALID_LOGIN)
    @browser.type('user_email', VALID_EMAIL)
    @browser.type('user_name', VALID_NAME)
    @browser.type('user_password', VALID_PASSWORD)
    @browser.type('user_password_confirmation', VALID_PASSWORD)
    click_create_profile_button
    assert_redirected_to_user_management_page
    @browser.assert_text_present(VALID_EMAIL)

    logout
    log_back_in(VALID_LOGIN, VALID_PASSWORD)
    @browser.click_and_wait(profile_for_user_name_link(VALID_NAME))
    @browser.assert_element_matches('user_email', /#{VALID_EMAIL}/)
    @browser.assert_text_not_present('Delete')

    @browser.click_and_wait('edit-profile')
    @browser.assert_text_present("Edit profile for #{VALID_NAME}")
    @browser.assert_value('user_email', "#{VALID_EMAIL}")
    @browser.assert_value('user_name', "#{VALID_NAME}")
    click_cancel_button

    new_password = ANOTHER_VALID_PASSWORD
    @browser.click_and_wait('link=Change password')
    @browser.assert_value('user_password', BLANK)
    @browser.assert_value('user_password_confirmation', BLANK)
    @browser.type('current_password', VALID_PASSWORD)
    @browser.type('user_password', new_password)
    @browser.type('user_password_confirmation', new_password)
    click_change_password_button
    assert_notice_message("Password was successfully changed for #{VALID_NAME}.")

    logout
    open_card(@project, 1)
    @browser.assert_location('/profile/login')
    login_as("#{@project_member.login}")
    @browser.assert_element_matches('current-user', /#{@project_member.email}/)
  end

  def test_edit_user_profile
    @admin.update_attribute(:email, 'old_admin@email.com')
    @admin.update_attribute(:name, 'old name')

    project = @project.identifier
    navigate_to_card_list_for(@project)
    create_new_card(@project, :name => 'new card')
    click_card_on_list(1)
    click_edit_link_on_card
    enter_text_in_editor('adding new card for work')
    save_card
    @browser.run_once_history_generation

    old_email = @admin.email
    new_email = ANOTHER_VALID_EMAIL
    old_name = @admin.name
    new_name = 'new name'
    @browser.open('/users/list')
    @browser.click_and_wait(profile_for_user_link(@admin))
    @browser.click_and_wait('edit-profile')
    @browser.type('user_email', new_email)
    @browser.type('user_name', new_name)
    click_save_profile_button

    @browser.open('/users/list')
    @browser.click_and_wait(profile_for_user_name_link(new_name))
    @browser.click_and_wait('link=Change password')
    @browser.type('current_password', MINGLE_TEST_DEFAULT_PASSWORD)
    @browser.type('user_password', VALID_PASSWORD)
    @browser.type('user_password_confirmation', VALID_PASSWORD)
    click_change_password_button
    logout

    login_as(@admin.login, VALID_PASSWORD)
    @browser.assert_element_matches('current-user', /#{new_name}/)
    navigate_to_card_list_for(@project)
    click_card_on_list(1)
    load_card_history
    @browser.assert_element_matches('card-1-2', /Modified by #{new_name} (.*)/)
    @browser.assert_element_matches('card-1-1', /Created by #{new_name} (.*)/)

    @browser.open('/users/list')
    @browser.assert_text_not_present(old_email)
    @browser.assert_text_not_present(old_name)
    @browser.assert_text_present(new_email)
    @browser.assert_text_present(new_name)
  end

  def test_cancel_during_edit_user
    login_as_project_member
    open_show_profile_for(@project_member)
    @browser.click_and_wait 'edit-profile'
    click_cancel_button
    @browser.assert_element_matches 'user_email', /#{@project_member.email}/
    logout
    open_card @project, 1
    @browser.assert_location '/profile/login'
    login_as "#{@project_member.login}"
    @browser.assert_element_matches "current-user", /#{@project_member.email}/
  end

  def test_edit_user_password_and_confirmation_must_match
    open_mingle_admin_dropdown
    @browser.click_and_wait "link=Manage users"
    @browser.click_and_wait "link=New user"
    @browser.type 'user_login', VALID_LOGIN
    @browser.type 'user_email', VALID_EMAIL
    @browser.type 'user_name', VALID_NAME_WITH_HTML
    @browser.type 'user_password', VALID_PASSWORD
    @browser.type 'user_password_confirmation', VALID_PASSWORD
    click_create_profile_button()
    logout

    log_back_in(VALID_LOGIN, VALID_PASSWORD)
    @browser.click_and_wait profile_for_user_name_link(VALID_NAME_WITH_HTML)
    @browser.click_and_wait 'link=Change password'
    @browser.type('current_password', VALID_PASSWORD)
    @browser.type 'user_password', 'pw0rd-'
    @browser.type 'user_password_confirmation', 'Pw0rd-'
    click_change_password_button

    @browser.assert_text_present "Change password for #{VALID_NAME_WITH_HTML}"
    @browser.assert_text_present PASSWORD_DOESNT_MATCH_CONFIRM
    @browser.assert_value 'user_password', BLANK
    @browser.assert_value 'user_password_confirmation', BLANK
  end

  def test_existing_password_not_rendered_when_changing_password
    open_change_password_page_for(@project_member.id)
    @browser.assert_value('user_password', BLANK)
    @browser.assert_value('user_password_confirmation', BLANK)
  end

  def test_edit_user_profile_validations
    open_mingle_admin_dropdown
    @browser.click_and_wait "link=Manage users"
    @browser.click_and_wait "link=New user"
    @browser.type 'user_login', VALID_LOGIN
    @browser.type 'user_email', VALID_EMAIL
    @browser.type 'user_name', VALID_NAME
    @browser.type 'user_password', VALID_PASSWORD
    @browser.type 'user_password_confirmation', VALID_PASSWORD
    click_create_profile_button
    assert_redirected_to_user_management_page
    logout

    log_back_in(VALID_LOGIN, VALID_PASSWORD)
    @browser.click_and_wait profile_for_user_name_link(VALID_NAME)
    @browser.click_and_wait 'edit-profile'
    assert_user_profile_save_validations
  end

  def test_change_password_validations
    open_mingle_admin_dropdown
    @browser.click_and_wait "link=Manage users"
    @browser.click_and_wait "link=New user"
    @browser.type 'user_login', VALID_LOGIN
    @browser.type 'user_email', VALID_EMAIL
    @browser.type 'user_name', VALID_NAME
    @browser.type 'user_password', VALID_PASSWORD
    @browser.type 'user_password_confirmation', VALID_PASSWORD
    click_create_profile_button
    assert_redirected_to_user_management_page
    logout

    log_back_in(VALID_LOGIN, VALID_PASSWORD)
    @browser.click_and_wait profile_for_user_name_link(VALID_NAME)
    @browser.click_and_wait 'link=Change password'
    @browser.type('current_password', VALID_PASSWORD)
    assert_user_password_change_save_validations
  end

  def test_register_user_validations
    open_mingle_admin_dropdown
    @browser.click_and_wait "link=Manage users"
    @browser.click_and_wait "link=New user"
    assert_user_profile_create_validations

    @browser.type 'user_password', 'pw0rd-'
    @browser.type 'user_password_confirmation', 'Pw0rd-'
    click_create_profile_button()
    @browser.assert_text_present PASSWORD_DOESNT_MATCH_CONFIRM
    @browser.assert_text_not_present PASSWORD_TOO_SHORT
    @browser.assert_text_not_present PASSWORD_CONFIRM_BLANK
  end

  def test_cannot_register_multiple_users_with_same_email_or_login_name
    navigate_to_all_projects_page
    open_mingle_admin_dropdown
    @browser.click_and_wait("link=Manage users")
    @browser.click_and_wait("link=New user")
    @browser.type('user_login', VALID_LOGIN)
    @browser.type('user_email', VALID_EMAIL)
    @browser.type('user_name', VALID_NAME)
    @browser.type('user_password', VALID_PASSWORD)
    @browser.type('user_password_confirmation', VALID_PASSWORD)
    click_create_profile_button
    assert_redirected_to_user_management_page

    @browser.click_and_wait "link=New user"
    @browser.type('user_login', VALID_LOGIN)
    @browser.type('user_email', VALID_EMAIL)
    @browser.type('user_name', VALID_NAME)
    @browser.type('user_password', VALID_PASSWORD)
    @browser.type('user_password_confirmation', VALID_PASSWORD)
    click_create_profile_button
    @browser.assert_text_present(SIGN_IN_NAME_ALREADY_TAKEN)
    @browser.assert_text_present(EMAIL_ALREADY_TAKEN)

    @browser.type('user_login', VALID_LOGIN_UPCASED)
    @browser.type('user_email', ANOTHER_VALID_EMAIL)
    @browser.type('user_password', VALID_PASSWORD)
    @browser.type('user_password_confirmation', VALID_PASSWORD)
    click_create_profile_button
    @browser.assert_text_present(SIGN_IN_NAME_ALREADY_TAKEN)

    logout
    login_as(VALID_LOGIN, VALID_PASSWORD)
    assert_notice_message(SIGN_IN_SUCCESSFUL)
  end

  def test_cannot_update_user_login_with_another_existing_user_login_despite_case
    navigate_to_all_projects_page
    open_mingle_admin_dropdown
    @browser.click_and_wait("link=Manage users")
    @browser.click_and_wait("link=New user")
    @browser.type('user_login', VALID_LOGIN)
    @browser.type('user_email', VALID_EMAIL)
    @browser.type('user_name', VALID_NAME)
    @browser.type('user_password', VALID_PASSWORD)
    @browser.type('user_password_confirmation', VALID_PASSWORD)
    click_create_profile_button
    assert_redirected_to_user_management_page

    @browser.click_and_wait "link=New user"
    @browser.type('user_login', ANOTHER_VALID_LOGIN)
    @browser.type('user_email', ANOTHER_VALID_EMAIL)
    @browser.type('user_name', ANOTHER_VALID_LOGIN)
    @browser.type('user_password', VALID_PASSWORD)
    @browser.type('user_password_confirmation', VALID_PASSWORD)
    click_create_profile_button


    click_show_profile_for(ANOTHER_VALID_LOGIN)
    click_edit_profile
    @browser.type('user_login', VALID_LOGIN_UPCASED)
    click_save_profile_button
    assert_error_message(LOGIN_ALREADY_TAKEN)

    logout
    login_as(ANOTHER_VALID_LOGIN, VALID_PASSWORD)
    assert_notice_message(SIGN_IN_SUCCESSFUL)
    @browser.assert_element_matches("css=.current-user", /#{ANOTHER_VALID_LOGIN}/)
  end

end
