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
 


# Tags: story, #153, svn, navigation
class Story153ShowDetailsOfSvnRevisionTest < ActiveSupport::TestCase
  
  fixtures :users, :login_access  

  does_not_work_without_subversion_bindings

  def setup
    @browser = selenium_session
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
        
    @driver = RepositoryDriver.new(name) do |driver|
      driver.create
      driver.import("#{Rails.root}/test/data/test_repository")
      driver.checkout      
      driver.update_file_with_comment 'a.txt', 'some content', 'modified a.txt'
      driver.update_file_with_comment 'a.txt', 'more content', 'modified a.txt again'
    end
    
    @project = create_project(:prefix => 'story153', :users => [users(:project_member)], :repository_path => @driver.repos_dir)
    @project.cache_revisions
    cache_revisions_content_for @project
    login_as_project_member
  end

  def test_view_revision
    @browser.open("/projects/#{@project.identifier}/revisions/3")

    @browser.assert_text_present('Revision 3')
    @browser.assert_text_present('modified a.txt again')
    @browser.assert_text_present('/a.txt')
    @browser.assert_text_present('more content') # checks for the diff
    @browser.assert_element_not_present('link=Next revision')

    @browser.click_and_wait('link=Previous revision')
    @browser.assert_text_present('Revision 2')
    @browser.assert_text_present('modified a.txt')
    @browser.assert_text_present('/a.txt')
    @browser.assert_text_present('some content') # checks for the diff
    @browser.assert_element_present('link=Next revision')

    @browser.click_and_wait('link=Previous revision')
    @browser.assert_text_present('Revision 1')
    @browser.assert_text_not_present('link=Previous revision')

    @browser.click_and_wait('link=Next revision')
    @browser.assert_text_present('Revision 2')
  end

end
