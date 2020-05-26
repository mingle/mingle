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

# Tags: story, #143, svn, project, cards
class Story143PatternsForFindingCardRevisionsInSvnLogTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  def setup
    does_not_work_without_subversion_bindings do
      destroy_all_records(:destroy_users => false, :destroy_projects => true)
      @browser = selenium_session
      @driver = RepositoryDriver.new(name) do |driver|
        driver.initialize_with_test_data_and_checkout
      end
      login_as_admin_user
      @project_name = 'project_for_story_143'
      create_new_project_without_specified_pattern @project_name
      @project = Project.find_by_name(@project_name)
      @project.activate
      recreate_revisions_for(@project_name)
    end
  end

  def test_define_pattern_for_finding_card_revisions_in_project_setting
    does_not_work_without_subversion_bindings do
      prepare_revisions_for_card(1)
      @browser.open "/projects/#{@project_name}/cards/1"
      load_card_history
      @browser.assert_element_present 'revision-2'
      @browser.assert_element_present 'revision-3'
      @browser.assert_element_not_present 'revision-4'
      @browser.assert_element_not_present 'revision-5'

      change_card_matching_prefixs(@project_name, 'bug,card,#')

      @browser.open "/projects/#{@project_name}/cards/1"
      load_card_history
      @browser.assert_element_present 'revision-2'
      @browser.assert_element_present 'revision-3'
      @browser.assert_element_present 'revision-4'
      @browser.assert_element_not_present 'revision-5'

      change_card_matching_prefixs(@project_name, 'bug,defect,card,#')

      @browser.open "/projects/#{@project_name}/cards/1"
      load_card_history
      @browser.assert_element_present 'revision-2'
      @browser.assert_element_present 'revision-3'
      @browser.assert_element_present 'revision-4'
      @browser.assert_element_present 'revision-5'
    end
  end

  def test_should_fail_to_update_when_give_a_wrong_pattern
    does_not_work_without_subversion_bindings do
      change_card_matching_prefixs @project_name, '(()'
      @browser.assert_text_present "Card keywords are limited to words and the '#' symbol"
    end
  end

  def test_pattern_testing
    does_not_work_without_subversion_bindings do
      prepare_revisions_for_card(2)
      @prefixs_in_setting_page = 'feature'
      @browser.open '/projects/project_for_story_143'
      @browser.click_and_wait "link=Project admin"
      @browser.click_and_wait "link=Card keywords"
      @browser.type 'project[card_keywords]', @prefixs_in_setting_page
      @browser.with_ajax_wait do
        @browser.click "name=show-matched"
      end
      assert_prefixs_in_setting_page_will_be_brought_to_the_lightbox
      assert_give_error_message_when_pattern_is_invalid
      assert_show_revisions_with_given_pattern_and_card_number
    end
  end

  # bug 7678
  def test_should_render_card_links_in_commit_messages_when_card_identifiers_separated_by_slash
    does_not_work_without_subversion_bindings do
      create_new_card @project, :name =>"story 1", :description => 'for story 1'
      commit_with_message("add for #1/#2")
      recreate_revisions_for(@project_name)
      
      @browser.open "/projects/#{@project_name}/cards/1"
      load_card_history
      assert_link_present("/projects/#{@project.identifier}/cards/1")
      assert_link_present("/projects/#{@project.identifier}/cards/2")
    end
  end

  def assert_prefixs_in_setting_page_will_be_brought_to_the_lightbox
    @browser.assert_value 'project[card_keywords]', @prefixs_in_setting_page
    @browser.assert_value 'card_number', '1'
  end

  def assert_give_error_message_when_pattern_is_invalid
    @browser.type 'project[card_keywords]', "()(/))))"
    @browser.with_ajax_wait do
      @browser.click 'name=show-matched'
    end
    @browser.assert_text_present "Card keywords are limited to words and the '#' symbol"
  end

  def assert_show_revisions_with_given_pattern_and_card_number
    @browser.type 'project[card_keywords]', ''
    @browser.type 'card_number', '2'
    @browser.with_ajax_wait do
      @browser.click 'name=show-matched'
    end

    @browser.assert_element_not_present 'revision-4'
    @browser.assert_element_not_present 'revision-5'
    @browser.assert_ordered 'revision-3', 'revision-2'

    @browser.type 'project[card_keywords]', 'bug, defect'
    @browser.type 'card_number', '2'
    @browser.with_ajax_wait do
      @browser.click 'name=show-matched'
    end
  end

  private

  def create_new_project_without_specified_pattern(project)
    create_new_project(project)
    navigate_to_subversion_repository_settings_page(project)
    type_project_repos_path(@driver.repos_dir)
    click_save_settings_link
  end

  def change_card_matching_prefixs(project, prefixs)
    @browser.open("/projects/#{project}")
    @browser.click_and_wait "link=Project admin"
    @browser.click_and_wait "link=Card keywords"
    @browser.assert_element_editable 'project[card_keywords]'
    @browser.type 'project[card_keywords]', prefixs
    @browser.click_and_wait 'link=Update keywords'
    Project.current.reload
    recreate_revisions_for(@project_name)
  end

  def commit_with_message(message)
    @driver.unless_initialized do
      @driver.commit_file_with_comment 'test.txt', "just for test", message
    end
  end

  def prepare_revisions_for_card(card_number)
    create_new_card @project, :name =>"story #{card_number}", :description => 'for story 143'
    @driver.unless_initialized do
      @driver.commit_file_with_comment 'test.txt', "just for test", "add for card #{card_number}"
      @driver.update_file_with_comment 'a.txt', 'modified', "update for ##{card_number}"
      @driver.update_file_with_comment 'test.txt', 'modified', "update for bug #{card_number}"
      @driver.update_file_with_comment 'test.txt', 'modified again', "update for defect #{card_number}"
    end
    recreate_revisions_for(@project_name)
  end

end
