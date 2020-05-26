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

# Tags: page
class Scenario20PageChangeEventsTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  OVERVIEW_PAGE = "Overview_Page"
  ANOTHER_PAGE = 'another_page'

  MEMBER_USER_EMAIL = 'member@email.com'
  ADMIN_USER_EMAIL = 'admin@email.com'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project = create_project(:prefix => 'scenario_20', :users => [users(:project_member)])
    login_as_project_member

    create_new_wiki_page(@project, OVERVIEW_PAGE, 'overview page content')
    create_new_wiki_page(@project, ANOTHER_PAGE, 'wiki page content')
  end

  def test_page_creation_event_shows_on_history_with_correct_user
    load_page_history
    assert_page_history_for(:page, ANOTHER_PAGE).version(1).shows(:created_by => MEMBER_USER_EMAIL)
    open_wiki_page(@project, OVERVIEW_PAGE)
    load_page_history
    assert_page_history_for(:page, OVERVIEW_PAGE).version(1).shows(:created_by => MEMBER_USER_EMAIL)

    navigate_to_history_for @project
    assert_page_history_for(:page, OVERVIEW_PAGE).version(1).shows(:created_by => MEMBER_USER_EMAIL)
    assert_page_history_for(:page, ANOTHER_PAGE).version(1).shows(:created_by => MEMBER_USER_EMAIL)
  end

  def test_page_change_events_show_correct_user
    load_page_history
    assert_page_history_for(:page, ANOTHER_PAGE).version(1).shows(:created_by => MEMBER_USER_EMAIL)

    open_wiki_page(@project, OVERVIEW_PAGE)
    load_page_history
    assert_page_history_for(:page, OVERVIEW_PAGE).version(1).shows(:created_by => MEMBER_USER_EMAIL)

    navigate_to_history_for @project
    assert_page_history_for(:page, OVERVIEW_PAGE).version(1).shows(:created_by => MEMBER_USER_EMAIL)
    assert_page_history_for(:page, ANOTHER_PAGE).version(1).shows(:created_by => MEMBER_USER_EMAIL)

    logout
    login_as_admin_user
    edit_page(@project, OVERVIEW_PAGE, 'placeholder')
    load_page_history
    assert_page_history_for(:page, OVERVIEW_PAGE).version(2).shows(:modified_by => ADMIN_USER_EMAIL)

    edit_page(@project, ANOTHER_PAGE, 'placeholder')
    load_page_history
    assert_page_history_for(:page, ANOTHER_PAGE).version(2).shows(:modified_by => ADMIN_USER_EMAIL)

    navigate_to_history_for @project
    assert_page_history_for(:page, OVERVIEW_PAGE).version(2).shows(:modified_by => ADMIN_USER_EMAIL)
    assert_page_history_for(:page, ANOTHER_PAGE).version(2).shows(:modified_by => ADMIN_USER_EMAIL)
  end

  def test_changing_page_content_creates_page_events
    edit_page(@project, OVERVIEW_PAGE, 'added new content')
    load_page_history
    assert_page_history_for(:page, OVERVIEW_PAGE).version(2).shows(:changed => 'Content')

    edit_page(@project, ANOTHER_PAGE, 'new page stuff')
    load_page_history
    assert_page_history_for(:page, ANOTHER_PAGE).version(2).shows(:changed => 'Content')

    navigate_to_history_for @project
    assert_page_history_for(:page, OVERVIEW_PAGE).version(2).shows(:changed => 'Content')
    assert_page_history_for(:page, ANOTHER_PAGE).version(2).shows(:changed => 'Content')
  end

  def test_opening_for_edit_then_cancelling_or_publishing_without_making_changes_doesnt_create_event
    open_for_edit OVERVIEW_PAGE
    click_cancel_link
    load_page_history
    assert_page_history_for(:page, OVERVIEW_PAGE).version(3).not_present

    open_for_edit ANOTHER_PAGE
    click_cancel_link
    load_page_history
    assert_page_history_for(:page, ANOTHER_PAGE).version(3).not_present

    navigate_to_history_for @project
    assert_page_history_for(:page, OVERVIEW_PAGE).version(3).not_present
    assert_page_history_for(:page, ANOTHER_PAGE).version(3).not_present

    open_for_edit OVERVIEW_PAGE
    publish
    load_page_history
    assert_page_history_for(:page, OVERVIEW_PAGE).version(3).not_present

    open_for_edit ANOTHER_PAGE
    publish
    load_page_history
    assert_page_history_for(:page, ANOTHER_PAGE).version(3).not_present

    navigate_to_history_for @project
    assert_page_history_for(:page, OVERVIEW_PAGE).version(3).not_present
    assert_page_history_for(:page, ANOTHER_PAGE).version(3).not_present
  end

  def test_different_user_opening_but_not_making_changes_doesnt_create_event
    logout
    login_as_admin_user

    open_for_edit OVERVIEW_PAGE
    click_cancel_link
    load_page_history
    assert_page_history_for(:page, OVERVIEW_PAGE).version(3).not_present

    open_for_edit ANOTHER_PAGE
    click_cancel_link
    load_page_history
    assert_page_history_for(:page, ANOTHER_PAGE).version(3).not_present

    navigate_to_history_for @project
    assert_page_history_for(:page, OVERVIEW_PAGE).version(3).not_present
    assert_page_history_for(:page, ANOTHER_PAGE).version(3).not_present

    open_for_edit OVERVIEW_PAGE
    publish
    load_page_history
    assert_page_history_for(:page, OVERVIEW_PAGE).version(3).not_present

    open_for_edit ANOTHER_PAGE
    publish
    load_page_history
    assert_page_history_for(:page, ANOTHER_PAGE).version(3).not_present

    navigate_to_history_for @project
    assert_page_history_for(:page, OVERVIEW_PAGE).version(3).not_present
    assert_page_history_for(:page, ANOTHER_PAGE).version(3).not_present
  end

  def test_show_page_attachment_change_events_in_history
    page_name = "page"
    file_name = 'attachment.jpg'
    file_name_2 = 'attachment.txt'
    attachment = Attachment.create!(:file => sample_attachment(file_name), :project => @project)
    attachment_2 = Attachment.create!(:file => sample_attachment(file_name_2), :project => @project)

    create_new_wiki_page(@project, page_name, "content")
    page = @project.pages.find_by_name(page_name)
    attach_file_on_page(page, file_name)
    @browser.run_once_history_generation
    open_wiki_page_for_edit(@project, page_name)
    @browser.click(class_locator("dz-remove"))
    @browser.get_confirmation
    click_save_link
    @browser.run_once_history_generation
    load_page_history
    assert_page_history_for(:page, page_name).version(2).shows(:attachment_added => file_name)
    assert_page_history_for(:page, page_name).version(3).shows(:attachment_removed => file_name)

    navigate_to_history_for @project, :today
    assert_page_history_for(:page, page_name).version(2).shows(:attachment_added => file_name)
    assert_page_history_for(:page, page_name).version(3).shows(:attachment_removed => file_name)
  end

  private
  def open_for_edit(page_name)
    open_wiki_page @project, page_name
    @browser.click_and_wait "link=Edit"
    wait_for_wysiwyg_editor_ready
  end

  def publish
    @browser.click_and_wait 'link=Save'
  end

end
