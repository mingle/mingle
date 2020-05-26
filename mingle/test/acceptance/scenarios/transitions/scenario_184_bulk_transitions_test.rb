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

# Tags: scenario, transitions
class Scenario184BulkTransitionsTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  STATUS = 'Status'
  PRIORITY = 'Priority'
  BUG_STATUS = 'BugStatus'
  OWNER = 'Owner'
  CREATED = 'Created'
  ADDRESS = 'Address'

  NEW = 'new'
  OPEN = 'open'
  IN_PROGRESS = 'in progress'
  DONE = 'dev compete'
  CLOSE = 'closed'
  HIGH = 'high'
  LOW = 'low'

  ANY = '(any)'
  REQUIRE_USER_INPUT = '(user input - required)'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @admin_user = users(:admin)
    @project_member = users(:project_member)
    @non_team_member = users(:existingbob)
    @non_admin_user = users(:longbob)
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_184', :users => [@admin_user, @project_member, @non_admin_user], :admins => [@project_admin_user])
    setup_property_definitions(STATUS => [NEW, OPEN, IN_PROGRESS, DONE, CLOSE], PRIORITY => [HIGH, LOW], BUG_STATUS => ['Open', 'Fixed', 'Verified', 'Closed'])
    @created_date = setup_date_property_definition(CREATED)
    @address_text = setup_text_property_definition(ADDRESS)
    @owner = setup_user_definition(OWNER)
    login_as_proj_admin_user
  end

  def test_bulk_transitions_button_enabled_when_a_card_is_selected
    card = create_card!(:name => 'transition', STATUS => NEW)
    navigate_to_card_list_for(@project)
    @browser.assert_has_classname("bulk_transitions", "disabled")
    @browser.assert_element_present("bulk_transitions")
    @browser.click("checkbox_0")
    @browser.assert_does_not_have_classname("bulk_transitions", "disabled")
  end

  def test_no_transitions_message_upon_clicking_bulk_transitions
    card = create_card!(:name => 'transition', STATUS => NEW)
    login_as_project_member
    navigate_to_card_list_for(@project)
    @browser.click("checkbox_0")
    open_bulk_transitions
    @browser.assert_text_present_in('transition-selector', "No available transitions for selected cards")
  end

  def test_card_transitions_should_be_listed_in_smart_order
    transition_A = create_transition(@project, 'A transition', :required_properties => {STATUS => NEW}, :set_properties => {STATUS => DONE})
    transition_C = create_transition(@project, 'Close', :required_properties => {STATUS => NEW}, :set_properties => {STATUS => DONE})
    transition_a = create_transition(@project, 'another transiton', :required_properties => {STATUS => NEW}, :set_properties => {STATUS => DONE})
    card = create_card!(:name => 'card', STATUS => NEW)

    navigate_to_card_list_for(@project)
    select_all
    assert_transition_ordered_in_bulk_edit(transition_A, transition_a, transition_C)

    open_card(@project, card)
    assert_transition_ordered_in_card_show(transition_A, transition_a, transition_C)

    navigate_to_grid_view_for(@project)
    click_on_card_in_grid_view(card.number)
    assert_transition_ordered_in_card_popup(@project, transition_A, transition_a, transition_C)

    group_columns_by(STATUS)
    add_lanes(@project, STATUS, [NEW, DONE])
    drag_and_drop_card_from_lane(card.html_id, STATUS, DONE)
    assert_transition_ordered_in_transitions_popup(transition_A, transition_a, transition_C)
  end

  def test_assigned_transition_only_visible_to_assignee_on_both_card_and_card_list
    transition_assigned_to_admin_user = create_transition_for(@project, 'Open for ADMIN', :required_properties => {STATUS => NEW}, :set_properties => {STATUS => OPEN},
                                                                :for_team_members => [@project_admin_user])

    card_for_transitioning = create_card!(:name => 'plain card', STATUS => NEW)
    open_card(@project, card_for_transitioning.number)
    assert_transition_present_on_card(transition_assigned_to_admin_user)

    navigate_to_card_list_by_clicking(@project)
    select_all
    assert_bulk_transition_available(transition_assigned_to_admin_user)
    logout

    login_as("#{@non_admin_user.login}", 'longtest')
    open_card(@project, card_for_transitioning.number)
    assert_transition_not_present_on_card(transition_assigned_to_admin_user)
    navigate_to_card_list_by_clicking(@project)
    select_all
    assert_no_bulk_transitions_available
  end

  def test_transition_with_comment_reqire_fileds_set_is_available_for_bulk_edit
    mark_closed = 'Mark Closed'
    card1 = create_card!(:name => 'card1', PRIORITY => HIGH, OWNER => @admin_user.id, ADDRESS => '123, kenk st, NSW 200', CREATED => '05 May- 2005')
    transition1 = create_transition_for(@project, mark_closed, :set_properties => {BUG_STATUS => 'Closed'}, :require_comment => true)
    transition2 = create_transition_for(@project, 'Mark closed with fields', :set_properties => {BUG_STATUS => 'Closed', OWNER => REQUIRE_USER_INPUT,
      ADDRESS =>  REQUIRE_USER_INPUT, CREATED => REQUIRE_USER_INPUT, PRIORITY => REQUIRE_USER_INPUT})
    click_all_tab
    select_all
    assert_bulk_transition_available(transition1)
    assert_bulk_transition_not_available(transition2)
  end

  #bug 2274, #7535
  def test_bulk_transtions_disabled_when_no_transition_available_or_no_transition_matches_selected_cards
    card = create_card!(:name => 'for testing')
    navigate_to_card_list_for(@project)
    select_all
    assert_no_bulk_transitions_available

    create_transition_for(@project, 'Open this', :required_properties => {STATUS => NEW}, :set_properties => {STATUS => OPEN})
    navigate_to_card_list_for(@project)
    select_all
    assert_no_bulk_transitions_available

    sample_transition = create_transition_for(@project, 'sample', :required_properties => {STATUS => ANY}, :set_properties => {STATUS => OPEN})
    navigate_to_card_list_for(@project)
    select_all
    assert_bulk_transition_available(sample_transition)
  end

  # bug 4260
  def test_able_to_apply_bulk_transition_to_card_whose_property_was_set_through_individualy_editing_card
    navigate_to_card_list_for(@project, [STATUS])
    transition_name = 'transition test'
    transition = create_transition_for(@project, transition_name, :type => 'Card', :required_properties => { STATUS => NEW}, :set_properties => {STATUS => OPEN})
    testing_card = create_card!(:name => 'testing card')
    open_card(@project, testing_card)
    add_new_value_to_property_on_card_show(@project, STATUS, NEW)
    navigate_to_card_list_for(@project, [STATUS])
    check_cards_in_list_view(testing_card)
    assert_bulk_transition_available(transition)
  end

end
