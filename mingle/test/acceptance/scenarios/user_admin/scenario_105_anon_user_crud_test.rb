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

# Tags: scenario, new_user_role, user, anonymous
class Scenario105AnonUserCrudTest < ActiveSupport::TestCase
  
  fixtures :users, :login_access  
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin = users(:proj_admin)
    @team_member = users(:project_member)
    @read_only_user = users(:bob)
    @mingle_admin = users(:admin)
    register_license_that_allows_anonymous_users
    @project = create_project(:prefix => 'scenario_105_project', :users => [@team_member], :admins => [@mingle_admin, @project_admin])
  end
  
  def test_license_with_anon_user_entieled_enable_anon_user_crud
    register_default_license
    login_as_admin_user
    navigate_to_project_admin_for(@project)
    assert_project_anonymous_accessible_not_present
    logout
    navigate_to_all_projects_page
    assert_located_at_login_page
    
    register_license_that_allows_anonymous_users
    login_as_admin_user
    navigate_to_project_admin_for(@project)
    assert_project_anonymous_accessible_present
    enable_project_anonymous_accessible_on_project_admin_page
    logout
    navigate_to_all_projects_page
    assert_project_link_present(@project)  
  end
  
  def test_license_without_anon_user_entieled_disable_anon_user_crud
    login_as_admin_user
    navigate_to_project_admin_for(@project)
    assert_project_anonymous_accessible_present
    enable_project_anonymous_accessible_on_project_admin_page
    logout
    navigate_to_all_projects_page
    assert_project_link_present(@project)  
    
    reset_license
    login_as_admin_user
    navigate_to_project_admin_for(@project)
    assert_project_anonymous_accessible_not_present
    logout
    navigate_to_all_projects_page
    assert_located_at_login_page
  end
  
  def test_on_create_project_to_enable_anon_user_access
    project = create_project(:prefix => 'for_anon_user', :users => [@team_member], :admins => [@mingle_admin, @project_admin], :read_only_users => [@read_only_user], :anonymous_accessible => true)
    navigate_to_all_projects_page
    assert_project_link_present(project)
    assert_project_link_not_present(@project)
  end
  
  def test_on_mingle_admin_and_proj_admin_update_project_to_enable_and_disable_anon_user_access   
    project = create_project(:prefix => 'project2', :users => [@team_member], :admins => [@mingle_admin, @project_admin], :read_only_users => [@read_only_user], :anonymous_accessible => true)
    login_as_admin_user
    navigate_to_project_admin_for(@project)
    enable_project_anonymous_accessible_on_project_admin_page
    logout    
    navigate_to_all_projects_page
    assert_project_link_present(@project)
    assert_project_link_present(project)
    
    login_as_proj_admin_user
    navigate_to_project_admin_for(@project)
    disable_project_anonymous_accessible_on_project_admin_page
    logout
    navigate_to_all_projects_page
    assert_project_link_not_present(@project)
    assert_project_link_present(project) 
  end
end
