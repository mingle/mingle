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

# Tags: story, #39, wiki_2, history, tagging, card-page-history
class Story39ShowPageChangesInHistoryTest < ActiveSupport::TestCase 
  include MingleHelpersLoader    
  
  fixtures :users, :login_access  
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project = create_project(:prefix => 'story39', :users => [users(:project_member)])
    login_as_project_member
  end
  
  def test_show_page_create_events_in_history
   create_new_wiki_page @project, "Some_New_Page", "A first pass at creating a page"
   navigate_to_history_for @project, :today
   with @browser do 
     assert_element_present 'link-to-page-Some_New_Page'
     assert_element_matches 'page-Some_New_Page-1', /Created .* member@email.com/m
   end   
  end

  def test_show_page_content_edit_events_in_history
   create_new_wiki_page @project, "Some_New_Page", "A first pass at creating a page"
   @browser.open "/projects/#{@project.identifier}/wiki/Some_New_Page"
   @browser.click_and_wait "link=Edit"
   enter_text_in_editor "more content"
   @browser.click_and_wait "link=Save"
   navigate_to_history_for @project, :today
   with @browser do 
     assert_element_present 'link-to-page-Some_New_Page-1'
     assert_element_matches 'page-Some_New_Page-2', /Modified by member@email.com/m
     assert_element_matches 'page-Some_New_Page-2', /Content changed/m
   end   
  end
  
end

