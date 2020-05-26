# -*- coding: utf-8 -*-

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
require File.expand_path(File.dirname(__FILE__) + '/../api/api_test_helper')

# Tags: scenario, bug, cards, comment
class CardCrudTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  RELEASE = 'Release'
  ITERATION = 'Iteration'
  STORY = "story"
  STATUS = 'status'
  OPEN = 'open'
  NEW = 'new'
  FIXED = 'fixed'
  TYPE = 'Type'
  CARD = 'Card'
  BLANK = ''
  NOTSET = '(not set)'
  HIGH = 'High'
  TASK= 'Task'

  CARD_NAME = 'Plain card'
  CARD_NAME2 = 'Plain card 2'
  ORIGINAL_NAME = 'Original name'
  NEW_NAME = 'New name'
  TAG = 'it is my new tag!'

  NEW_TAG = 'it is another tag!'
  DESCRIPTION = 'here is my description!'
  NEW_DESCRIPTION = "new description is here!!"
  COMMENT = "it my new comment!"
  ATTACHMENT = "1.jpg"
  WIKI_NAME = "Plain page"

  MANAGED_TEXT_PROPERY = "Managed text list"
  FREE_TEXT_PROPERTY = "Allow any text"
  MANAGED_NUMBER_PROPERTY = "Managed number list"
  FREE_NUMBER_PROPERY = "Allow any number"
  USER_TYPE_PROPERY = "owner"
  DATE_TYPE_PROPERY = "date"
  CARD_TYPE_PROPERY = "card"
  FORMULAR_TYPE_PROPERY = 'formula'
  RELATIONSHIP_PROPERY = 'relationship property'
  LOCKED_MANAGED_TEXT_PROPERTY="i am locked"

  CURRENT_USER = '(current user)'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @mingle_admin = users(:admin)
    @project_admin = users(:proj_admin)
    @project_member = users(:project_member)
    @read_only_user = users(:read_only_user)
    @browser = selenium_session
    @project = create_project(:prefix => 'card_crud_test', :users => [@project_member, users(:longbob)], :admins => [@mingle_admin, @project_admin], :read_only_users => [@read_only_user])
    setup_property_definitions(STATUS => [OPEN, FIXED], ITERATION => [1, 2])
    login_as_admin_user
    open_project(@project)
  end

  
  def test_copy_card_end_to_end
    # Data setups project 1...
    project1_with_all_types = create_project(:prefix => 'project1', :users => [@project_member ,@mingle_admin])
    type_story_project1 = setup_card_type(project1_with_all_types, STORY)
    setup_all_properties_for_a_type(project1_with_all_types, STORY)
    type_task = setup_card_type(project1_with_all_types, TASK, :properties => [CARD_TYPE_PROPERY, MANAGED_TEXT_PROPERY])
    card2 = create_card!(:name => "test", :card_type => type_task)
    card1 = create_card!(:name => "story Card", :card_type => type_story_project1, MANAGED_TEXT_PROPERY => 'a', LOCKED_MANAGED_TEXT_PROPERTY => "b", MANAGED_NUMBER_PROPERTY => 1, USER_TYPE_PROPERY => CURRENT_USER, DATE_TYPE_PROPERY => '12 Dec 2011')

    # Data setups project 2...
    project2_with_all_types = create_project(:prefix => 'project2', :users => [@project_admin, @read_only_user])
    type_story_project2 = setup_card_type(project2_with_all_types, STORY)
    setup_all_properties_for_a_type(project2_with_all_types, STORY)
    # Some more data setup...
    project1_with_all_types.activate
    open_card(project1_with_all_types, card1.number)
    open_card_for_edit(project1_with_all_types, card1.number)
    type_comment_in_edit_mode(COMMENT)
    type_card_description(DESCRIPTION)
    save_card
    open_card(project1_with_all_types, card1)
    set_relationship_properties_on_card_show(CARD_TYPE_PROPERY  =>  card2)

    # show bigins... Assert warning messages
    click_copy_to_link

    choose_a_project_and_continue_to_see_warning_message(project2_with_all_types)
    assert_warning_messages_while_card_copy(project2_with_all_types)

    # cards creation in project 2 and its assertions
    click_continue_to_copy_link
    project2_with_all_types.activate
    created_card = Card.find_by_name(card1.name)
    open_card(project2_with_all_types, created_card.number)

    assert_properties_set_on_card_show(CARD_TYPE_PROPERY =>  NOTSET, MANAGED_TEXT_PROPERY => 'a', LOCKED_MANAGED_TEXT_PROPERTY => 'b', FORMULAR_TYPE_PROPERY => '21', USER_TYPE_PROPERY => NOTSET, DATE_TYPE_PROPERY => '12 Dec 2011' )
    card_content_should_be_copied_but_comment_and_history_should_not(created_card,project2_with_all_types)

    # Third project to test all not sets for properties
    open_project(@project)
    @project.activate
    card3=create_card!(:name => "card 3")
    open_card(@project, card3)
    copy_card_to_project(project1_with_all_types)
    project1_with_all_types.activate
    card_created = Card.find_by_name(card3.name)
    open_card(project1_with_all_types, card_created.number)
    assert_properties_set_on_card_show(CARD_TYPE_PROPERY =>  NOTSET, MANAGED_TEXT_PROPERY => NOTSET, FORMULAR_TYPE_PROPERY => NOTSET, USER_TYPE_PROPERY => NOTSET, DATE_TYPE_PROPERY => NOTSET )
  end

  def assert_warning_messages_while_card_copy(project)
    assert_info_box_light_message("Formula property value for #{FORMULAR_TYPE_PROPERY} will not be copied.", :id => "confirm-copy-div")
    assert_info_box_light_message("Card property value for #{CARD_TYPE_PROPERY} will not be copied.", :id => "confirm-copy-div")
    assert_info_box_light_message("User property value for #{USER_TYPE_PROPERY} will not be copied because the requisite team member does not exist in #{@project.name}.", :id => "confirm-copy-div")
    assert_info_box_light_message("Any properties that do not exist in project #{@project.name} will not be copied.", :id => "confirm-copy-div")
  end

  def setup_all_properties_for_a_type(project, type)
    setup_card_type_property_for_cardtype(project, CARD_TYPE_PROPERY, type)
    setup_managed_text_property_for_cardtype(project, MANAGED_TEXT_PROPERY, ["a", "b", "c"], type)
    setup_managed_text_property_for_cardtype(project, LOCKED_MANAGED_TEXT_PROPERTY, ["a", "b", "c"], type)
    lock_property(project,LOCKED_MANAGED_TEXT_PROPERTY)
    setup_user_property_for_cardtype(project,USER_TYPE_PROPERY,type)
    setup_date_property_for_cardtype(project,DATE_TYPE_PROPERY,type)
    setup_managed_number_property_for_cardtype(project, MANAGED_NUMBER_PROPERTY, [1,2,3], type)
    setup_formula_property_for_cardtype(project, FORMULAR_TYPE_PROPERY,"'#{MANAGED_NUMBER_PROPERTY}'+ 20", type)
  end

  # Story 12728
  def test_create_the_first_card_link_presents_when_no_cards_in_project
    navigate_to_card_list_for(@project)
    assert_text_present("There are no cards for #{@project.name} - Create the first card now")
    @browser.with_ajax_wait{@browser.click("link=Create the first card")}
    type_card_name("Testing Card")
    submit_quick_add_card

    assert_text_not_present("There are no cards for #{@project.name} - Create the first card now")
    assert_cards_present_in_list(@project.cards.find_by_name("Testing Card"))
  end

  def test_editing_card_in_edit_mode_persists_changes_after_save
    new_card = create_card!(:name => ORIGINAL_NAME, STATUS => OPEN)
    open_card(@project, new_card.number)
    click_edit_link_on_card
    type_card_name(NEW_NAME)
    type_card_description(DESCRIPTION)
    type_comment_in_edit_mode(COMMENT)
    set_properties_in_card_edit(ITERATION => 1, STATUS => FIXED)
    save_card
    @browser.run_once_history_generation
    open_card(@project, new_card.number)
    assert_comment_author_present("admin@email.com")
    assert_history_for(:card, new_card.number).version(2).shows(:changed => 'Name', :from => ORIGINAL_NAME, :to => NEW_NAME)
    assert_history_for(:card, new_card.number).version(2).shows(:comments_added => COMMENT)
    assert_history_for(:card, new_card.number).version(2).shows(:set_properties => {ITERATION => 1})
    assert_history_for(:card, new_card.number).version(2).shows(:changed => STATUS, :from => OPEN, :to => FIXED)
  end

  def test_can_delete_card_while_viewing_it
    new_card = create_card!(:name => CARD_NAME, :description => DESCRIPTION, STATUS => FIXED)
    navigate_to_card_list_for(@project)
    click_card_on_list(new_card.number)
    click_card_delete_link
    click_continue_to_delete_on_confirmation_popup
    assert_notice_message("Card ##{new_card.number} deleted successfully.")
  end

  #story5939 Always load fresh content when clicking edit on a card
  def test_clicking_on_card_edit_will_load_fresh_description_and_will_refresh_history
    create_card_via_api('card[name]' => CARD_NAME, 'card[description]' => DESCRIPTION)
    new_card = @project.reload.cards.sort_by(&:number).last
    navigate_to_card(@project, new_card)
    update_card_via_api(new_card.number, 'card[description]' => NEW_DESCRIPTION )
    click_edit_link_on_card
    assert_warning_message_of_expired_card_content_present
    assert_card_or_page_content_in_edit(NEW_DESCRIPTION)
    @browser.click_and_wait('link=go back')
     assert_warning_message_of_expired_card_content_not_present
     assert_text_present("v1 - Old version today at")
     assert_text_present(DESCRIPTION)

    @browser.run_once_history_generation
    assert_history_for(:card, new_card.number).version(1).shows(:changed => 'Description')
    assert_history_for(:card, new_card.number).version(2).shows(:changed => 'Description')
  end

  def test_latest_version_link_on_the_warning_bar_of_expired_card_contents_should_work
     fresh_card = create_card!(:name => CARD_NAME2, :description => DESCRIPTION)
     navigate_to_card(@project, fresh_card)
     fresh_card.description = NEW_DESCRIPTION
     fresh_card.save!
     click_edit_link_on_card
     assert_warning_message_of_expired_card_content_present
     @browser.click_and_wait('link=latest version')
     assert_warning_message_of_expired_card_content_not_present
     assert_text_present("v2 - Latest version, last modified")
     assert_text_present(NEW_DESCRIPTION)
  end

  def test_clicking_on_card_edit_will_load_all_card_details
    new_card = create_card!(:name => CARD_NAME, STATUS => FIXED)
    navigate_to_card(@project, new_card)
    new_card.update_properties(STATUS => OPEN)
    new_card.add_comment :content => COMMENT
    new_card.attach_files(sample_attachment(ATTACHMENT))
    new_card.save!
    click_edit_link_on_card
    assert_warning_message_of_expired_card_content_present
    assert_comment_present(COMMENT)
    assert_property_set_on_card_edit(STATUS, OPEN)
    assert_attachment_present(ATTACHMENT)
  end

  #bug 7568, 1777, 855
  def test_save_and_add_another_with_card_defaults_and_card_description
    open_edit_defaults_page_for(@project, "Card")
    set_property_defaults(@project, STATUS => FIXED, ITERATION => '1')
    click_save_defaults
    new_card = create_card!(:name => CARD_NAME, :description => 'a&b=b \n\n 2. sdf')
    open_card(@project, new_card)
    @browser.assert_text_present('a&b=b \n\n 2. sdf')
    assert_link_to_card_not_present(@project, 2)
    click_edit_link_on_card
    set_properties_in_card_edit(STATUS => OPEN, ITERATION => '2')
    click_save_and_add_another_link
    assert_properties_set_on_card_edit(STATUS => OPEN, ITERATION => '2')
  end

  # bug 3066
  def test_save_and_add_another_carries_over_property_values_when_their_names_contain_spaces
    value_with_spaces = 'foo bar'
    property_name_with_spaces = 'multiple words'
    setup_property_definitions(property_name_with_spaces => [value_with_spaces])
    create_card_type_via_api('defect', property_name_with_spaces)
    type_defect = @project.reload.card_types.find_by_name('defect')
    create_card_via_api('card[name]' => 'for testing', 'card[card_type_name]' => type_defect.name)
    card = @project.reload.cards.sort_by(&:number).last

    open_card_for_edit(@project, card.number)
    set_properties_in_card_edit(property_name_with_spaces => value_with_spaces)
    assert_properties_set_on_card_edit(property_name_with_spaces => value_with_spaces)
    click_save_and_add_another_link
    assert_card_update_successfully_message(card)
    type_card_name('confirming bug 3066')
    assert_properties_set_on_card_edit(property_name_with_spaces => value_with_spaces)
    save_card
    saved_and_added_another_card_number = card.number + 1
    @browser.run_once_history_generation
    open_card(@project, saved_and_added_another_card_number)
    assert_history_for(:card, saved_and_added_another_card_number).version(1).shows(:set_properties => {property_name_with_spaces => value_with_spaces})
  end

  # bug 1317  2384
  def test_property_set_in_show_view_works_twice_in_a_row
    card_without_properties_set  = create_card!(:name => CARD_NAME)
    open_card(@project, card_without_properties_set.number)
    set_properties_on_card_show(STATUS => OPEN)
    assert_equal(OPEN, card_without_properties_set.reload.cp_status)
    set_properties_on_card_show(STATUS => FIXED)
    @browser.run_once_history_generation
    assert_equal(FIXED, card_without_properties_set.reload.cp_status)
    click_edit_link_on_card
    @browser.run_once_history_generation
    assert_properties_set_on_card_edit(STATUS => FIXED)
    assert_history_for(:card, card_without_properties_set.number).version(3).shows(:changed => STATUS, :from => OPEN, :to => FIXED)
  end

  # bug [mingle1/#1244, #1242] - this used to test the description field as well
  # but the test changed such that it wasn't validating whitespace on the description
  # anymore. we really don't care about whitespace in description now that we're using
  # HTML instead of markdown, so renamed the test to only be applicable to card name
  def test_card_create_should_trim_leading_and_trailing_whitespace_in_card_name
    card_name_trimmed = 'whatever'
    card_name_with_whitespace = "          #{card_name_trimmed}                "

    click_all_tab
    card_number = create_new_card(@project, :name => card_name_with_whitespace, :description => "")
    open_card(@project, card_number)
    card_from_db = @project.cards.find_by_number(card_number)
    assert_equal(card_name_trimmed, card_from_db.name)

    open_add_card_via_quick_add
    type_card_name(card_name_with_whitespace)
    submit_quick_add_card :wait => true
    card_from_db = find_card_by_name(card_name_trimmed)
    assert card_from_db
    assert_equal(card_name_trimmed, card_from_db.name)
  end

  def wait_for_notice_message
    @browser.wait_for_element_visible "notice"
  end

  # bug 1879, 5062
  def test_can_bulk_delete_multiple_cards
    create_cards(@project, 10)
    navigate_to_card_list_for(@project)
    assert_bulk_delete_button_disabled
    select_all
    assert_bulk_delete_button_enabled
    click_bulk_delete_button
    click_confirm_bulk_delete
    assert_no_card_for_current_project_message(@project)
  end

  #Bug 2426 for korean language
  def test_korean_characters_are_displyed_properly_in_card_description
    card = create_card!(:name => CARD_NAME)
    open_card_for_edit(@project, card.number)
    type_card_description('한국어는 멋진 언어')
    save_card
    click_edit_link_on_card
    assert_card_or_page_content_in_edit('한국어는 멋진 언어')
  end

  # bug 3504
  def test_created_by_and_modified_by_messages_escape_html
    user_with_html = users(:user_with_html)
    same_user_name_without_html = 'foo bar'
    add_full_member_to_team_for(@project, user_with_html)
    logout
    login_as_user_with_html
    navigate_to_card_list_for(@project)
    create_card_via_api('card[name]' => CARD_NAME, user_login: user_with_html.login)
    card = @project.reload.cards.sort_by(&:number).last
    open_card(@project, card.number)
    edit_card(:name => CARD_NAME2)
    @browser.run_once_history_generation
    open_card(@project, card.number)
    assert_history_for(:card, card.number).version(1).shows(:created_by => user_with_html.name)
    assert_history_for(:card, card.number).version(2).shows(:modified_by => user_with_html.name)
    assert_history_for(:card, card.number).version(1).does_not_show(:created_by => same_user_name_without_html)
    assert_history_for(:card, card.number).version(2).does_not_show(:modified_by => same_user_name_without_html)
    open_edit_profile_for(user_with_html)
    type_full_name_in_user_profile(NEW_NAME)
    click_save_profile_button
    @browser.run_once_history_generation
    open_card(@project, card)
    assert_history_for(:card, card.number).version(1).shows(:created_by => NEW_NAME)
    assert_history_for(:card, card.number).version(2).shows(:modified_by => NEW_NAME)
    navigate_to_card_list_for(@project)
    add_column_for(@project, ['Created by'])
    assert_card_created_by_user(card, NEW_NAME)
  end

  # bug 3069
  def test_card_comments_escape_html
    comment_with_html_tags = "foo <b>BAR</b>"
    same_comment_without_html_tags = "foo BAR"
    card = create_card!(:name => CARD_NAME)
    open_card_for_edit(@project, card.number)
    type_comment_in_edit_mode(comment_with_html_tags)
    save_card
    assert_comment_present(comment_with_html_tags)
    assert_comment_not_present(same_comment_without_html_tags)
  end

  def test_should_refresh_add_decription_link_when_remove_attachment_in_the_card_show
    new_card = create_card!(:name => CARD_NAME)
    navigate_to_card(@project, new_card)
    new_card.attach_files(sample_attachment(ATTACHMENT))
    new_card.save!
    navigate_to_card(@project, new_card)

    remove_attachment(new_card, ATTACHMENT)
    @browser.click_and_wait('link=Add description')
    assert_warning_message_of_expired_card_content_not_present
    assert_version_info_on_card_edit("(v3 - Latest version, last modified today at)")
  end

  # bug 7221
  def test_should_show_mql_warning_on_bulk_card_delete_confirmation
    card_1 = create_card!(:name => CARD_NAME)
    card_2 = create_card!(:name => CARD_NAME2)
    navigate_to_card_list_for(@project)
    check_cards_in_list_view(card_1, card_2)
    click_bulk_delete_button
    assert_info_box_light_message("Any MQL (Advanced filters, some Macros or aggregates using MQL conditions) that uses these cards will no longer return any results.", :id => "confirm-delete-div", :include => true)
  end

  def test_changing_card_type_on_card_show_should_get_warning_message
    create_card_type_via_api('defect')
    type_defect = @project.reload.card_types.find_by_name('defect')
    create_card_via_api('card[name]' => 'for testing', 'card[card_type_name]' => type_defect.name)
    card = @project.reload.cards.sort_by(&:number).last
    open_card(@project, card.number)
    set_card_type_on_card_show('Card', :stop_at_confirmation => true)
    assert_change_type_confirmation_for_single_card_present
    cancel_to_change_card_type
    open_card(@project, card.number)
    assert_card_type_set_on_card_show(type_defect)

    set_card_type_on_card_show('Card', :stop_at_confirmation => true)
    continue_to_change_card_type
    open_card(@project, card.number)
    assert_card_type_set_on_card_show("Card")

    open_card_for_edit(@project, card.number)
    set_card_type_on_card_edit('defect')
    @browser.click(save_card_button)
    assert_change_type_confirmation_for_single_card_present
  end

  # Story 12754 -quick add on funky tray
  def test_quick_add_does_not_appear_at_project_level
    Project.create!(:name => 'Zebra', :identifier => 'zebra')
    Project.create!(:name => 'Alpha', :identifier => 'alpha')
    navigate_to_all_projects_page
    assert_quick_add_link_not_present_on_funky_tray
  end

private
  def create_card_type_via_api(card_type_name, prop_def_name=nil)
    params = {"card_type[name]" => card_type_name }
    params['card_type[property_definitions][][name]'] = prop_def_name unless prop_def_name.nil?
    post("#{base_url}/card_types.xml", params)
  end

  def base_url(options ={})
    "http://#{options[:login] || 'admin'}:#{ options[:password] || MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}"
  end

  def update_card_via_api(card_number, params)
    put("#{base_url}/cards/#{card_number}.xml", params)
  end

  def create_card_via_api(params)
    post("#{base_url(login: params.delete(:user_login))}/cards.xml", params)
  end

def card_content_should_be_copied_but_comment_and_history_should_not(card,project)
   name = card.name
   expected_description = card.description
   expected_tags = card.tags

   project.activate
   new_card = Card.find_by_name(name)
   open_card(project,new_card)
   assert_version_info_on_card_show("(v1 - Latest version, last modified today at)")
   # assert_card_description_in_show(DESCRIPTION)
   assert_comment_in_card_edit_page('')
 end

end
