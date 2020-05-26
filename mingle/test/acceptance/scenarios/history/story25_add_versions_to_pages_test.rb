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

# Tags: history, card-page-history
class Story25AddVersionsToPagesTest < ActiveSupport::TestCase 
  
  fixtures :users, :login_access  
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @project = create_project(:prefix => 'story25', :users => [users(:project_member)])
    @browser = selenium_session
    login_as_project_member
  end
  
  def teardown
    @project.deactivate
  end
  
  def test_creating_a_overview_page_creates_first_version
    create_new_wiki_page @project, "Overview_Page", "A first pass at creating a overview page"
    @browser.open "/projects/#{@project.identifier}"
    load_page_history
    @browser.assert_text_present "A first pass at creating a overview page"
    @browser.assert_text_present "Version 1"
  end

  def test_editing_the_overview_existing_page_creates_new_version
    create_new_wiki_page @project, "Overview_Page", "A first pass at creating a overview page"
    @browser.open "/projects/#{@project.identifier}"
    @browser.click_and_wait "link=Edit"
    enter_text_in_editor "A second attempt at the overview page"
    @browser.click_and_wait 'link=Save'
    load_page_history
    @browser.assert_element_present "link-to-page-Overview_Page-1"
    @browser.assert_text_present "Version 2"
  end

  def test_switching_between_versions_of_the_overview_page
    create_new_wiki_page @project, "Overview_Page", "A first pass at creating a overview page"
    @browser.open "/projects/#{@project.identifier}"
    @browser.click_and_wait "link=Edit"
    enter_text_in_editor "A second attempt at the overview page"
    @browser.click_and_wait 'link=Save'

    @browser.click_and_wait "link=Edit"
    enter_text_in_editor "A third attempt at the overview page"
    @browser.click_and_wait 'link=Save'

    load_page_history
    @browser.click_and_wait "link-to-page-Overview_Page-1"
    @browser.assert_text_present "A first pass at creating a overview page"
    
    load_page_history
    @browser.click_and_wait "link-to-page-Overview_Page-2"
    @browser.assert_text_present "A first pass at creating a overview page"
  end  

end
