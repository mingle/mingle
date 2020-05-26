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

class UpgradeTest05 < ActiveSupport::TestCase
  # PROJECT_1 = ARGV[0]

  TAG_NAME1 = 'Bush_tagged'
  TAG_NAME2 = 'Obama_tagged'
  TAG_NAME3 = 'Terminator_Tagged'
  
  CARD_NAME = 'new_card'
  
  def setup
    @browser = selenium_session
    @user = @browser
  end
  
  def teardown
    p "log out"
    logout
  end
  
  def test_00_welcom_message
    p "You are getting into upgrade_test_05"  
  end
  
  def test_01_all_template_are_loadded
    p "check all the tempates had been loaded."
    navigate_to_template_management_page
    log_in_upgraded_instance_as_admin
    assert_template_present(TEMPLATE1)
    assert_template_present(TEMPLATE2)
    assert_template_present(TEMPLATE3)
    assert_template_present(TEMPLATE4)
  end
  

  def test_02_hg_repo_had_been_cached
    
  end
  

end
