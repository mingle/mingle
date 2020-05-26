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

# Tags: story, #55, svn, cards, history
if defined? Repository::Svn
  class Story55ShowRevisionsForCardTest < ActiveSupport::TestCase
    
    fixtures :users, :login_access  
  
    def setup
      destroy_all_records(:destroy_users => false, :destroy_projects => true)
      login_as_admin

      @driver = RepositoryDriver.new(name) do |driver|
        driver.initialize_with_test_data_and_checkout
        driver.commit_file_with_comment 'new_file.txt', 'some content', 'added new_file.txt for card 11'
        driver.commit_file_with_comment 'another_file.txt', 'more content', 'added another_file for card 1'
        driver.commit_file_with_comment 'third_file.txt', 'some content', 'third file for card 1'
      end

      @project = create_project(:prefix => 'story55', :users => [users(:project_member)], :repository_path => @driver.repos_dir)
      setup_property_definitions :iteration => ['1'], :status => ['new', 'open', 'in progress']
      
      card =create_card!(:name => "first card", :status => 'new')
      card.update_attribute(:cp_iteration, '1')
      card.update_attribute(:cp_status, 'open')
      card.update_attribute(:cp_status, 'in progress')

      recreate_revisions_for(@project.reload)
      @browser = selenium_session
      login_as_project_member
    end
    
    def teardown
      @project.deactivate
    end

    def test_shows_revisions
      @browser.open("/projects/#{@project.identifier}/cards/1")  
      load_card_history
      @browser.assert_text_not_present 'added new_file.txt for card 11'
      @browser.assert_element_present 'revision-4'
      @browser.assert_element_present 'revision-3'
      @browser.assert_ordered 'revision-4', 'revision-3'      
    end

  end
end
