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
class Scenario35CardTransitions3Test < ActiveSupport::TestCase

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

  #bug 2420
  def test_free_text_property_value_not_set_should_be_displayed_when_creating_transition_failed
    navigate_to_transition_management_for(@project)
    click_create_new_transition_link
    set_required_properties(@project, ADDRESS => '(not set)')
    click_create_transition
    assert_error_message("Name can't be blank")
    assert_requires_property(ADDRESS => '(not set)')
  end

  # bug 2309
  def test_tranisions_should_be_deleted_when_dependent_properties_are_deleted
    transition_to_be_deleted_with_property = create_transition_for(@project, 'Close', :set_properties => { STATUS => CLOSE })

    navigate_to_property_management_page_for(@project)
    delete_property_for(@project, STATUS, :stop_at_confirmation => true)
    @browser.assert_text_present("Used by 1 Transition: #{transition_to_be_deleted_with_property.name}. This will be deleted.")
    @browser.click_and_wait("link=Continue to delete")
    assert_notice_message("Property #{STATUS} has been deleted.")
    assert_property_does_not_exist(STATUS)
    assert_transition_not_present_for(@project, transition_to_be_deleted_with_property)
  end

  #bug 2293
  def test_properties_with_special_chars_does_not_break_transition_creation
    special_status = 'status”s 2.'
    setup_property_definitions(special_status => [NEW, OPEN, IN_PROGRESS, DONE, CLOSE])
    transition1 = create_transition_for(@project, 'Close', :set_properties => { special_status => CLOSE })
    assert_transition_present_for(@project, transition1)
  end

  #bug 2282
  def test_only_type_specific_properties_are_shown_on_transition_edit
    setup_card_type(@project, 'story', :properties => [STATUS])
    transition_close = create_transition_for(@project, 'close', :type => 'story', :set_properties => { STATUS => CLOSE })
    assert_transition_present_for(@project, transition_close)
    open_transition_for_edit(@project, transition_close)
    assert_sets_property_not_present(PRIORITY, BUG_STATUS, OWNER, CREATED, ADDRESS)
    assert_requires_property_not_present(PRIORITY, BUG_STATUS, OWNER, CREATED, ADDRESS)
  end

  # bug 3076
  def test_after_transition_creation_assert_card_transitions_selected_on_side_planel
    transition_to_be_deleted_with_property = create_transition_for(@project, 'Close', :set_properties => { STATUS => CLOSE })
    assert_current_highlighted_option_on_side_bar_of_management_page('Card transitions')
  end

  # bug 3247
  def test_transition_name_is_escaping_html_on_transition_management_page
    name_with_html_tags = "foo <b>BAR</b>"
    same_name_without_html_tags = "foo BAR"
    transition = create_transition(@project, name_with_html_tags, :set_properties => { STATUS => CLOSE })
    navigate_to_transition_management_for(@project)
    @browser.assert_element_matches("transition-#{transition.id}", /(#{name_with_html_tags})/)
    @browser.assert_element_does_not_match("transition-#{transition.id}", /(#{same_name_without_html_tags})/)
  end

  # bug 3522
  def test_used_by_team_member_name_escapes_html_on_transition_management_page
    user_with_html_tags = users(:user_with_html)
    same_user_name_without_html_tags = 'foo bar'
    add_full_member_to_team_for(@project, user_with_html_tags)
    transition = create_transition_for(@project, 'user has html tags', :for_team_members => [user_with_html_tags], :set_properties => { STATUS => CLOSE })
    navigate_to_transition_management_for(@project)
    @browser.assert_element_matches("transition-#{transition.id}", /(#{user_with_html_tags.name})/)
    @browser.assert_element_does_not_match("transition-#{transition.id}", /(#{same_user_name_without_html_tags})/)
  end

  # bug 3628; also, I hijacked this test to check html escaping
  def test_cannot_create_value_for_free_text_property_that_begins_and_ends_with_parens_in_require_user_input_lightbox
    address_def = @project.find_property_definition(ADDRESS); address_def.name = '<h1>address</h1>'; address_def.save!

    card = create_card!(:name => 'for testing')
    free_text_transition = create_transition_for(@project, 'testing free text', :set_properties => { address_def.name => REQUIRE_USER_INPUT })
    open_card(@project, card)
    click_transition_link_on_card(free_text_transition)

    add_value_to_free_text_property_lightbox_editor_on_transition_complete(address_def.name => '(foo)')
    click_on_complete_transition
    assert_error_message(/#{address_def.name.escape_html}: <(b|B)>\(foo\)<\/(b|B)> is an invalid value. Value cannot both start with '\(' and end with '\)' unless it is an existing project variable which is available for this property./, :raw_html => true)
    assert_history_for(:card, card.number).version(2).not_present
  end

  # this test also tests html escaping
  def test_cannot_create_value_for_managed_list_property_that_begins_and_ends_with_parens_in_require_user_input_lightbox
    priority_def = @project.find_property_definition(PRIORITY); priority_def.name = '<h1>priority</h1>'; priority_def.save!

    card = create_card!(:name => 'for testing')
    transition = create_transition_for(@project, 'testing managed text', :set_properties => { priority_def.name => REQUIRE_USER_INPUT })
    open_card(@project, card)
    click_transition_link_on_card(transition)

    add_value_to_property_via_inline_editor_in_lightbox_editor_on_transition_complete(priority_def.name => '(foo)')
    click_on_complete_transition
    assert_error_message(/#{priority_def.name.escape_html}: <(b|B)>\(foo\)<\/(b|B)> is an invalid value. Value cannot both start with '\(' and end with '\)' unless it is an existing project variable which is available for this property./, :raw_html => true)
  end

  # bug 9170
  def test_should_not_allow_blank_value_to_be_entered_for_property_on_transition
    priority_def = @project.find_property_definition(PRIORITY); priority_def.name = '<h1>priority</h1>'; priority_def.save!
    card = create_card!(:name => 'for testing')
    transition = create_transition_for(@project, 'testing managed text', :set_properties => { priority_def.name => REQUIRE_USER_INPUT })
    open_card(@project, card)
    click_transition_link_on_card(transition)
    assert_blank_property_value_not_allowed(priority_def)
    assert_enabled('complete_transition')
  end

  # bug 3625; hijacked test to also check html escaping
  def test_cannot_create_value_for_free_text_property_that_begins_and_ends_during_transition_creation_edit
    address_def = @project.find_property_definition(ADDRESS); address_def.name = '<h1>address</h1>'; address_def.save!
    value_that_begins_and_ends_with_parens = '(foo)'
    another_value_that_begins_and_ends_with_parens = '(bar)'
    card = create_card!(:name => 'for testing')
    open_transition_create_page(@project)
    transition_name = 'testing free text'
    type_transition_name(transition_name)
    add_value_to_property_on_transition_sets(@project, address_def.name, value_that_begins_and_ends_with_parens)
    add_value_to_property_on_transition_requires(@project, address_def.name, another_value_that_begins_and_ends_with_parens)
    click_create_transition
    assert_error_message(/#{address_def.name.escape_html}: <(b|B)>\(bar\)<\/(b|B)> is an invalid value. Value cannot both start with '\(' and end with '\)'/, :raw_html => true)
    assert_error_message(/#{address_def.name.escape_html}: <(b|B)>\(foo\)<\/(b|B)> is an invalid value. Value cannot both start with '\(' and end with '\)' unless it is an existing project variable which is available for this property./, :raw_html => true)
    assert_transition_not_present_on_managment_page_for(@project, transition_name)
    open_card(@project, card)
    assert_transition_not_present_on_card(transition_name)
  end

  # bug 3625; hijacked test to also check html escaping
  def test_cannot_create_value_for_managed_property_that_begins_and_ends_during_transition_creation
    status_def = @project.find_property_definition(STATUS); status_def.name = '<h1>status</h1>'; status_def.save!
    value_that_begins_and_ends_with_parens = '(foo)'
    another_value_that_begins_and_ends_with_parens = '(bar)'
    card = create_card!(:name => 'for testing')
    open_transition_create_page(@project)
    transition_name = 'testing managed'
    type_transition_name(transition_name)
    add_value_to_property_on_transition_sets(@project, status_def.name, value_that_begins_and_ends_with_parens)
    add_value_to_property_on_transition_requires(@project, status_def.name, another_value_that_begins_and_ends_with_parens)
    click_create_transition
    assert_error_message(/#{status_def.name.escape_html}: <(b|B)>\(bar\)<\/(b|B)> is an invalid value. Value cannot both start with '\(' and end with '\)'/, :raw_html => true)
    assert_error_message(/#{status_def.name.escape_html}: <(b|B)>\(foo\)<\/(b|B)> is an invalid value. Value cannot both start with '\(' and end with '\)' unless it is an existing project variable which is available for this property./, :raw_html => true)
    assert_transition_not_present_on_managment_page_for(@project, transition_name)
    open_card(@project, card)
    assert_transition_not_present_on_card(transition_name)
  end

  # bug 3625 & 3684
  def test_cannot_update_existing_transition_with_value_that_begins_and_ends_during_transition_edit
    value_that_begins_and_ends_with_parens = '(foo)'
    another_value_that_begins_and_ends_with_parens = '(bar)'
    card = create_card!(:name => 'for testing')
    open_transition_create_page(@project)
    transition_name = 'testing free text'
    transition = create_transition(@project, transition_name, :required_properties => { STATUS => NEW }, :set_properties => { STATUS => OPEN })
    open_transition_for_edit(@project, transition)
    type_transition_name(transition_name)
    add_value_to_property_on_transition_sets(@project, STATUS, value_that_begins_and_ends_with_parens)
    add_value_to_property_on_transition_requires(@project, STATUS, another_value_that_begins_and_ends_with_parens)
    click_save_transition
    assert_error_message_without_html_content("#{STATUS}: #{another_value_that_begins_and_ends_with_parens} is an invalid value. Value cannot both start with '(' and end with ')'. #{STATUS}: #{value_that_begins_and_ends_with_parens} is an invalid value. Value cannot both start with '(' and end with ')' unless it is an existing project variable which is available for this property.")
    navigate_to_transition_management_for(@project)
    @browser.assert_text_not_present(value_that_begins_and_ends_with_parens)
    @browser.assert_text_not_present(another_value_that_begins_and_ends_with_parens)
    open_transition_for_edit(@project, transition)
    assert_sets_properties_not(STATUS => value_that_begins_and_ends_with_parens)
    assert_requires_properties_not(STATUS => another_value_that_begins_and_ends_with_parens)
    open_card(@project, card)
    assert_transition_not_present_on_card(transition_name)
    open_card(@project, card)
    assert_transition_not_present_on_card(transition_name)
  end

  # bug 3801
  def test_dropdowns_retain_values_after_error_is_displayed
    foo_value = '(foo)'
    bar_value = '(bar)'

    navigate_to_transition_management_for(@project)
    click_create_new_transition_link

    type_transition_name('my transition')
    add_value_to_property_on_transition_requires(@project, STATUS, foo_value)
    add_value_to_property_on_transition_sets(@project, STATUS, bar_value)
    click_create_transition
    assert_error_message_without_html_content("#{STATUS}: #{foo_value} is an invalid value. Value cannot both start with '(' and end with ')'. #{STATUS}: #{bar_value} is an invalid value. Value cannot both start with '(' and end with ')' unless it is an existing project variable which is available for this property.")

    assert_requires_property(STATUS => foo_value)
    assert_sets_property(STATUS => bar_value)

    set_sets_properties(@project, STATUS => NOT_SET)
    click_create_transition
    assert_error_message_without_html_content("#{STATUS}: #{foo_value} is an invalid value. Value cannot both start with '(' and end with ')'")
  end

  # Bug 3796.
  def test_should_show_information_message_when_creating_transition
    navigate_to_transition_management_for(@project)
    click_create_new_transition_link

    transition_name = 'timmy'
    type_transition_name(transition_name)
    add_value_to_property_on_transition_requires(@project, STATUS, NEW)
    add_value_to_property_on_transition_sets(@project, STATUS, OPEN)
    click_create_transition
    assert_notice_message("Transition #{transition_name} was successfully created")
  end

  # Bug 3796.
  def test_should_show_information_message_when_updating_transition
    open_transition_create_page(@project)
    transition_name = 'milly'
    transition = create_transition(@project, transition_name, :required_properties => { STATUS => NEW }, :set_properties => { STATUS => OPEN })
    open_transition_for_edit(@project, transition)
    new_transition_name = 'ian'
    type_transition_name(new_transition_name)
    click_save_transition
    assert_notice_message("Transition #{new_transition_name} was successfully updated")
  end

  #Bug 3796
  def test_should_show_information_message_when_deleting_transition
    transition_name = "minnie"
    transition = create_transition(@project, transition_name, :required_properties => { STATUS => NEW }, :set_properties => { STATUS => OPEN })
    navigate_to_transition_management_for(@project)
    click_delete(transition)
    @browser.verify_confirmation("Are you sure?")
    assert_notice_message("Transition #{transition_name} was successfully deleted")
  end

  # bug 4166
  def test_transitions_can_be_run_from_grid_view_card_popups
    card = create_card!(:name => 'plain card', STATUS => NEW)
    transition = create_transition(@project, 'some transition', :set_properties => { STATUS => OPEN })
    navigate_to_grid_view_for(@project)

    click_on_card_in_grid_view(card.number)
    click_transition_link_on_card_in_grid_view(transition)
    open_card(@project, card)
    assert_property_set_on_card_show(STATUS, OPEN)
  end

  # bug 4180
  def test_running_transition_on_grid_does_not_reset_lanes_to_tab_default
    card = create_card!(:name => 'c1')
    transition = create_transition(@project, 'some transition', :set_properties => { STATUS => OPEN })

    navigate_to_grid_view_for(@project)
    group_columns_by(STATUS)
    assert_lane_not_present(STATUS, NEW)
    assert_lane_not_present(STATUS, OPEN)
    assert_lane_not_present(STATUS, DONE)

    add_lanes(@project, STATUS, [NEW, DONE])
    view = create_card_list_view_for(@project, 'some grid')
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(view)

    click_tab('some grid')
    add_lanes(@project, STATUS, [OPEN])
    click_on_card_in_grid_view(card.number)
    click_transition_link_on_card_in_grid_view(transition)
    assert_lane_present(STATUS, OPEN)
  end

  # bug 4490
  def test_running_require_user_to_enter_transition_on_grid_does_not_stop_you_from_running_another_transition_right_after
    req_input_transition = create_transition(@project, 'require user input', :required_properties => { STATUS => DONE }, :set_properties => { STATUS => Transition::USER_INPUT_REQUIRED })
    regular_transition = create_transition(@project, 'regular transition', :required_properties => { STATUS => NEW }, :set_properties => { STATUS => DONE })

    card1 = create_card!(:name => 'some card', STATUS => DONE)
    card2 = create_card!(:name => 'some other card', STATUS => NEW)
    navigate_to_grid_view_for(@project)

    click_on_card_in_grid_view(card1.number)
    click_transition_link_on_card_in_grid_view(req_input_transition)
    set_value_to_property_in_lightbox_editor_on_transition_execute(STATUS => IN_PROGRESS)
    click_on_complete_transition
    close_popup

    click_on_card_in_grid_view(card2.number)
    click_transition_link_on_card_in_grid_view(regular_transition)

    assert_error_message_not_present
  end

  #bug 4538
  def test_removing_hidden_property_from_the_type_should_remove_the_transition_using_it_for_that_type
    hide_property(@project, STATUS)
    transition_setting_hidden_property = create_transition_for(@project, 'setting hidden', :type => CARD, :set_properties => { STATUS => OPEN })
    edit_card_type_for_project(@project, CARD, :uncheck_properties => [STATUS], :wait_on_warning => true)
    @browser.assert_text_present("This update will delete transition #{transition_setting_hidden_property.name}. This deletion is happening because transition #{transition_setting_hidden_property.name} depends upon card type #{CARD} having property #{STATUS}")
    click_continue_to_update_link
    assert_transition_not_present_on_managment_page_for(@project, transition_setting_hidden_property.name)
  end

  #bug 4528
  def test_transitions_set_to_current_user_does_not_delete_transition_when_mingle_admin_removes_himself_from_the_team_list
    login_as_admin_user
    user_property = 'user'
    create_property_definition_for(@project, user_property, :type => 'user')
    transition_set_to_me = create_transition_for(@project, 'set to me', :set_properties => { user_property => '(current user)' })
    remove_from_team_for(@project, @admin_user)
    assert_transition_present_for(@project, transition_set_to_me)
  end

  # bug 7902
  def test_should_not_direct_to_other_page_when_executing_transition_in_popup_on_grid_view
    login_as_admin_user
    user_property = 'user'
    card = create_card!(:name => 'card')
    create_property_definition_for(@project, user_property, :type => 'user')
    transition_set_to_me = create_transition_for(@project, 'set to me', :set_properties => { user_property => '(current user)' })
    navigate_to_grid_view_for(@project)
    click_on_card_in_grid_view(card.number)
    click_transition_link_on_card_in_grid_view(transition_set_to_me)
    navigate_to_history_for(@project)
    assert_text_not_present("#{transition_set_to_me.name.html_bold} successfully applied to card. ##{card.number}")
  end
end
