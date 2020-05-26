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

# Tags: card-page-history
class Story60DisplayCardVersionsTest < ActiveSupport::TestCase 
  
  fixtures :users, :login_access  
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    login_as_project_member

    @project = create_project(:prefix => 'story60', :users => [users(:project_member)])
    setup_property_definitions :status => ['new'], :iteration => [1]
    @card =create_card!(:name => 'first card', :description => 'initial description')
    @card.update_attributes(:cp_status => 'new', :cp_iteration => '1')
    @card.reload
    @card.update_attributes(:description => 'changed description')
    @card.reload
    @project.save_with_validation(false)
  end
  
  def test_navigate_to_previous_version
    @browser.run_once_history_generation
    @browser.open("/projects/#{@project.identifier}/cards/#{@card.number}")
    load_card_history
    @browser.assert_element_present 'link-to-card-1-1'
    @browser.assert_element_present 'link-to-card-1-2'
    @browser.assert_text_present 'Version 3'
    
    @browser.click_and_wait 'link-to-card-1-1'
    assert_properties_not_set_on_card_show(:status, :iteration)
    sleep 10
    load_card_history
    @browser.click_and_wait 'link-to-card-1-2'
    assert_properties_set_on_card_show(:status => 'new', :iteration => '1')
    @browser.assert_text 'content', 'initial description'
    @browser.assert_element_not_present 'link-to-card-1-2'
  end
end
