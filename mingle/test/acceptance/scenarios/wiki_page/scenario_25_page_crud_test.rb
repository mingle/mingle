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

# Tags: scenario, bug, wiki_2
class Scenario25PageCrudTest < ActiveSupport::TestCase

  fixtures :users, :login_access
  WIKI_NAME = "-test-test-test"
  NEW_WIKI_NAME = "simple, stuff"
  CONTENT = "I am Wiki Content"
  NEW_CONTENT = "Here is the new WIKI content"
  TAG = "i am the wiki tag"
  NEW_TAG = "and I am the new wiki tag"
  ATTACHMENT = "1.jpg"
  LONG_LINK ='http://localhost:3000/projects/testing/cards/grid?color_by=Type&filters%5B%5D=%5BType%5D%5Bis%5D%5BStory%5D&filters%5B%5D=%5BIteration%5D%5Bis%5D%5B%28Current+Iteration%29%5D&group_by%5Blane%5D=Status&lanes=New%2CIn+Dev%2CTesting%2CDone&tab=Card+Wall'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project = create_project(:prefix => 'scenario_25', :users => [users(:admin)])
    login_as_admin_user
    @browser.open "/projects/#{@project.identifier}"
  end

  #story5939 Always load fresh content when clicking edit on a wiki
  def test_clicking_on_wiki_edit_will_load_fresh_content_and_will_refresh_history
    new_page = @project.pages.create!(:name => WIKI_NAME, :content => CONTENT)
    open_wiki_page(@project, WIKI_NAME)
    new_page.content = NEW_CONTENT
    new_page.save!
    click_edit_link_on_wiki_page
    assert_warning_message_of_expired_wiki_content_present
    click_save_link
    @browser.run_once_history_generation
    load_page_history
    assert_page_history_for(:page, WIKI_NAME).version(1).shows(:changed => 'Content')
    assert_page_history_for(:page, WIKI_NAME).version(2).shows(:changed => 'Content')
  end

  # Story 12754 -quick add on funky tray
  def test_quick_add_link_on_funky_tray
    new_page = @project.pages.create!(:name => WIKI_NAME, :content => CONTENT)
    open_wiki_page(@project, WIKI_NAME)
    assert_quick_add_link_present_on_funky_tray
    add_card_via_quick_add("new card", :wait => true)
    @browser.wait_for_element_visible("notice")
    card = find_card_by_name("new card")
    assert_notice_message("Card ##{card.number} was successfully created.", :escape => true)
  end

  def test_clicking_on_wiki_edit_will_load_fresh_attachment_and_history
    new_page = @project.pages.create!(:name => WIKI_NAME)
    open_wiki_page(@project, WIKI_NAME)
    new_page.attach_files(sample_attachment(ATTACHMENT))
    new_page.save!
    click_edit_link_on_wiki_page
    assert_warning_message_of_expired_wiki_content_present
    assert_attachment_present(ATTACHMENT)
    click_save_link
    @browser.run_once_history_generation
    load_page_history
    assert_page_history_for(:page, WIKI_NAME).version(2).shows(:attachment_added => ATTACHMENT)
  end

  def test_go_back_link_on_the_warning_bar_of_expired_wiki_contents_should_work
    new_page = @project.pages.create!(:name => WIKI_NAME, :content => CONTENT)
    open_wiki_page(@project, WIKI_NAME)
    new_page.content = NEW_CONTENT
    new_page.save!
    click_edit_link_on_wiki_page
    assert_warning_message_of_expired_wiki_content_present
    click_go_back_link_on_warning_bar_of_expired_wiki_contents
    assert_warning_message_of_expired_wiki_content_not_present
    assert_text_present("v1 - Old version")
    assert_text_present(CONTENT)
  end

  def test_latest_version_link_on_the_warning_bar_of_expired_wiki_contents_should_work
    new_page = @project.pages.create!(:name => WIKI_NAME, :content => CONTENT)
    open_wiki_page(@project, WIKI_NAME)
    new_page.content = NEW_CONTENT
    new_page.save!
    click_edit_link_on_wiki_page
    assert_warning_message_of_expired_wiki_content_present
    click_latest_version_link_on_warning_bar_of_expired_wiki_contents
    assert_warning_message_of_expired_wiki_content_not_present
    assert_text_present("v2 - Latest version, last modified")
    assert_text_present(NEW_CONTENT)
  end


  # bug 471
  def test_cancel_during_initial_overview_page_creation_takes_user_back_to_starting_point
    assert_text_present 'This project does not have an overview page'
    create_overview_page
    @browser.assert_element_present('page_content')
    @browser.assert_location "/projects/#{@project.identifier}/wiki/new?pagename=Overview_Page"
    click_cancel_link
    wait_for_element_info
    @browser.assert_location "/projects/#{@project.identifier}/overview"
    assert_text_present 'This project does not have an overview page - why not create it...'
  end

  def test_cancelling_out_of_edit_takes_user_to_wiki_show
    new_page = @project.pages.create!(:name => WIKI_NAME, :content => CONTENT)
    open_wiki_page(@project, WIKI_NAME)
    new_page.content = NEW_CONTENT
    new_page.save!
    click_edit_link_on_wiki_page
    type_page_content("foo bar")
    click_cancel_link
    @browser.assert_location "/projects/#{@project.identifier}/wiki/#{WIKI_NAME}"
    assert_text_present NEW_CONTENT
    @browser.assert_text_not_present "foo bar"
  end

  #bug 1814
  def test_card_links_in_wiki_content
    card = create_card!(:name => 'for testing')
    create_new_wiki_page(@project, 'foo', "##{card.number}")
    open_wiki_page(@project, 'foo')
    @browser.click_and_wait("link=##{card.number}")
    @browser.assert_text_present(card.name)
    assert_on_card(@project, card)
  end



  # bug 2483
  def test_page_does_not_exist_styling_no_longer_appears_after_page_is_created
    page_one = 'page_one'
    new_page = 'new_page'
    link_to_new_page = "[[#{new_page}]]"
    create_new_wiki_page(@project, "#{page_one}", link_to_new_page)
    assert_non_existant_wiki_link_present
    open_wiki_page(@project, new_page)
    type_page_content('words and letters')
    click_save_link
    open_wiki_page(@project, page_one)
    assert_non_existant_wiki_page_link_not_present
  end

  def test_version_get_updated_when_page_converted_from_redcloth_style
    new_page = @project.pages.create!(:name => WIKI_NAME, :content => 'h1. Go for the gold!')
    new_page.redcloth = true
    new_page.send(:update_without_callbacks)

    open_wiki_page(@project, WIKI_NAME)
    click_edit_link_on_wiki_page
    assert_warning_message_of_expired_wiki_content_not_present
    @browser.assert_element_matches(CardEditPageId::RENDERABLE_CONTENTS, /<h1>Go for the gold!<\/h1>/, :raw_html => true)
  end

  def test_should_not_get_warning_message_when_remove_attachment_on_wiki_page
    new_page = @project.pages.create!(:name => WIKI_NAME, :content => CONTENT)
    open_wiki_page_for_edit(@project, WIKI_NAME)
    attach_file_on_page(new_page, 'I am attachment')
    open_wiki_page(@project, WIKI_NAME)
    remove_attachment(new_page, 'I_am_attachment')

    click_edit_link_on_wiki_page
    assert_warning_message_of_expired_wiki_content_not_present
    assert_version_info_on_page("(v3 - Latest version, last modified today at)")
  end

  #bug 999
  def test_link_in_description_should_be_confined_within_the_descriptor_box
    new_page = @project.pages.create!(:name => WIKI_NAME, :content => CONTENT)
    open_wiki_page_for_edit(@project, WIKI_NAME)
    enter_text_in_editor(LONG_LINK)

    with_ajax_wait { click_save_link }

    @browser.assert_element_style_property_value("#page-content a", "word-wrap", "break-word");
  end

end
