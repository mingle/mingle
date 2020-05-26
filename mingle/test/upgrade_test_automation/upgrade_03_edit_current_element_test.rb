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
  TARGET_PROJECT = get_project_name
  NEW_CARD_NAME = 'new card name from excel import'
  
  def setup
    @browser = selenium_session
    @user = @browser
    @project = Project.find_by_identifier(TARGET_PROJECT)
    @project.activate
  end
  
  def teardown
    logout
  end
  
  def test_00_welcom_message
    p "You are getting into upgrade_test_03"  
  end
  
  def test_01_update_card_name_via_excel_import
    p "test_01 update the 5th card's name to '#{NEW_CARD_NAME}'in proejct '#{TARGET_PROJECT}' via excel import"
    # card_1 = @project.cards.find_by_name('Release2')
    card = @project.cards.find_by_number(5)
    header_row = [['Number', 'Name']]
    card_data = [[card.number, NEW_CARD_NAME]]
    navigate_to_card_list_for(@project)
    log_in_upgraded_instance_as_admin
    import(excel_copy_string(header_row, card_data), :timeout => 200000)
    # @browser.run_once_history_generation
    # open_card(@project, card.number)
    # assert_history_for(:card, card.number).version(2).shows(:tags_removed => 'foo bar', :tagged_with => 'uxp', :tagged_with => 'scope', 
    #   :set_properties => {:release => '14'}, :unset_properties => {:status => 'new'})
    open_card(@project, card.number)
    assert_card_name_in_show(NEW_CARD_NAME)
  end
end
