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

require File.expand_path('card_transition_acceptance_support.rb', File.dirname(__FILE__))
require File.expand_path('../../../acceptance/acceptance_test_helper.rb', File.dirname(__FILE__))

# Tags: scenario, transitions, #2274, #2454, #2461, #2463, #2509, #2510
class Scenario35CardTransitions2Test < ActiveSupport::TestCase

  include CardTransitionAcceptanceSupport

  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @admin_user = users(:admin)
    @non_team_member = users(:existingbob)
    @non_admin_user = users(:longbob)
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_35', :users => [@admin_user, @non_admin_user], :admins => [@project_admin_user])
    setup_property_definitions(STATUS => [NEW, OPEN, IN_PROGRESS, DONE, CLOSE], PRIORITY => [HIGH, LOW], BUG_STATUS => ['Open', 'Fixed', 'Verified', 'Closed'])
    @created_date = setup_date_property_definition(CREATED)
    @address_text = setup_text_property_definition(ADDRESS)
    @owner = setup_user_definition(OWNER)
    login_as_proj_admin_user
  end

  def test_transition_can_be_completed_only_if_added_comment_for_transition_with_comment_required_on_card_list_view
    mark_closed = 'Mark Closed'
    comment = "this is a test"
    transition1 = create_transition_for(@project, mark_closed, :set_properties => { BUG_STATUS => 'Closed' }, :require_comment => true)
    card1 = create_card!(:name => 'card1')
    card2 = create_card!(:name => 'card2')
    click_all_tab
    select_all
    execute_bulk_transition_action_that_requires_input(transition1)
    assert_disabled('complete_transition')
    add_comment_for_transition_to_complete_text_area(comment)
    assert_enabled('complete_transition')
    click_on_complete_transition(:ajaxwait => false)
    assert_notice_message("(<b>)?#{mark_closed}(</b>)? successfully applied to cards #2, #1")
    navigate_to_history_for(@project)
    assert_history_for(:card, card1.number).version(2).shows(:comments_added => comment)
    assert_history_for(:card, card2.number).version(2).shows(:comments_added => comment)
  end

  def test_transition_can_be_completed_only_if_added_comment_for_transition_with_comment_required_for_grid_view
    mark_closed = 'Mark Closed'
    comment = "this is a test"
    transition1 = create_transition_for(@project, mark_closed, :set_properties => { BUG_STATUS => 'Closed' }, :require_comment => true)
    card1 = create_card!(:name => 'card1')
    click_all_tab
    switch_to_grid_view
    click_on_card_in_grid_view(card1.number)
    click_transition_link_on_card_in_grid_view(transition1)
    assert_disabled('complete_transition')
    add_comment_for_transition_to_complete_text_area(comment)
    assert_enabled('complete_transition')
    click_on_complete_transition
    navigate_to_history_for(@project)
    assert_history_for(:card, card1.number).version(2).shows(:comments_added => comment)
  end

  def test_input_not_required_on_different_kind_of_properties_when_value_already_present_to_complete_transition
    mark_closed = 'Mark Closed'
    card1 = create_card!(:name => 'card1', PRIORITY => HIGH, OWNER => @admin_user.id, ADDRESS => '123, kenk st, NSW 200', CREATED => '05 May 2005')
    transition1 = create_transition_for(@project, mark_closed, :set_properties => { BUG_STATUS => 'Closed', OWNER => REQUIRE_USER_INPUT,
                                                                                    ADDRESS => REQUIRE_USER_INPUT, CREATED => REQUIRE_USER_INPUT, PRIORITY => REQUIRE_USER_INPUT })
    open_card(@project, card1.number)
    click_transition_link_on_card_with_input_required(transition1)
    assert_enabled('complete_transition')
    click_on_complete_transition
    navigate_to_history_for(@project)
    assert_history_for(:card, card1.number).version(2).shows(:set_properties => { BUG_STATUS => 'Closed' })
  end

  def test_transition_with_input_reqire_fileds_set_not_available_for_bulk_edit
    mark_closed = 'Mark Closed'
    card1 = create_card!(:name => 'card1', PRIORITY => HIGH, OWNER => @admin_user.id, ADDRESS => '123, kenk st, NSW 200', CREATED => '05 May 2005')
    transition1 = create_transition_for(@project, mark_closed, :set_properties => { BUG_STATUS => 'Closed', OWNER => REQUIRE_USER_INPUT,
                                                                                    ADDRESS => REQUIRE_USER_INPUT, CREATED => REQUIRE_USER_INPUT, PRIORITY => REQUIRE_USER_INPUT })
    click_all_tab
    select_all
    assert_no_bulk_transitions_available
  end

  # bug 918 & 1594
  def test_card_transition_should_be_updated_when_tag_value_changed_in_card_view
    card = create_card!(:name => 'plain card', STATUS => NEW)
    transition_open = create_transition_for(@project, 'open card', :required_properties => { STATUS => NEW, :priority => HIGH }, :set_properties => { STATUS => OPEN })
    open_card(@project, card.number)
    assert_transition_not_present_on_card(transition_open)
    set_properties_on_card_show(PRIORITY => HIGH)
    assert_transition_present_on_card(transition_open)
  end

  # bug 754 & 2790
  def test_cannot_create_duplicate_named_card_transitions
    card = create_card!(:name => 'for testing transition', STATUS => NEW)
    transition_name = "Close"
    transition_name_upcased = transition_name.upcase
    create_transition_for(@project, transition_name, :required_properties => { 'Status' => NEW }, :set_properties => { 'Status' => 'open' })
    create_transition_for(@project, transition_name, :required_properties => { 'Status' => NEW }, :set_properties => { 'Status' => 'open' })
    assert_error_message("Name has already been taken")

    create_transition_for(@project, transition_name_upcased, :required_properties => { 'Status' => NEW }, :set_properties => { 'Status' => 'open' })
    assert_error_message("Name has already been taken")
    open_card(@project, card.number)
    assert_transition_present_on_card(transition_name)
    assert_transition_not_present_on_card(transition_name_upcased)
  end

  # bug 7344
  def test_should_not_got_error_when_editing_a_transiton_using_plv
    any_text = setup_text_property_definition("AnyText")
    text_plv_name = 'plv'
    text_plv_value = 'I am the value of plv!'
    create_text_plv(@project, text_plv_name, text_plv_value, [any_text])
    transition = create_transition_for(@project, "Set to plv", :set_properties => { "AnyText" => "(plv)" })
    open_transition_for_edit(@project, transition)
    @browser.assert_element_present("link=Save")
  end

  # bug 2790
  def test_cannot_update_transaction_by_giving_it_name_of_existing_transaction_despite_case
    card = create_card!(:name => 'for testing transition', STATUS => NEW)
    original_name = 'open'
    existing_transition_name = 'WANT_CLOSE'
    existing_transition_name_downcased = existing_transition_name.downcase
    transition_for_editing = create_transition_for(@project, original_name, :required_properties => { 'Status' => NEW }, :set_properties => { 'Status' => 'open' })
    existing_transition = create_transition_for(@project, existing_transition_name, :required_properties => { 'Status' => NEW }, :set_properties => { 'Status' => 'open' })
    open_transition_for_edit(@project, transition_for_editing)
    type_transition_name(existing_transition_name_downcased)
    click_save_transition
    assert_error_message("Name has already been taken")
    open_card(@project, card.number)
    assert_transition_present_on_card(original_name)
    assert_transition_present_on_card(existing_transition_name)
    assert_transition_not_present_on_card(existing_transition_name_downcased)

    open_transition_for_edit(@project, transition_for_editing)
    type_transition_name(existing_transition_name)
    click_save_transition
    assert_error_message("Name has already been taken")
    open_card(@project, card.number)
    assert_transition_present_on_card(original_name)
    assert_transition_present_on_card(existing_transition_name)
  end

  # bug 1239
  def test_creating_transition_trims_leading_and_trailing_whitespace_from_name
    name_trimmed = 'Starting work'
    name_with_whitespace = "          #{name_trimmed}          "
    create_transition_for(@project, name_trimmed, :set_properties => { STATUS => IN_PROGRESS })
    transition_from_db = Project.find_by_identifier(@project.identifier).transitions.find_by_name(name_trimmed)
    assert_equal(name_trimmed, transition_from_db.name)
  end

  # bug 1339
  def test_transition_with_apostrophe_in_its_name_does_not_break_card_list_links
    name_with_apostrope = "jen's transition"
    transition = create_transition_for(@project, name_with_apostrope, :required_properties => { STATUS => NEW }, :set_properties => { STATUS => IN_PROGRESS })
    card_with_transition = create_card!(:name => 'card for transitioning', STATUS => NEW)
    navigate_to_card_list_by_clicking(@project)
    click_card_on_list(card_with_transition)
    @browser.assert_element_matches('card-short-description', /#{card_with_transition.name}/)
    assert_on_card(@project, card_with_transition)
  end

  # bug 1450
  def test_adding_assigning_addition_team_members_to_transtions_takes_effect_on_cards
    transition_name = 'Open'
    transition_open = create_transition_for(@project, transition_name, :required_properties => { STATUS => NEW }, :set_properties => { STATUS => OPEN }, :team_members => [@admin_user])
    new_card = create_card!(:name => 'plain card', STATUS => NEW)
    logout

    login_as("#{@project_admin_user.login}")
    open_transition_for_edit(@project, transition_open)
    assign_to_team_members([@project_admin_user])
    click_save_transition
    open_card(@project, new_card.number)
    assert_transition_present_on_card(transition_open)
  end

  # bug 1728, 1776 & 2073
  def test_editing_transition_with_properties_using_not_set_keeps_them_as_not_set
    create_property_definition_for(@project, 'tester', :type => 'user')
    @project.reload.activate

    transition_using_not_set = create_transition_for(@project, 'testing stuff', :required_properties => { :priority => NOT_SET }, :set_properties => { :tester => NOT_SET, STATUS => NO_CHANGE })
    open_transition_for_edit(@project, transition_using_not_set)
    type_transition_name('new name')
    assert_requires_property(:priority => NOT_SET)
    assert_sets_property(:tester => NOT_SET)
    assert_sets_property(STATUS => NO_CHANGE)
    click_save_transition
    assert_transition_present_for(@project, transition_using_not_set)
    open_transition_for_edit(@project, transition_using_not_set)
    assert_requires_property(:priority => NOT_SET)
    assert_sets_property(:tester => NOT_SET)
    assert_sets_property(STATUS => NO_CHANGE)
  end

  # bug 2510
  def test_transition_that_only_sets_hidden_property_appears_on_card
    transition_setting_hidden_property = create_transition_for(@project, 'setting hidden', :set_properties => { STATUS => OPEN })
    card = create_card!(:name => 'plain card')
    hide_property(@project, STATUS)
    open_card(@project, card.number)
    assert_transition_present_on_card(transition_setting_hidden_property)
  end

  # bug 3091
  def test_hidden_properties_which_are_valid_for_card_type_are_shown_not_all
    @type_story = setup_card_type(@project, TYPE_STORY, :properties => [STATUS, PRIORITY, @owner])
    @type_defect = setup_card_type(@project, TYPE_BUG, :properties => [BUG_STATUS, @created_date])
    hide_property(@project, STATUS)
    hide_property(@project, BUG_STATUS)
    open_transition_create_page(@project)
    set_card_type_on_transitions_page(@type_story.name)
    assert_sets_property_present(STATUS)
    assert_requires_property_present(STATUS)
    assert_sets_property_not_present(BUG_STATUS)
    assert_requires_property_not_present(BUG_STATUS)

    set_card_type_on_transitions_page(@type_defect.name)
    assert_sets_property_not_present(STATUS)
    assert_requires_property_not_present(STATUS)
    assert_sets_property_present(BUG_STATUS)
    assert_requires_property_present(BUG_STATUS)
  end

  #bug 2461
  def test_trying_to_create_transtition_without_card_type_and_no_global_properties_gives_error_message
    card_type_without_properties = setup_card_type(@project, 'story', :properties => [])
    navigate_to_transition_management_for(@project)
    click_create_new_transition_link
    type_transition_name('some name')
    click_create_transition
    assert_error_message("Transition must set at least one property.")
  end

  #bug  2454
  def test_transition_that_requires_and_sets_any_for_a_property_does_not_create_value_ignore_for_that_property
    transition_setting_hidden_property = create_transition_for(@project, 'setting hidden', :required_properties => { STATUS => ANY }, :set_properties => { STATUS => NO_CHANGE, PRIORITY => LOW })
    card = create_card!(:name => 'plain card', STATUS => NEW)
    open_card(@project, card.number)
    click_transition_link_on_card(transition_setting_hidden_property)
    assert_history_for(:card, card.number).version(2).shows(:set_properties => { PRIORITY => LOW })
    assert_history_for(:card, card.number).version(2).does_not_show(:changed => STATUS, :from => NEW, :to => ":ignore")
    assert_value_not_present_for(STATUS, ":ignore")
  end

  # bug 2463
  def test_project_admin_has_ability_to_inline_add_new_value_to_enum_property_during_transition_creation
    navigate_to_transition_management_for(@project)
    click_create_new_transition_link
    assert_inline_value_add_present_for_requires_during_transition_create_edit_for(@project, STATUS)
    assert_inline_value_add_present_for_sets_during_transition_create_edit_for(@project, STATUS)
  end

  #bug 1022
  def test_user_should_be_able_to_use_transitions_without_confirmation_in_popup_on_non_grid_view_page
    new_transition = create_transition_for(@project, 'FOO', :require_comment => false,:set_properties => {STATUS => OPEN})
    card1 = create_card!(:name  => 'Card 1')
    search_card_with_number(card1.number)
    click_transition_link_on_card_in_grid_view(new_transition)
    assert_transition_light_box_not_present
    assert_property_set_on_card_show(STATUS, OPEN)
  end

end
