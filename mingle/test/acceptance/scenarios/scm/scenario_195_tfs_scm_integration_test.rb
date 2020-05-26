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

# Tags: svn
class Scenario195TfsScmIntegrationTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project = create_project(:prefix => 'scenario_195', :admins => [users(:proj_admin)], :users => [users(:admin)])   

  end

  def teardown
    @project.deactivate
  end

  def test_tfs_scm_integration_error_scenarios_test
     login_as_admin_user
     navigate_to_project_repository_settings_page(@project)
     select_scm_type('Team Foundation Server') 

     # no data entered
     click_save_settings_link
     assert_error_message "Server url can't be blank, Collection can't be blank, Tfs project can't be blank, Domain can't be blank, Username can't be blank, Password can't be blank"

     navigate_to_project_repository_settings_page(@project)
     select_scm_type('Git') 

     # no data entered
     click_save_settings_link
     assert_error_message "Repository path can't be blank"

     navigate_to_project_repository_settings_page(@project)
     select_scm_type('Mercurial') 

     # no data entered
     click_save_settings_link
     assert_error_message "Repository path can't be blank"
  end

end

