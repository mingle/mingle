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

require File.expand_path(File.dirname(__FILE__) + '/upgrade_test_env_helper.rb')
require File.expand_path(File.dirname(__FILE__) + '/upgrade_test_assertions.rb')
require File.expand_path(File.dirname(__FILE__) + '/upgrade_test_helper.rb')
include UpgradeTestAssertions
include UpgradeTestHelper

class UpgradeTest03 < ActiveSupport::TestCase
  
  # PROJECT_1 = ARGV[0]
  
  # TARGET_PROJECT = get_project_name
  # TEST_DATA_DIR = get_test_data_dir
  
  PROJECT_IDENTIFIER = "project_#{ENV['MIGRATE_FROM']}"
  # PROJECT_IDENTIFIER = "project_pg_2_3_1"
  DATA_FOLDER = File.expand_path("test/upgrade_test_automation/data")

      
  def setup
    @browser = selenium_session
    @user = @browser
    navigate_to_all_projects_page
  end
  
  def teardown
    self.class.close_selenium_sessions
  end
  
 #bulk delete all cards in one page
  def test_01_all_default_templates_have_been_imported
    p "--------------------------------------------------------------------"
    p "              verify all tempates have been imported                "
    p "--------------------------------------------------------------------"
    sleep 240
    log_in_upgraded_instance_as_admin 
    @browser.click_and_wait("link=Manage project templates")
    @browser.assert_element_present('link=Agile hybrid template(3.0)')
    @browser.assert_element_present('Scrum template(3.0)')
    @browser.assert_element_present('Story tracker template(3.0)')
    @browser.assert_element_present('Xp template(3.0)')
  end 
end
