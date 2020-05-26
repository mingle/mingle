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

# Tags: license
# using Z to make it run last. todo: remove the licening test dependcy
class ZScenario58MingleRegistrationTest < ActiveSupport::TestCase
  does_not_work_without_jruby
  
  fixtures :users, :login_access
  
  LICENSED_TO = 'ThoughtWorks Inc.'
  VALID_LICENSE_KEY = "cU4DAtXWmyrddqoOpD9KUkXn5zBj3J0iUh5D+AOiGVlUCiRo0Ro3JvtFoTR2
  a4FTDGKy5sjSrAORNORtQk2386zOaZbf34MSeVwryYdmscElPw67SRTTOANl
  I6S0ne4TqWZPnwuS9CVUiaz43JLMHExnesNEfksQjncCEfe8IMyKy+HqZHw4
  avsK3hhNHW37OqPvJtIAHX3NADD2pojyAX7H0TklYUIGEZaba62gAF0azR0k
  P5gRDkdeNyIf6TufbLKHIL3sahmFWMS7ILKWR1AxNbPqsdF+zmhTNSz8b//x
  mzi4Uxxje+KnKTuUDSRKq12gFIsEmbpZfoze7DvCaA=="

  VALID_LICENSE_KEY_WITH_WHITE_SPACES = "  cU4DAtXWmyrddqoOpD9KUkXn5zBj3J0iUh5D+AOiGVlUCiRo0Ro3JvtFoTR2
  a4FTDGKy5sjSrAORNORtQk2386zOaZbf34MSeVwryYdmscElPw67SRTTOANl
  I6S0ne4TqWZPnwuS9CVUiaz43JLMHExnesNEfksQjncCEfe8IMyKy+HqZHw4
  avsK3hhNHW37OqPvJtIAHX3NADD2pojyAX7H0TklYUIGEZaba62gAF0azR0k
  P5gRDkdeNyIf6TufbLKHIL3sahmFWMS7ILKWR1AxNbPqsdF+zmhTNSz8b//x
  mzi4Uxxje+KnKTuUDSRKq12gFIsEmbpZfoze7DvCaA==        "

  INVALID_LICENSE_KEY = "BBBCbWb5BLSybiIBpWNM38jbYOchxr+opf53mj7vMlyAunTNZoUyV88CRF3P
VJ+WJ79x17Di7YG22zSXecXNjBNo4A+0vxB5ytUzBiqfj6DSpHS1KOlJyDD1
e7xQpU8OwwzMYXzP7hVdDMk9jMYi//nQfbWGdfSl6K905tfxKqP+MomUyoE0
FC+jTKr0ncnKilaRv4alOj5bBucTxqLKiJm4HTOOt9+KSpDonTzF+R7oLCgf
6CXLOn594Bfk9ASwEyeTaargIpSyjrI15g0vz5ZgObCdS+ykghfTeiU7bPEr
36m1xd6PXT5kzbIWGVovLcCIeD6VfgEaU1cssATQ4A=="

  # Expiration date: 2007-09-27
  EXPIRED_LICENSE_KEY = "XPdcBYNClmuNSerQDzS5p3MMgTE8bOKFvw5l3/QDba2ChzcH5WNzr7+b6rFm
  ARXZ5SVj5BOjjPG7BWCYgCnr1i9ENKddvrqkAzIH+6DMG9XmxsOShWFR33/j
  tO+p4C6nlCuTlCMWb2W5obccvAjWsCRmoK8Ia8gYiS4d977EnmI4XiiO/YTv
  rOMobIV+H/Ag7lBwqpnYIwasz70SuzlqmVw5/k4GeB9AS8iTP1ja3xc6BZnw
  g1/L5fP7KeCypg0oW/M1wHrGHhhXgM4sbM7gBwLa+3qjT2i1e9iigjLGBE8v
  oXVomTyv8tDC6YQ77JHej/6ZbG6IV0ZjP64QueaUVg=="
  
  #limited full users: 5 active users and 5 light users.
  LIMITED_FULL_USER_LICENSE_KEY = "PwkG9I/kc0c7qa0cgztxzMwv4Z0ZjIQYh5+dl4DsX29UvRbbKTHUbaU8Lf/w
PmZCsIebZ+kzooDNRaQUGkWbFtKcfK5REBg5YqeiYe6Z9OzZEtnQ/SfmCygW
GG/nIEGfTbuZevptsiiM4TxKRrgD7DOaUy14nVlS0ICoOxVib1PjUTEEY30Y
F02sCZMLecKqWazQQ+sCY+syKqcKpak2HMAyGLoXj6QQQUOUWqxfeOvCsmYB
+SYAUSAonSsoPd7VWOg2tav8RnpQo1gw/LueZQH5JglrDLe+KC8JT7WvhFLP
5lA0g4bhcjISOxJKSTsIy0LJfSWlVJ8FCSwreB0c3Q=="

  MAX_ACTIVE_FULL_USERS = 5
  MAX_ACTIVE_LIGTHT_USERS = 5
  CURRENT_ACTIVE_FULL_USERS = 13
    
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin = users(:proj_admin)
    @team_member = users(:project_member)
    @read_only_user = users(:bob)
    @mingle_admin = users(:admin)
    @user_with_html = users(:user_with_html)
    @user_with_quotes = users(:user_with_quotes)
    @existingbob = users(:existingbob)
    @longbob = users(:longbob)
    @capitalized = users(:capitalized)
    @first = users(:first)
    @admin_not_on_project = users(:admin_not_on_project)
    @project = create_project(:prefix => 'scenario_58', :users => [users(:admin), users(:project_member)])
    @browser.enable_license_decrypt
    login_as_admin_user
  end
  
  def teardown
    @browser.disable_license_decrypt
    reset_license
  end
  
  def test_valid_license_get_registered
    set_new_license_for_project(VALID_LICENSE_KEY, LICENSED_TO)
    assert_successful_registration_message
    assert_licence_registered_details
  end
  
  def test_white_spaces_at_the_begining_and_the_end_should_not_affect_registration
    set_new_license_for_project(VALID_LICENSE_KEY_WITH_WHITE_SPACES, LICENSED_TO)
    assert_successful_registration_message
    assert_licence_registered_details
  end
  
  def test_invalid_license_gives_error_message_during_registration
    set_new_license_for_project(INVALID_LICENSE_KEY, LICENSED_TO)
    assert_invalid_license_error_message
  end
  
  def test_error_message_is_given_when_LICENSED_TO_textfield_is_invalid
    set_new_license_for_project(VALID_LICENSE_KEY, 'Abc corp.')
    assert_invalid_license_error_message
  end
  
  def test_expired_license_gives_expiration_message
    set_new_license_for_project(EXPIRED_LICENSE_KEY, LICENSED_TO)
    assert_license_expired_message
    navigate_to_all_projects_page
    assert_new_project_link_not_present
    navigate_to_user_management_page
    assert_new_user_link_not_present
  end
  
  def test_overregistering_full_users_gives_error_message
    set_new_license_for_project(LIMITED_FULL_USER_LICENSE_KEY, LICENSED_TO)
    assert_license_violations_message_caused_by_too_many_users(MAX_ACTIVE_FULL_USERS, CURRENT_ACTIVE_FULL_USERS)
    navigate_to_all_projects_page
    assert_new_project_link_not_present
    navigate_to_user_management_page
    assert_new_user_link_not_present
  end
  
  def test_unlicensed_mingle_instance_gives_error_message
    logout
    clear_license
    login_as_admin_user
    assert_unlicensed_mingle_error_message 
    navigate_to_all_projects_page
    assert_new_project_link_not_present
    navigate_to_user_management_page
    assert_new_user_link_not_present
  end
  
  def test_mingle_admin_can_get_their_fully_optional_again_by_deactivating_any_extra_users_or_switch_them_to_light_users
    fake_now(2011, 6, 3)
    set_new_license_for_project(LIMITED_FULL_USER_LICENSE_KEY, LICENSED_TO)
    navigate_to_team_list_for(@project)
    assert_license_violations_message_caused_by_too_many_users(MAX_ACTIVE_FULL_USERS, CURRENT_ACTIVE_FULL_USERS)
    assert_read_only_team_member_check_box_disabled_for(@mingle_admin)
    assert_member_can_not_be_removed
    assert_project_admin_check_box_disabled_for(@mingle_admin)
    navigate_to_all_projects_page
    assert_new_project_link_not_present
    navigate_to_user_management_page
    assert_new_user_link_not_present
    navigate_to_user_management_page
    toggle_activation_for(@read_only_user)
    toggle_activation_for(@capitalized)
    toggle_activation_for(@existingbob)
    toggle_activation_for(@first)
    toggle_activation_for(@admin_not_on_project)
    check_light_user_check_box_for(@user_with_html)
    check_light_user_check_box_for(@user_with_quotes)
    check_light_user_check_box_for(@longbob)
    assert_error_message_not_present
    navigate_to_team_list_for(@project)
    assert_read_only_team_member_check_box_enabled_for(@mingle_admin)
    assert_member_can_be_removed
    assert_project_admin_check_box_enabled_for(@mingle_admin)
    navigate_to_all_projects_page
    assert_new_project_link_present
    navigate_to_user_management_page
    assert_new_user_link_present
  ensure
    @browser.reset_fake
  end
  
  def test_mingle_admin_can_get_fully_optional_again_by_renew_license_key
    fake_now(2011, 6, 3)
    set_new_license_for_project(LIMITED_FULL_USER_LICENSE_KEY, LICENSED_TO) 
    navigate_to_team_list_for(@project)
    assert_license_violations_message_caused_by_too_many_users(MAX_ACTIVE_FULL_USERS, CURRENT_ACTIVE_FULL_USERS)
    assert_read_only_team_member_check_box_disabled_for(@mingle_admin)
    assert_member_can_not_be_removed
    assert_project_admin_check_box_disabled_for(@mingle_admin)
    set_new_license_for_project(VALID_LICENSE_KEY, LICENSED_TO)
    navigate_to_team_list_for(@project)
    assert_error_message_not_present
    assert_read_only_team_member_check_box_enabled_for(@mingle_admin)
    assert_member_can_be_removed
    assert_project_admin_check_box_enabled_for(@mingle_admin)
    navigate_to_all_projects_page
    assert_new_project_link_present
    navigate_to_user_management_page
    assert_new_user_link_present    
  ensure
    @browser.reset_fake
  end
  
  def test_admin_can_be_deactived_by_other_admins_and_then_cannot_login
    set_new_license_for_project(VALID_LICENSE_KEY, LICENSED_TO)
    navigate_to_user_management_page
    check_administrator_check_box_for(@team_member)
    login_as_project_member
    navigate_to_user_management_page
    toggle_activation_for(@mingle_admin)
    login_as_admin_user    
    assert_error_message("The Mingle account for #{@mingle_admin.login} is no longer active. Please contact your Mingle administrator to resolve this issue.", :ignore_space => true)
  ensure
    login_as_project_member
    active_user(@mingle_admin)
  end
  
  #bug 2032
  def test_user_can_go_to_project_overview_page_after_registration_completion
    set_new_license_for_project(VALID_LICENSE_KEY, LICENSED_TO)
    assert_successful_registration_message
    assert_licence_registered_details
    click_done
    assert_project_link_present(@project)
  end
  
  #bug 1873, bug 1861
  def test_error_message_is_not_present_elsewhere_when_invalid_license_is_overwritten_with_valid_one
    set_new_license_for_project(VALID_LICENSE_KEY, LICENSED_TO)
    assert_licence_registered_details
    click_done
    navigate_to_register_mingle_page
    set_new_license_for_project(INVALID_LICENSE_KEY, LICENSED_TO)
    assert_invalid_license_error_message
    click_on_mingle_logo
    assert_error_message_not_present
    open_project(@project)
    assert_error_message_not_present
  end
  
  #bug 9443
  def test_only_correct_error_message_should_display_when_switching_to_light_user
    fake_now(2011, 6, 3)
    set_new_license_for_project(LIMITED_FULL_USER_LICENSE_KEY, LICENSED_TO) 
    navigate_to_user_management_page
    toggle_activation_for(@read_only_user)
    toggle_activation_for(@capitalized)
    toggle_activation_for(@existingbob)
    toggle_activation_for(@first)
    toggle_activation_for(@admin_not_on_project)    
    check_light_user_check_box_for(@team_member)
    check_light_user_check_box_for(@user_with_quotes)
    assert_license_violations_message_caused_by_too_many_users(5, 6, caused_by_full_user = true)
  ensure
    @browser.reset_fake
  end
  
end
