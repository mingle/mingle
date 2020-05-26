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

class UpgradeTest01 < ActiveSupport::TestCase
  # PROJECT_1 = ARGV[0]

  def setup
    @browser = selenium_session
    @user = @browser
    @browser.open('/')
  end
  
  def teardown
    self.class.close_selenium_sessions
  end
    
  def test_01_user_can_go_through_the_initially_upgrade_steps
    p "--------------------------------------------------------------------"
    p "          Go through all the upgrade intallation steps              "
    p "--------------------------------------------------------------------"
    @browser.click(my_css_locator('button[type="submit"]'))
    @browser.wait_for_page_to_load(120000)
    @browser.click('next')
    @browser.wait_for_element_present('eula_accepted')
    @browser.click('eula_accepted')
    @browser.wait_for_all_ajax_finished
    @browser.click('next')
    @browser.wait_for_page_to_load(120000)
    log_in_upgraded_instance_as_admin
    @browser.wait_for_page_to_load(120000)
    @browser.wait_for_element_present('next')
    @browser.click('next')
  end
  
end
