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

# Tags: story, #33, svn, navigation
class Story33ShowDirectoriesOfSvnRepositoryTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  does_not_work_without_subversion_bindings

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @driver = RepositoryDriver.new(name) do |driver|
      driver.create
      driver.import("#{Rails.root}/test/data/test_repository")
    end

    @browser = selenium_session
    @project = create_project(:prefix => 'story33', :users => [users(:admin)])
    login_as_admin_user
    navigate_to_subversion_repository_settings_page(@project)
    type_project_repos_path(@driver.repos_dir)
    @browser.click_and_wait('link=Save settings')
  end

  def test_show_directories_of_svn_repository
    @browser.open("/projects/#{@project.identifier}")
    click_source_tab

    @browser.click_and_wait 'link=dir1'
    @browser.assert_text_present 'b.txt'
    @browser.click_and_wait 'link=../'
    @browser.assert_text_not_present 'b.txt'
    @browser.assert_text_present 'dir1'
  end
  
  def test_svn_repository_should_display_correctly_even_without_directories
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @driver = RepositoryDriver.new('repository without dir') do |driver|
      driver.create
      driver.import("#{Rails.root}/test/data/repository_without_dir")
    end

    @browser = selenium_session
    @project = create_project(:prefix => 'story33', :users => [users(:admin)])
    login_as_admin_user
    navigate_to_subversion_repository_settings_page(@project)
    type_project_repos_path(@driver.repos_dir)
    @browser.click_and_wait('link=Save settings')
    
    @browser.open("/projects/#{@project.identifier}")
    click_source_tab
    
    @browser.assert_element_present("link=bug_one.txt")
    @browser.assert_element_present("link=bug_two.txt")
  end

  def test_browser_revision
    content = "sample code change"
    commit_log = "change a.txt for testing"

    @driver.unless_initialized do
      @driver.checkout
      @driver.update_file_with_comment 'a.txt', content, commit_log
    end

    @browser.open("/projects/#{@project.identifier}")
    click_source_tab
    @browser.assert_value 'rev', 'HEAD'
    @browser.assert_text_present commit_log
    @browser.type 'rev', '1'
    @browser.click_and_wait 'name=commit'
    @browser.assert_text_not_present commit_log

    #testing not existing revision
    @browser.type 'rev', '33'
    @browser.click_and_wait 'name=commit'
    @browser.assert_text_present 'No such revision 33, showing youngest revision'
    @browser.assert_value 'rev', 'HEAD'
  end

  # for bug 379
  def test_show_file_list_of_svn_repository_in_order
    content = "sample code"
    commit_log = "for bug 379"

    @driver.unless_initialized do
      @driver.checkout
      @driver.commit_dir_with_comment 'another_dir', 'add new dir'
      @driver.commit_file_with_comment "another_dir/bug.txt", content, commit_log
      @driver.commit_file_with_comment 'c.txt', content, commit_log
      @driver.commit_file_with_comment 'another_dir/another_new.txt', content, commit_log
    end

    @browser.open("/projects/#{@project.identifier}")
    click_source_tab
    @browser.assert_ordered 'source_list_another_dir', 'source_list_dir1'
    @browser.assert_ordered 'source_list_dir1', 'source_list_a.txt'
    @browser.assert_ordered 'source_list_a.txt', 'source_list_c.txt'

    @browser.click_and_wait 'link=another_dir'
    @browser.assert_ordered 'source_list_another_new.txt', 'source_list_bug.txt'
  end

end
