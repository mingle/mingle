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

# Tags: story, #84, wiki_2, navigation
class Story84LinkPageToPageTest < ActiveSupport::TestCase 
  
  fixtures :users, :login_access  
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project = create_project(:prefix => 'story84', :users => [users(:project_member)])
    login_as_project_member
  end
  
  def test_link_page_to_page
    @browser.open("/projects/#{@project.identifier}/wiki/First_Page")
    enter_text_in_editor 'Following is a link to the [[Next Wiki Page]] which has interesting content.'
    @browser.click_and_wait 'link=Save'
    @browser.click_and_wait 'link=Next Wiki Page'
    @browser.assert_location "/projects/#{@project.identifier}/wiki/Next_Wiki_Page"
    enter_text_in_editor 'Here is some interesting content with [[a link]]'
    @browser.click_and_wait 'link=Save'
    @browser.assert_location "/projects/#{@project.identifier}/wiki/Next_Wiki_Page"
    @browser.assert_text_present 'Here is some interesting content'
  end

end
