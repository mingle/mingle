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

# Tags: card-page-history
class Scenario06CardVersioningTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  STATUS = 'status'
  NEW = 'new'
  OPEN = 'open'
  PRIORITY = 'priority'
  HIGH = 'high'
  URGENT = 'urgent'
  ITERATION = 'iteration'
  NOT_SET = '(not set)'
  STORY = 'Story'
  DEFECT = 'Defect'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project = create_project(:prefix => 'scenario_06', :users => [users(:project_member)])
    setup_property_definitions STATUS => [NEW, OPEN], PRIORITY => [HIGH, URGENT], ITERATION => ['1']
    setup_card_type(@project, STORY, :properties => [PRIORITY, ITERATION])
    setup_card_type(@project, DEFECT, :properties => [PRIORITY])
    login_as_project_member
    navigate_to_card_list_by_clicking(@project)
  end

  def test_card_versioning
    card_version_1 = {:name => 'new story', :description => "initial address\\n", STATUS => NEW}
    card_version_2 = {:name => 'create address book', :description => "user can enter and save address\\n", STATUS => NEW, ITERATION => '1', PRIORITY => HIGH}
    card_version_3 = {:name => 'crud address',  :description => "user can enter, save, and edit address\\n", STATUS => NEW, ITERATION => '1', PRIORITY => nil}

    card = create_card!(:name => 'new story', :description => "initial address", STATUS => NEW)
    navigate_to_card_list_by_clicking(@project)
    click_card_on_list(1)

    edit_card card_version_2
    @browser.run_once_history_generation
    assert_history_for(:card, card.number).version(1).present
    assert_history_for(:card, card.number).version(2).present
    @browser.assert_ordered "card-#{card.number}-2", "card-#{card.number}-1"

    @browser.click_and_wait "link-to-card-1-1"
    assert_on_card(@project, card, '?version=1')
    @browser.assert_text_present card_version_1[:name]
    @browser.assert_text 'content', card_version_1[:description].gsub("\\n", '')
    assert_properties_set_on_card_show(STATUS => NEW)
    assert_show_card_in_readonly_page [STATUS, ITERATION, PRIORITY]

    edit_card card_version_3
    @browser.run_once_history_generation

    assert_history_for(:card, card.number).version(3).present
    @browser.assert_ordered "card-#{card.number}-3", "card-#{card.number}-2"

    @browser.click_and_wait "link-to-card-1-2"
    assert_on_card(@project, card, '?version=2')
    @browser.assert_text_present card_version_2[:name]
    @browser.assert_text_present card_version_2[:description].gsub("\\n", '')
    assert_properties_set_on_card_show(STATUS => NEW, ITERATION => '1')
    assert_show_card_in_readonly_page [STATUS, ITERATION, PRIORITY]
  end

  def assert_show_card_in_readonly_page(properties=[])
    @browser.assert_element_present 'link=Show latest'
    @browser.assert_element_not_present 'link=Edit'
    @browser.assert_element_not_present 'link=Delete'
    @browser.assert_element_not_present 'link=Add tags'
    @browser.assert_element_not_present 'link=Add description'

    properties.each do |name|
      @browser.click droplist_link_id(name, 'show')
      wait_a_moment_to_make_sure_nothing_happens
      @browser.assert_element_not_present droplist_dropdown_id(name, 'show')
    end
  end

  def wait_a_moment_to_make_sure_nothing_happens
    sleep(1)
  end

  def assert_show_card_in_editable_page(properties=[])
    @browser.assert_element_not_present 'link=Show latest'
    @browser.assert_element_present CardShowPageId::EDIT_LINK_ID

    properties.each do |name|
      @browser.click droplist_link_id(name, 'show')
      @browser.wait_for_element_visible droplist_dropdown_id(name, 'show')
    end
  end

  # for bug 321
  def assert_not_create_card_version_when_only_inputing_duplicate_data_for_card_edit()
    edit_card card_version_3
    assert_history_for(:card, card.number).version(4).not_present
  end

  # for bug 237
  def test_should_not_create_version_of_card_if_no_significant_details_changed
    card_number = create_new_card(@project, :name => 'intersting card', :description => 'this is so fun, everyone wants it')
    open_card(@project, card_number)
    assert_history_for(:card, card_number).version(1).present
    click_edit_link_on_card
    save_card
    assert_history_for(:card, card_number).version(1).present
    assert_history_for(:card, card_number).version(2).not_present

    as_user('admin') do
      open_card(@project, card_number)
      assert_history_for(:card, card_number).version(1).present
      click_edit_link_on_card
      save_card
      assert_history_for(:card, card_number).version(1).present

      assert_history_for(:card, card_number).version(2).not_present
      @browser.assert_text_not_present 'created by admin@email.com'
    end
  end

  # bug 238, 853
  def test_no_history_should_be_created_when_no_modification_on_card
    navigate_to_card_list_by_clicking(@project)
    card_number = add_new_card('1st card')
    open_card(@project, card_number)
    click_edit_link_on_card
    save_card
    open_card(@project, card_number)
    load_card_history
    assert_card_comment_not_visible #bug 2265
    assert_link_not_present("#{@project}/cards/#{card_number}?version=2")
  end

  # bug 1109
  def test_version_not_created_when_going_into_cards_edit_mode_via_description_link_and_saving_without_changes
    card_number = add_new_card('card one')
    open_card(@project, card_number)
    @browser.click('link=Add description')
    @browser.wait_for_element_visible(save_card_button)
    save_card
    assert_history_for(:card, card_number).version(2).not_present
  end

  #bug 2519
  def test_card_versions_does_not_loose_properties_in_previous_versions_when_lost_in_latest
    card1 = create_card!(:name => 'simple card', :card_type => STORY, ITERATION => '1')
    open_card(@project, card1)
    assert_history_for(:card, card1.number).version(1).shows(:set_properties => {ITERATION => '1'})
    set_card_type_on_card_show(DEFECT)

    @browser.run_once_history_generation
    open_card(@project, card1) # need to reload card page because history section of card show auto refreshed after card update

    assert_history_for(:card, card1.number).version(2).shows(:changed => ITERATION, :from => '1', :to => NOT_SET)
    assert_history_for(:card, card1.number).version(1).shows(:set_properties => {ITERATION => '1'})
  end

  #bug 2635
  def test_adding_comment_in_card_show_and_card_edit_create_two_comments_with_history_entry
    card1 = create_card!(:name => 'simple card')
    open_card(@project, card1)
    add_comment('comment 1')
    assert_comment_present('comment 1')
    open_card_for_edit(@project, card1)
    type_comment_in_edit_mode('comment 2')
    save_card
    assert_comment_present('comment 2')
    assert_history_for(:card, card1.number).version(2).shows(:comments_added => 'comment 1')
    assert_history_for(:card, card1.number).version(3).shows(:comments_added => 'comment 2')
  end

  # bug 3245
  def test_history_versions_for_setting_card_properties_are_escaping_html
    property_name_with_html_tags = "foo <h1>BAR</h1>"
    setup_property_definitions(property_name_with_html_tags => [NEW])
    card = create_card!(:name => 'for testing', property_name_with_html_tags => NEW)
    @browser.run_once_history_generation
    open_card(@project, card.number)
    assert_history_for(:card, card.number).version(1).shows(:set_properties => {property_name_with_html_tags => NEW})
  end

  def test_if_card_version_has_changed_when_adding_a_comment_then_user_will_be_informed
    card1 = create_card!(:name => 'simple card')
    open_card(@project, card1)
    add_comment('comment 1')
    @browser.open("/projects/#{@project.identifier}/cards/#{card1.number}/edit?coming_from_version=#{card1.reload.version - 1}")
    assert_info_message("This card has changed since you opened it for viewing")  # if you change this assertion, you may need to change the one at the bottom of this test

    # editing after adding a comment should not show the error (this was a sign-off issue)
    open_card(@project, card1)
    add_comment('comment 2')
    assert_comment_present('comment 2')
    click_edit_link_on_card

    assert_info_message_not_present  # make sure the 'This card has changed since you opened it for viewing.' message isn't there
  end
end
