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

# Tags: user, license

class Scenario121PreventViolatingLicenseInTermsOfUsersTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  MAX_FULL_USER = 9
  MAX_LIGHT_USER = 2

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session


    @mingle_admin = users(:admin)
    @full_user = users(:capitalized)
    @light_user = users(:bob)
    @another_full_user = users(:proj_admin)
    @another_light_user = users(:longbob)
    @deactivated_light_user = users(:existingbob)
    @deactivated_full_user = users(:first)

    login_as_admin_user
    navigate_to_user_management_page

    check_light_user_check_box_for(@light_user)
    check_light_user_check_box_for(@another_light_user)
    check_light_user_check_box_for(@deactivated_light_user)

    toggle_activation_for(@deactivated_light_user)
    toggle_activation_for(@deactivated_full_user)

    register_limited_license_that_allows_anonymous_users(MAX_FULL_USER, MAX_LIGHT_USER)

  end

  def teardown
    logout
    reset_license
  end

  # full=max, light=max
  def test_should_not_be_able_to_create_or_active_users_when_light_seats_and_full_seats_are_all_taken
    login_as_admin_user
    navigate_to_user_management_page
    assert_both_full_and_light_seats_are_used_up_message
    assert_activate_deactivate_link_not_present_for(@deactivated_full_user)
    assert_activate_deactivate_link_not_present_for(@deactivated_light_user)
    assert_new_user_link_not_present
  end

  def test_license_message_should_not_be_html_escaped_when_license_is_in_violation
    project = create_project(:prefix => 'scenario_121', :admins => [@mingle_admin])
    create_user_without_validation
    login_as(@light_user.login)
    navigate_to_project_overview_page(project)
    assert_license_violations_message_caused_by_too_many_users(MAX_FULL_USER, MAX_FULL_USER + 1)
  end

  def test_should_only_be_able_to_swich_full_and_admin_to_light_when_light_seats_and_full_seats_are_all_taken
    login_as_admin_user
    navigate_to_user_management_page


    assert_admin_check_box_disabled_for(@light_user)
    assert_light_check_box_disabled_for(@light_user)

    assert_admin_check_box_enabled_for(@full_user)
    check_administrator_check_box_for(@full_user)
    assert_user_is_mingle_admin(@full_user)
    assert_both_full_and_light_seats_are_used_up_message

    admin_user = @full_user
    assert_admin_check_box_enabled_for(admin_user)
    check_administrator_check_box_for(admin_user)
    assert_user_is_full_user(admin_user)
    assert_both_full_and_light_seats_are_used_up_message


    assert_light_check_box_enabled_for(@full_user)
    check_light_user_check_box_for(@full_user)
    assert_user_is_light_user(@full_user)
    check_light_user_check_box_for(@full_user)
    assert_both_full_and_light_seats_are_used_up_message



    check_administrator_check_box_for(@full_user)
    admin_user = @full_user
    assert_light_check_box_enabled_for(admin_user)
    check_light_user_check_box_for(admin_user)
    assert_user_is_light_user(admin_user)
    check_light_user_check_box_for(admin_user)
    assert_both_full_and_light_seats_are_used_up_message

  end

  # full=max-1, light=max+1
  def test_should_not_be_able_to_create_or_active_users_when_the_total_number_of_full_and_light_seats_are_taken
    login_as_admin_user
    navigate_to_user_management_page
    check_light_user_check_box_for(@full_user)
    assert_total_seats_are_used_up_message
    assert_activate_deactivate_link_not_present_for(@deactivated_full_user)
    assert_activate_deactivate_link_not_present_for(@deactivated_light_user)
    assert_new_user_link_not_present
  end

  def test_should_be_able_to_switch_between_all_roles_when_the_total_number_of_full_and_light_seats_are_taken
    login_as_admin_user
    navigate_to_user_management_page
    check_light_user_check_box_for(@another_full_user)
    assert_total_seats_are_used_up_message

    assert_admin_check_box_enabled_for(@light_user)
    check_administrator_check_box_for(@light_user)
    assert_user_is_mingle_admin(@light_user)
    check_light_user_check_box_for(@light_user)
    assert_total_seats_are_used_up_message


    assert_light_check_box_enabled_for(@light_user)
    check_light_user_check_box_for(@light_user)
    assert_user_is_full_user(@light_user)
    check_light_user_check_box_for(@light_user)
    assert_total_seats_are_used_up_message


    assert_admin_check_box_enabled_for(@full_user)
    check_administrator_check_box_for(@full_user)
    assert_user_is_mingle_admin(@full_user)
    assert_total_seats_are_used_up_message

    admin_user = @full_user
    assert_admin_check_box_enabled_for(admin_user)
    check_administrator_check_box_for(admin_user)
    assert_user_is_full_user(admin_user)
    assert_total_seats_are_used_up_message

    assert_light_check_box_enabled_for(@full_user)
    check_light_user_check_box_for(@full_user)
    assert_user_is_light_user(@full_user)
    check_light_user_check_box_for(@full_user)
    assert_total_seats_are_used_up_message

    check_administrator_check_box_for(@full_user)
    admin_user = @full_user
    assert_light_check_box_enabled_for(admin_user)
    check_light_user_check_box_for(admin_user)
    check_administrator_check_box_for(admin_user)
    assert_total_seats_are_used_up_message

  end

  # full=max, light=max-1
  def test_should_only_be_able_to_create_or_active_light_user_when_only_full_user_achieve_its_maximum
    login_as_admin_user
    navigate_to_user_management_page
    toggle_activation_for(@another_light_user)
    assert_only_full_seats_are_used_up_message(MAX_FULL_USER)

    assert_activate_deactivate_link_not_present_for(@deactivated_full_user)
    assert_activate_deactivate_link_present_for(@deactivated_light_user)

    assert_new_user_link_present
    click_new_user_link
    assert_light_type_checked
    assert_full_type_disabled
    assert_admin_type_disabled

    add_new_user("foobar@email.com", "password1.")
    assert_light_user_created_message
  end


  def test_should_only_be_able_to_switch_full_and_admin_to_light_when_only_full_user_achieve_its_maximum
    login_as_admin_user
    navigate_to_user_management_page
    toggle_activation_for(@another_light_user)
    assert_only_full_seats_are_used_up_message(MAX_FULL_USER)

    assert_admin_check_box_disabled_for(@light_user)
    assert_light_check_box_disabled_for(@light_user)

    assert_admin_check_box_enabled_for(@full_user)
    check_administrator_check_box_for(@full_user)
    assert_user_is_mingle_admin(@full_user)
    assert_only_full_seats_are_used_up_message(MAX_FULL_USER)

    admin_user = @full_user
    assert_admin_check_box_enabled_for(admin_user)
    check_administrator_check_box_for(admin_user)
    assert_user_is_full_user(admin_user)
    assert_only_full_seats_are_used_up_message(MAX_FULL_USER)

    assert_light_check_box_enabled_for(@full_user)
    check_light_user_check_box_for(@full_user)
    assert_user_is_light_user(@full_user)
    check_light_user_check_box_for(@full_user)
    assert_only_full_seats_are_used_up_message(MAX_FULL_USER)

    check_administrator_check_box_for(@full_user)
    admin_user = @full_user
    assert_light_check_box_enabled_for(admin_user)
    check_light_user_check_box_for(admin_user)
    assert_user_is_light_user(admin_user)
    check_light_user_check_box_for(admin_user)
    assert_only_full_seats_are_used_up_message(MAX_FULL_USER)
  end

  # full=max-1, light=max
  def test_should_be_able_to_create_all_type_user_when_only_light_user_achieve_its_maximum
    login_as_admin_user
    navigate_to_user_management_page
    check_administrator_check_box_for(@full_user)
    deactivated_admin_user = @full_user
    toggle_activation_for(deactivated_admin_user)

    assert_activate_deactivate_link_present_for(@deactivated_full_user)
    assert_activate_deactivate_link_present_for(@deactivated_light_user)
    assert_activate_deactivate_link_present_for(deactivated_admin_user)


    assert_new_user_link_present
    click_new_user_link
    assert_full_type_checked

    new_user = add_new_user("foobar@email.com", "password1.")
    assert_full_user_created_message
    navigate_to_delete_users_page
    delete_users(new_user)
    navigate_to_user_management_page

    click_new_user_link
    change_user_type_to("light")
    new_user = add_new_user("foobar@email.com", "password1.")
    assert_light_user_created_message
    navigate_to_delete_users_page
    delete_users(new_user)
    navigate_to_user_management_page

    click_new_user_link
    change_user_type_to("admin")
    add_new_user("foobar@email.com", "password1.")
    assert_admin_user_created_message
  end

  def test_should_be_able_to_swich_between_all_roles_when_only_light_user_achieve_its_maximum
    login_as_admin_user
    navigate_to_user_management_page
    toggle_activation_for(@another_full_user)

    assert_admin_check_box_enabled_for(@light_user)
    check_administrator_check_box_for(@light_user)
    assert_user_is_mingle_admin(@light_user)
    check_light_user_check_box_for(@light_user)

    assert_light_check_box_enabled_for(@light_user)
    check_light_user_check_box_for(@light_user)
    assert_user_is_full_user(@light_user)
    check_light_user_check_box_for(@light_user)

    assert_admin_check_box_enabled_for(@full_user)
    check_administrator_check_box_for(@full_user)
    assert_user_is_mingle_admin(@full_user)

    admin_user = @full_user
    assert_admin_check_box_enabled_for(admin_user)
    check_administrator_check_box_for(admin_user)
    assert_user_is_full_user(admin_user)

    assert_light_check_box_enabled_for(@full_user)
    check_light_user_check_box_for(@full_user)
    assert_user_is_light_user(@full_user)
    check_light_user_check_box_for(@full_user)

    check_administrator_check_box_for(@full_user)
    admin_user = @full_user
    assert_light_check_box_enabled_for(admin_user)
    check_light_user_check_box_for(admin_user)
    check_administrator_check_box_for(admin_user)
  end

  # bug 6091
  def test_can_update_user_when_license_hit_maximum_of_full_user
    login_as_admin_user
    navigate_to_user_management_page
    click_show_profile_for(@full_user)
    click_edit_profile
    @browser.type('user_login', 'newuser')
    click_save_profile_button
    assert_notice_message("Profile was successfully updated for #{@full_user.name}.")
    navigate_to_user_management_page
    click_change_password_for(@full_user)
    @browser.type('user_password', 'password1.')
    @browser.type('user_password_confirmation', 'password1.')
    click_change_password_button
    assert_notice_message("Password was successfully changed for #{@full_user.name}")
  end



end
