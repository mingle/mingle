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

# Tags: scenario, new_user_role, user
class Scenario109LightUserTest < ActiveSupport::TestCase
  fixtures :users, :login_access  
  
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
    @project = create_project(:prefix => 'scenario_109_project', :users => [@team_member], :admins => [@mingle_admin, @project_admin])
    login_as_admin_user
  end
  
  def teardown
    reset_license
  end
  
  def test_team_member_will_become_read_only_team_member_if_it_is_updated_to_be_a_light_user
    login_as_admin_user
    navigate_to_team_list_for(@project)
    assert_user_is_team_member(@team_member)
    navigate_to_user_management_page
    check_light_user_check_box_for(@team_member)
    navigate_to_team_list_for(@project)
    assert_user_is_read_only_team_member(@team_member)
  end
  
  def test_light_user_can_be_only_added_as_read_only_team_member
    login_as_admin_user
    navigate_to_register_mingle_page
    navigate_to_user_management_page
    check_light_user_check_box_for(@longbob)
    add_readonly_member_to_team_for(@project, @longbob)
    assert_user_is_read_only_team_member(@longbob)
    assert_project_admin_check_box_disabled_for(@longbob)
    assert_read_only_team_member_check_box_disabled_for(@longbob)
  end
  
  def test_if_existing_light_user_is_updated_to_be_a_full_member_they_will_retain_their_old_project_access
    login_as_admin_user
    navigate_to_user_management_page
    check_light_user_check_box_for(@team_member)
    navigate_to_team_list_for(@project)
    assert_user_is_read_only_team_member(@team_member)
    navigate_to_user_management_page
    check_light_user_check_box_for(@team_member)
    navigate_to_team_list_for(@project)
    assert_user_is_normal_team_member(@team_member)
    assert_member_can_be_removed
    assert_project_admin_check_box_enabled_for(@team_member)
  end
  
  def test_team_member_and_project_admin_option_should_be_disabled_for_light_user
    login_as_admin_user
    navigate_to_user_management_page
    check_light_user_check_box_for(@team_member)
    navigate_to_team_list_for(@project)
    assert_user_is_read_only_team_member(@team_member)
    assert_project_admin_check_box_disabled_for(@team_member)
  end
  
end
