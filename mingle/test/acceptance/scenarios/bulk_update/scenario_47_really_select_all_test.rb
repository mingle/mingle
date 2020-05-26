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

# Tags: cards, card-list, bulk
class Scenario47ReallySelectAllTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  STATUS = 'status'
  OPEN = 'OPEN'
  CLOSED = 'closed'
  RELEASE = 'Release'
  ONE_DOT_ONE = '1.1'
  NOT_SET = '(not set)'
  BLANK = ''

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_admin_team_member = users(:longbob)
    @project_admin = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_47', :users => [@non_admin_team_member], :admins => [@project_admin])
    setup_property_definitions(STATUS => [OPEN, CLOSED], RELEASE => [ONE_DOT_ONE])
    login_as_proj_admin_user
    open_project(@project)
  end

  def test_cannot_perform_bulk_transitions_when_ALL_cards_are_selected
    create_transition_for(@project, 'available to all', :set_properties => {STATUS => OPEN})
    create_cards(@project, 26)
    navigate_to_card_list_for(@project)
    select_all
    assert_transition_drop_down_enabled
    really_select_all_cards(26)
    assert_transition_drop_down_disabled
  end

  def test_really_select_all_link_does_not_appear_when_view_contains_twenty_five_cards_or_less
    create_cards(@project, 25)
    navigate_to_card_list_for(@project)
    select_all
    @browser.assert_not_visible("link=Select all 25 cards in current view")
  end

  def test_can_change_property_values_to_all_selected_cards
    cards = create_cards(@project, 26)
    first_card = cards.first
    last_card = cards.last

    navigate_to_card_list_for(@project)
    select_all
    really_select_all_cards(26)
    click_edit_properties_button
    set_bulk_properties(@project, STATUS => OPEN)
    assert_properties_set_in_bulk_edit_panel(@project,STATUS => OPEN)

    open_card(@project, first_card.number)
    assert_history_for(:card, first_card.number).version(2).shows(:set_properties => {STATUS => OPEN})
    assert_history_for(:card, first_card.number).version(3).not_present
    open_card(@project, last_card.number)
    assert_history_for(:card, last_card.number).version(2).shows(:set_properties => {STATUS => OPEN})
    assert_history_for(:card, last_card.number).version(3).not_present

    navigate_to_card_list_for(@project)
    select_all
    really_select_all_cards(26)
    click_edit_properties_button
    set_bulk_properties(@project, STATUS => NOT_SET)
    assert_properties_set_in_bulk_edit_panel(@project,STATUS => NOT_SET)
    open_card(@project, first_card.number)
    assert_history_for(:card, first_card.number).version(2).shows(:set_properties => {STATUS => OPEN})
    assert_history_for(:card, first_card.number).version(3).shows(:changed => STATUS, :from => OPEN, :to => NOT_SET)
    assert_history_for(:card, first_card.number).version(4).not_present
    open_card(@project, last_card.number)
    assert_history_for(:card, last_card.number).version(2).shows(:set_properties => {STATUS => OPEN})
    assert_history_for(:card, last_card.number).version(3).shows(:changed => STATUS, :from => OPEN, :to => NOT_SET)
    assert_history_for(:card, last_card.number).version(4).not_present
  end

  def test_can_add_and_remove_tags_for_all_selected_cards
    tag_for_all = %w(rss)
    cards = create_cards(@project, 26)
    navigate_to_card_list_for(@project)
    select_all
    really_select_all_cards(26)
    click_bulk_tag_button
    bulk_tag_with(tag_for_all)
    assert_value_present_in_tagging_panel "All tagged:.*#{tag_for_all.join}"

    @browser.run_once_history_generation
    first_card = cards.first
    last_card = cards.last
    open_card(@project, first_card.number)
    assert_history_for(:card, first_card.number).version(2).shows(:tagged_with => tag_for_all)
    assert_history_for(:card, first_card.number).version(3).not_present
    open_card(@project, last_card.number)
    assert_history_for(:card, last_card.number).version(2).shows(:tagged_with => tag_for_all)
    assert_history_for(:card, last_card.number).version(3).not_present

    navigate_to_card_list_for(@project)
    select_all
    really_select_all_cards(26)
    click_bulk_tag_button

    bulk_remove_tag(tag_for_all)
    @browser.run_once_history_generation
    open_card(@project, first_card.number)
    assert_history_for(:card, first_card.number).version(2).shows(:tagged_with => tag_for_all)
    assert_history_for(:card, first_card.number).version(3).shows(:tags_removed => tag_for_all)
    assert_history_for(:card, first_card.number).version(4).not_present
    open_card(@project, last_card.number)
    assert_history_for(:card, last_card.number).version(2).shows(:tagged_with => tag_for_all)
    assert_history_for(:card, last_card.number).version(3).shows(:tags_removed => tag_for_all)
    assert_history_for(:card, last_card.number).version(4).not_present
  end

  def test_can_delete_all_selected_cards_on_mulitple_pages_using_really_select_all
    cards = create_cards(@project, 26)
    navigate_to_card_list_for(@project)
    select_all
    really_select_all_cards(26)
    click_bulk_delete_button
    click_confirm_bulk_delete
    assert_info_message("There are no cards for #{@project.name}")
  end

  def test_can_really_select_all_on_pages_other_than_the_first_page
    cards = create_cards(@project, 26)
    navigate_to_card_list_for(@project)
    click_page_link(2)
    select_all
    really_select_all_cards(26)
    @browser.assert_text_present("All 26 cards in view are selected.")
    assert_transition_drop_down_disabled
  end

  def test_can_set_user_properties_using_bulk_edit_and_really_select_all
    user_property_name = "Tester's"
    cards = create_cards(@project, 26)
    first_card = cards.first
    last_card = cards.last
    create_property_definition_for(@project, user_property_name, :type => 'user')
    navigate_to_card_list_for(@project)
    select_all
    really_select_all_cards(26)
    click_edit_properties_button
    set_bulk_properties(@project, user_property_name => @non_admin_team_member.name)
    open_card(@project, first_card.number)
    assert_history_for(:card, first_card.number).version(2).shows(:set_properties => {user_property_name => @non_admin_team_member.name})
    assert_history_for(:card, first_card.number).version(3).not_present
    open_card(@project, last_card.number)
    assert_history_for(:card, last_card.number).version(2).shows(:set_properties => {user_property_name => @non_admin_team_member.name})
    assert_history_for(:card, last_card.number).version(3).not_present

    navigate_to_card_list_for(@project)
    select_all
    really_select_all_cards(26)
    click_edit_properties_button
    set_bulk_properties(@project, user_property_name => NOT_SET)
    assert_properties_set_in_bulk_edit_panel(@project,user_property_name => NOT_SET)
    open_card(@project, first_card.number)
    assert_history_for(:card, first_card.number).version(2).shows(:set_properties => {user_property_name => @non_admin_team_member.name})
    assert_history_for(:card, first_card.number).version(3).shows(:changed => user_property_name, :from => @non_admin_team_member.name, :to => NOT_SET)
    assert_history_for(:card, first_card.number).version(4).not_present
    open_card(@project, last_card.number)
    assert_history_for(:card, last_card.number).version(2).shows(:set_properties => {user_property_name => @non_admin_team_member.name})
    assert_history_for(:card, last_card.number).version(3).shows(:changed => user_property_name, :from => @non_admin_team_member.name, :to => NOT_SET)
    assert_history_for(:card, last_card.number).version(4).not_present
  end

  def test_can_set_free_text_properties_using_bulk_edit_and_really_select_all
    free_text_property_name = 'resolution'
    value_for_free_text_property = 'fast and furious fix'
    cards = create_cards(@project, 26)
    first_card = cards.first
    last_card = cards.last
    create_property_definition_for(@project, free_text_property_name, :type => 'any text')
    navigate_to_card_list_for(@project)
    select_all
    really_select_all_cards(26)
    click_edit_properties_button
    add_value_to_free_text_property_using_inline_editor_on_bulk_edit(free_text_property_name, value_for_free_text_property)
    assert_property_set_in_bulk_edit_panel(@project, free_text_property_name, value_for_free_text_property)
    open_card(@project, first_card.number)
    assert_history_for(:card, first_card.number).version(2).shows(:set_properties => {free_text_property_name => value_for_free_text_property})
    assert_history_for(:card, first_card.number).version(3).not_present
    open_card(@project, last_card.number)
    assert_history_for(:card, last_card.number).version(2).shows(:set_properties => {free_text_property_name => value_for_free_text_property})
    assert_history_for(:card, last_card.number).version(3).not_present

    navigate_to_card_list_for(@project)
    select_all
    really_select_all_cards(26)
    click_edit_properties_button
    add_value_to_free_text_property_using_inline_editor_on_bulk_edit(free_text_property_name, BLANK)
    assert_property_set_in_bulk_edit_panel(@project, free_text_property_name, NOT_SET)
    open_card(@project, first_card.number)
    assert_history_for(:card, first_card.number).version(2).shows(:set_properties => {free_text_property_name => value_for_free_text_property})
    assert_history_for(:card, first_card.number).version(3).shows(:changed => free_text_property_name, :from => value_for_free_text_property, :to => NOT_SET)
    assert_history_for(:card, first_card.number).version(4).not_present
    open_card(@project, last_card.number)
    assert_history_for(:card, last_card.number).version(2).shows(:set_properties => {free_text_property_name => value_for_free_text_property})
    assert_history_for(:card, last_card.number).version(3).shows(:changed => free_text_property_name, :from => value_for_free_text_property, :to => NOT_SET)
    assert_history_for(:card, last_card.number).version(4).not_present
  end

  def test_can_set_date_properties_using_bulk_edit
     date_property_name = 'Fixed on'
     valid_date_value = '12 Apr 1943'
     cards = create_cards(@project, 26)
     first_card = cards.first
     last_card = cards.last
     create_property_definition_for(@project, date_property_name, :type => 'date')
     navigate_to_card_list_for(@project)
     select_all
     really_select_all_cards(26)
     click_edit_properties_button
     add_value_to_date_property_using_inline_editor_on_bulk_edit(date_property_name, valid_date_value)
     assert_property_set_in_bulk_edit_panel(@project, date_property_name, valid_date_value)
     open_card(@project, first_card.number)
     assert_history_for(:card, first_card.number).version(3).not_present
     assert_history_for(:card, first_card.number).version(2).shows(:set_properties => {date_property_name => valid_date_value})
     open_card(@project, last_card.number)
     assert_history_for(:card, last_card.number).version(2).shows(:set_properties => {date_property_name => valid_date_value})
     assert_history_for(:card, last_card.number).version(3).not_present

     navigate_to_card_list_for(@project)
     select_all
     really_select_all_cards(26)
     click_edit_properties_button
     add_value_to_date_property_using_inline_editor_on_bulk_edit(date_property_name, BLANK)
     assert_property_set_in_bulk_edit_panel(@project, date_property_name, NOT_SET)
     open_card(@project, first_card.number)
     assert_history_for(:card, first_card.number).version(2).shows(:set_properties => {date_property_name => valid_date_value})
     assert_history_for(:card, first_card.number).version(3).shows(:changed => date_property_name, :from => valid_date_value, :to => NOT_SET)
     assert_history_for(:card, first_card.number).version(4).not_present
     open_card(@project, last_card.number)
     assert_history_for(:card, last_card.number).version(2).shows(:set_properties => {date_property_name => valid_date_value})
     assert_history_for(:card, last_card.number).version(3).shows(:changed => date_property_name, :from => valid_date_value, :to => NOT_SET)
     assert_history_for(:card, last_card.number).version(4).not_present
  end

  #bug 2428
  def test_checking_a_card_and_adding_a_column_should_not_select_all_cards
    cards = create_cards(@project, 26)
    navigate_to_card_list_for(@project)
    select_all
    really_select_all_cards(26)
    click_edit_properties_button
    set_bulk_properties(@project, STATUS => CLOSED)
    select_none
    cards_on_page_one = cards
    check_cards_in_list_view(cards.last)
    add_column_for(@project, [STATUS])
    assert_card_not_checked(cards.last)
  end

  #bug 2320
  def test_filtering_card_list_removes_really_select_all
    cards = create_cards(@project, 27)
    first_card = cards.first
    last_card = cards.last
    navigate_to_card_list_for(@project)
    select_all
    really_select_all_cards(27)
    click_edit_properties_button
    set_bulk_properties(@project, STATUS => CLOSED)
    filter_card_list_by(@project, :type => 'Card')
    cards_on_page_one = cards[2..-1]
    cards_on_page_one.each{|card| assert_card_not_checked(card)}
    cards_on_page_one.each{|card| assert_enabled(get_card_checkbox_id(card))}
  end

  #bug 6312
  def only_cards_on_current_page_get_tagged_applied_when_select_all_cards_in_current_view
    cards = create_cards(@project, 27)
    navigate_to_card_list_for(@project)
    select_all
    really_select_all_cards(27)
    click_edit_properties_button
    set_bulk_properties(@project, STATUS => CLOSED)
    bulk_tag('apple')
    assert_notice_message("27 cards updated")
  end
end
