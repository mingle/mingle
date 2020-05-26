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

# Tags: story, #97, cards, card-page-history
class Story97ShowCardHistoryAtCardPageTest < ActiveSupport::TestCase 
  
  fixtures :users, :login_access  

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    login_as_project_member   
    
    @project = create_project(:prefix => 'story97', :users => [users(:project_member)])
    setup_property_definitions :Status => ['new'], :Feature => ['email']
  end
        
  def test_show_event_history_in_card_page
    #create card #1
    navigate_to_card_list_for @project
    card_name  = "Add contact to address book"
    create_new_card(@project, :name => card_name, :status => 'new', :feature => 'email')
    
    #then there should be create event in card show page
    navigate_to_card(@project, card_name)
    load_card_history
    @browser.assert_element_matches 'card-1-1', /Created .* member@email.com/m
    @browser.assert_element_matches 'card-1-1', /Feature set to email/m
    @browser.assert_element_matches 'card-1-1', /Status set to new/m
    # @browser.assert_element_matches 'card-1-1', /years ago/m
    
    #create another card 
    create_new_card @project, :name => "another card"
    
    #assert event of card 2 not in card 1's place
    navigate_to_card(@project, card_name)
    load_card_history
    @browser.assert_element_not_present 'card-2-1'
    
    #update card
    edit_card(:description => "add new descriptioins")
    
    #then 2 event should be in card page
    navigate_to_card(@project, card_name)
    load_card_history
    @browser.assert_element_present 'card-1-2'
  end

end
