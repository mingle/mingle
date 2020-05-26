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

# Tags: scenario, user, mingle-admin
class Scenario30MingleAdminTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  PASSWORD_FOR_LONGBOB_USER = 'longtest'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @admin_user = users(:admin)
    @longbob_user = users(:longbob)
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_30', :users => [@admin_user])
  end

  def test_during_project_creation_mingle_admin_can_elect_to_be_team_member_by_default
    project = 'foo'
    login_as_admin_user
    create_new_project(project)
    assert_mingle_user_is_team_member_for(project, @admin_user)
    add_full_member_to_team_for(project, @longbob_user)
    login_as(@longbob_user.login, PASSWORD_FOR_LONGBOB_USER)
    assert_mingle_user_is_team_member_for(project, @admin_user)
  end

  # bug 1548
  def test_mingle_admin_can_remove_themselves_as_project_team_member
    login_as_admin_user
    assert_mingle_user_is_team_member_for(@project, @admin_user)
    remove_from_team_for(@project, @admin_user)
    assert_mingle_user_not_team_member_for(@project, @admin_user)
  end

  def test_during_project_creation_mingle_admin_can_elect_to_not_be_a_team_member
    project = 'foo'
    login_as_admin_user
    create_new_project(project, :as_member => false)
    assert_mingle_user_not_team_member_for(project, @admin_user)
    add_full_member_to_team_for(project, @longbob_user)
    login_as(@longbob_user.login, PASSWORD_FOR_LONGBOB_USER)
    assert_mingle_user_not_team_member_for(project, @admin_user)
  end

  def test_mingle_admin_can_make_another_user_a_mingle_admin
    login_as_admin_user
    navigate_to_user_management_page
    check_administrator_check_box_for(@longbob_user)
    logout
    login_as(@longbob_user.login, PASSWORD_FOR_LONGBOB_USER)
    navigate_to_user_management_page
    assert_user_is_mingle_admin(@longbob_user)
  end

  def test_mingle_admin_can_add_project_admins
    login_as_admin_user
    add_to_team_as_project_admin_for(@project, @longbob_user)
    logout
    login_as(@longbob_user.login, PASSWORD_FOR_LONGBOB_USER)
    navigate_to_team_list_for(@project)
    assert_user_is_project_admin(@longbob_user)
  end

  def test_mingle_admin_can_edit_other_users
    new_password = 'n3wpwd!'
    new_full_name = 'long bob user'
    new_email = 'this.is.longbob@foo.com'
    new_version_control_name = 'THE long bob'

    login_as_admin_user
    navigate_to_user_management_page
    click_show_profile_for(@longbob_user)
    click_edit_profile
    @browser.type('user_name', new_full_name)
    @browser.type('user_email', new_email)
    @browser.type('user_version_control_user_name', new_version_control_name)
    click_save_profile_button

    navigate_to_user_management_page
    click_change_password_for(@longbob_user)
    @browser.type('user_password', new_password)
    @browser.type('user_password_confirmation', new_password)
    click_change_password_button

    logout
    login_as(@longbob_user.login, new_password)
    @browser.click_and_wait(profile_for_user_name_link(new_full_name))
    click_edit_profile
    @browser.assert_value('user_name', new_full_name)
    @browser.assert_value('user_email', new_email)
    @browser.assert_value('user_version_control_user_name', new_version_control_name)
  end

  def test_advanced_admin_page_is_visiable_for_mingle_admin
    login_as_admin_user
    open_project_admin_for(@project)
    assert_advanced_project_admin_link_is_present(@project)
  end
end
