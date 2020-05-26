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
class Scenario35CardTransitions1Test < ActiveSupport::TestCase

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

  def test_should_provide_tooltip_for_property_on_transition_lightbox
    setup_numeric_property_definition(SIZE, [1, 2, 3, 4, 12]).update_attributes(:description => "This property indicates size of each card.")

    mark_test = 'Marked as tested'
    transition = create_transition_for(@project, mark_test, :set_properties => { OWNER => REQUIRE_USER_INPUT, PRIORITY => OPTIONAL_USER_INPUT, SIZE => REQUIRE_USER_INPUT })

    card = create_card!(:name => 'card')
    open_card(@project, card.number)
    click_transition_link_on_card(transition)
    assert_property_tooltip_on_transition_lightbox(SIZE)
  end

  def test_should_provide_tooltip_for_property_on_transition_edit_page
    edit_property_definition_for(@project, OWNER, :description => "this is owner.")

    navigate_to_transition_management_for(@project)
    click_create_new_transition_link
    assert_property_tooltip_on_transition_edit_page(REQUIRES, OWNER)
    assert_property_tooltip_on_transition_edit_page(SETS, OWNER)
  end

  def test_search_value_for_user_type_property_in_transition_lightbox
    admin_name = @admin_user.name
    non_admin_name = @non_admin_user.name
    project_admin_name = @project_admin_user.name

    setup_numeric_property_definition(SIZE, [1, 2, 3, 4, 12])
    mark_test = 'Marked as tested'
    transition = create_transition_for(@project, mark_test, :set_properties => { OWNER => REQUIRE_USER_INPUT, PRIORITY => OPTIONAL_USER_INPUT, SIZE => REQUIRE_USER_INPUT })

    card = create_card!(:name => 'card')
    open_card(@project, card.number)
    click_transition_link_on_card(transition)

    click_property_droplist_link_in_transition_lightbox(OWNER)
    type_keyword_to_search_value_for_property_in_transition_lightbox(OWNER, 'Hello')
    assert_value_not_present_in_property_drop_down_in_transition_lightbox(OWNER, [CURRENT_USER, admin_name, non_admin_name, project_admin_name])
    type_keyword_to_search_value_for_property_in_transition_lightbox(OWNER, 'adm')
    assert_value_present_in_property_drop_down_in_transition_lightbox(OWNER, [admin_name, project_admin_name])
    assert_value_not_present_in_property_drop_down_in_transition_lightbox(OWNER, [CURRENT_USER])
    type_keyword_to_search_value_for_property_in_transition_lightbox(OWNER, "")
    select_value_in_drop_down_for_property_in_transition_lightbox(OWNER, CURRENT_USER)
    assert_value_for_property_in_transition_lightbox(OWNER, CURRENT_USER)

    click_property_droplist_link_in_transition_lightbox(PRIORITY)
    type_keyword_to_search_value_for_property_in_transition_lightbox(PRIORITY, 'Hello')
    assert_value_not_present_in_property_drop_down_in_transition_lightbox(PRIORITY, [NOT_SET, HIGH, LOW])
    type_keyword_to_search_value_for_property_in_transition_lightbox(PRIORITY, 'O')
    assert_value_present_in_property_drop_down_in_transition_lightbox(PRIORITY, [NOT_SET, LOW])
    assert_value_not_present_in_property_drop_down_in_transition_lightbox(PRIORITY, [HIGH])
    select_value_in_drop_down_for_property_in_transition_lightbox(PRIORITY, NOT_SET)
    assert_value_for_property_in_transition_lightbox(PRIORITY, NOT_SET)

    click_property_droplist_link_in_transition_lightbox(SIZE)
    type_keyword_to_search_value_for_property_in_transition_lightbox(SIZE, 'Hello')
    assert_value_not_present_in_property_drop_down_in_transition_lightbox(SIZE, [1, 2, 3, 4, 12])
    type_keyword_to_search_value_for_property_in_transition_lightbox(SIZE, '1')
    assert_value_present_in_property_drop_down_in_transition_lightbox(SIZE, [1, 12]) # <= RANDOM FAILED AT
    assert_value_not_present_in_property_drop_down_in_transition_lightbox(SIZE, [2, 3, 4]) # => https://go01.thoughtworks.com/go/tab/build/detail/Mingle_trunk--Windows2003-PostgreSQL/6372/Acceptances/1/Acceptance_Transitions
    select_value_in_drop_down_for_property_in_transition_lightbox(SIZE, 12) # Suspecting the "filtering" in js wasn't finished before the assertion
    assert_value_for_property_in_transition_lightbox(SIZE, '12')
  end

  def test_search_value_for_user_type_property_when_create_transition
    admin_name = @admin_user.name
    non_admin_name = @non_admin_user.name
    project_admin_name = @project_admin_user.name

    navigate_to_transition_management_for(@project)
    click_create_new_transition_link

    click_property_on_transition_edit_page(SETS, OWNER)
    type_keyword_to_search_value_for_property_on_transition_edit_page(SETS, OWNER, "Hello")
    assert_value_not_present_in_property_drop_down_on_transition_edit_page(SETS, OWNER, [NO_CHANGE, NOT_SET, CURRENT_USER, REQUIRE_USER_INPUT, OPTIONAL_USER_INPUT, admin_name, non_admin_name, project_admin_name])
    type_keyword_to_search_value_for_property_on_transition_edit_page(SETS, OWNER, "adm")
    assert_value_present_in_property_drop_down_on_transition_edit_page(SETS, OWNER, [admin_name, project_admin_name])
    assert_value_not_present_in_property_drop_down_on_transition_edit_page(SETS, OWNER, [NO_CHANGE, NOT_SET, CURRENT_USER, REQUIRE_USER_INPUT, OPTIONAL_USER_INPUT])
    type_keyword_to_search_value_for_property_on_transition_edit_page(SETS, OWNER, "")
    select_value_in_drop_down_for_property_on_transition_edit_page(SETS, OWNER, CURRENT_USER)
    assert_value_for_property_on_transition_edit_page(SETS, OWNER, CURRENT_USER)

    click_property_on_transition_edit_page(REQUIRES, OWNER)
    type_keyword_to_search_value_for_property_on_transition_edit_page(REQUIRES, OWNER, "Hello")
    assert_value_not_present_in_property_drop_down_on_transition_edit_page(REQUIRES, OWNER, [ANY, SET, NOT_SET, CURRENT_USER, admin_name, non_admin_name, project_admin_name])
    type_keyword_to_search_value_for_property_on_transition_edit_page(REQUIRES, OWNER, "adm")
    assert_value_present_in_property_drop_down_on_transition_edit_page(REQUIRES, OWNER, [admin_name, project_admin_name])
    assert_value_not_present_in_property_drop_down_on_transition_edit_page(REQUIRES, OWNER, [ANY, SET, NOT_SET, CURRENT_USER])
    type_keyword_to_search_value_for_property_on_transition_edit_page(REQUIRES, OWNER, "")
    select_value_in_drop_down_for_property_on_transition_edit_page(REQUIRES, OWNER, CURRENT_USER)
    assert_value_for_property_on_transition_edit_page(REQUIRES, OWNER, CURRENT_USER)
  end

  def test_search_value_for_managed_number_property_when_create_transition
    setup_numeric_property_definition(SIZE, [1, 2, 3, 4])
    navigate_to_transition_management_for(@project)
    click_create_new_transition_link

    click_property_on_transition_edit_page(SETS, SIZE)
    type_keyword_to_search_value_for_property_on_transition_edit_page(SETS, SIZE, 'Hello')
    assert_value_not_present_in_property_drop_down_on_transition_edit_page(SETS, SIZE, [NOT_SET, NO_CHANGE, REQUIRE_USER_INPUT, OPTIONAL_USER_INPUT, 1, 2, 3, 4])
    type_keyword_to_search_value_for_property_on_transition_edit_page(SETS, SIZE, '1')
    assert_value_present_in_property_drop_down_on_transition_edit_page(SETS, SIZE, [1])
    assert_value_not_present_in_property_drop_down_on_transition_edit_page(SETS, SIZE, [NOT_SET, NO_CHANGE, REQUIRE_USER_INPUT, OPTIONAL_USER_INPUT, 2, 3, 4])
    select_value_in_drop_down_for_property_on_transition_edit_page(SETS, SIZE, 1)
    assert_value_for_property_on_transition_edit_page(SETS, SIZE, '1')

    click_property_on_transition_edit_page(REQUIRES, SIZE)
    type_keyword_to_search_value_for_property_on_transition_edit_page(REQUIRES, SIZE, 'Hello')
    assert_value_not_present_in_property_drop_down_on_transition_edit_page(REQUIRES, SIZE, [ANY, SET, NOT_SET, 1, 2, 3, 4])
    type_keyword_to_search_value_for_property_on_transition_edit_page(REQUIRES, SIZE, 'Not')
    assert_value_present_in_property_drop_down_on_transition_edit_page(REQUIRES, SIZE, [NOT_SET])
    assert_value_not_present_in_property_drop_down_on_transition_edit_page(REQUIRES, SIZE, [ANY, SET, 1, 2, 3, 4])
    select_value_in_drop_down_for_property_on_transition_edit_page(REQUIRES, SIZE, NOT_SET)
    assert_value_for_property_on_transition_edit_page(REQUIRES, SIZE, NOT_SET)
  end

  def test_search_value_for_managed_text_property_when_create_transition
    navigate_to_transition_management_for(@project)
    click_create_new_transition_link

    click_property_on_transition_edit_page(SETS, PRIORITY)
    type_keyword_to_search_value_for_property_on_transition_edit_page(SETS, PRIORITY, 'Hello')
    assert_value_not_present_in_property_drop_down_on_transition_edit_page(SETS, PRIORITY, [NOT_SET, NO_CHANGE, REQUIRE_USER_INPUT, OPTIONAL_USER_INPUT, HIGH, LOW])
    type_keyword_to_search_value_for_property_on_transition_edit_page(SETS, PRIORITY, 'O')
    assert_value_present_in_property_drop_down_on_transition_edit_page(SETS, PRIORITY, [NOT_SET, NO_CHANGE, OPTIONAL_USER_INPUT, LOW])
    assert_value_not_present_in_property_drop_down_on_transition_edit_page(SETS, PRIORITY, [REQUIRE_USER_INPUT, HIGH])
    select_value_in_drop_down_for_property_on_transition_edit_page(SETS, PRIORITY, LOW)
    assert_value_for_property_on_transition_edit_page(SETS, PRIORITY, LOW)

    click_property_on_transition_edit_page(REQUIRES, PRIORITY)
    type_keyword_to_search_value_for_property_on_transition_edit_page(REQUIRES, PRIORITY, 'Hello')
    assert_value_not_present_in_property_drop_down_on_transition_edit_page(REQUIRES, PRIORITY, [ANY, SET, NOT_SET, HIGH, LOW])
    type_keyword_to_search_value_for_property_on_transition_edit_page(REQUIRES, PRIORITY, 'O')
    assert_value_present_in_property_drop_down_on_transition_edit_page(REQUIRES, PRIORITY, [NOT_SET, LOW])
    assert_value_not_present_in_property_drop_down_on_transition_edit_page(REQUIRES, PRIORITY, [ANY, SET, HIGH])
    select_value_in_drop_down_for_property_on_transition_edit_page(REQUIRES, PRIORITY, LOW)
    assert_value_for_property_on_transition_edit_page(REQUIRES, PRIORITY, LOW)
  end

  def test_transitions_cannot_be_seen_across_projects
    @decoy_project = create_project(:prefix => 'scenario_35_decoy', :users => [@project_admin_user])
    setup_property_definitions(STATUS => [NEW, OPEN, IN_PROGRESS], PRIORITY => [HIGH, LOW])
    card_in_decoy_project = create_card!(:name => 'plain card', STATUS => NEW)
    @project.with_active_project do |project|
      transition = create_transition_for(@project, 'Open this', :set_properties => { STATUS => NEW })
      assert_transition_present_for(@project, transition)
      assert_transition_not_present_for(@decoy_project, transition)
      @browser.assert_text_present "There are currently no transitions to list."
      open_card(@decoy_project, card_in_decoy_project.number)
      assert_transition_not_present_on_card(transition)
    end
  end

  def test_non_admin_project_team_member_cannot_create_or_edit_or_delete_transitions
    create_transition(@project, 'close', :set_properties => { :priority => HIGH })
    logout
    login_as("#{@non_admin_user.login}", 'longtest')
    navigate_to_transition_management_for(@project)
    @browser.assert_element_not_present('link=Create new card transition')
    @browser.assert_element_not_present('link=Edit this transition')
    @browser.assert_element_not_present(css_locator('.delete-transition'))
    @browser.open("/projects/#{@project.identifier}/transitions/new")
    assert_cannot_access_resource_error_message_present
    @browser.open("/projects/#{@project.identifier}/transitions/destroy")
    assert_cannot_access_resource_error_message_present

    logout
    login_as("#{@project_admin_user.login}")
    navigate_to_transition_management_for(@project)
    @browser.assert_element_present('link=Create new card transition')
    @browser.assert_element_present('link=Edit this transition')
    @browser.assert_element_present(css_locator('.delete-transition'))
  end

  def test_project_admin_can_create_transition
    logout
    login_as("#{@project_admin_user.login}")
    transition_created_by_proj_admin = create_transition_for(@project, 'by project admin', :set_properties => { :priority => HIGH })
    assert_transition_present_for(@project, transition_created_by_proj_admin)
  end

  #bug 6385
  def test_cancel_transtion_creation_should_not_leave_a_fake_transition_behind
    navigate_to_transition_management_for(@project)
    click_create_new_transition_link
    fill_in_transition_values(@project, 'new transition', :set_properties => { STATUS => NEW, PRIORITY => HIGH })
    @browser.click_and_wait('link=Cancel')
    @browser.assert_element_not_present(class_locator("delete-transition"))
  end

  # bug 757 & 1442 & 6601
  def test_transition_creation_validations
    navigate_to_transition_management_for(@project)
    click_create_new_transition_link
    @browser.type('transition_name', 'trans')
    click_create_transition
    assert_error_message('Transition must set at least one property.') #757

    set_required_properties(@project, STATUS => OPEN)
    set_sets_properties(@project, STATUS => NEW)

    set_required_properties(@project, PRIORITY => LOW)
    set_sets_properties(@project, PRIORITY => HIGH)

    @browser.type('transition_name', '')
    click_create_transition
    assert_error_message("Name can't be blank") #1443


    @browser.type('transition_name', 'trans')
    select_only_selected_team_members_radio_button
    click_create_transition
    assert_error_message('Please select at least one team member')
    assert_requires_property(STATUS => OPEN, PRIORITY => LOW)
    assert_sets_property(STATUS => NEW, PRIORITY => HIGH) # 6601
  end

  def test_can_only_assign_transitions_to_team_members
    navigate_to_transition_management_for(@project)
    click_create_new_transition_link
    select_only_selected_team_members_radio_button
    @browser.assert_element_not_present css_locator("input[value='#{@non_team_member.id}']")
  end

  def test_transition_does_not_remove_existing_set_values_that_are_set_to_any
    create_property_definition_for(@project, 'tester', :type => 'user')
    @project.reload.activate
    transition_that_any_priority = create_transition_for(@project, 'Open', :required_properties => { STATUS => NEW, :priority => ANY }, :set_properties => { STATUS => OPEN })
    high_priority_card = create_card!(:name => 'plain card', STATUS => NEW, :priority => HIGH, :tester => @admin_user.id)
    open_card(@project, high_priority_card.number)
    click_transition_link_on_card(transition_that_any_priority)
    assert_properties_set_on_card_show(STATUS => OPEN, :priority => HIGH, :tester => ADMIN_NAME_TRUNCATED)
  end

  def test_transition_sets_exisiting_properties_to_not_set
    create_property_definition_for(@project, 'tester', :type => 'user')
    @project.reload.activate
    transition_priority_to_not_set = create_transition_for(@project, 'De-prioritize', :set_properties => { :priority => NOT_SET, :tester => NOT_SET }, :required_properties => { :priority => HIGH })
    high_priority_card = create_card!(:name => 'plain card', :priority => HIGH, :tester => @admin_user.id)
    open_card(@project, high_priority_card.number)
    click_transition_link_on_card(transition_priority_to_not_set)
    assert_properties_set_on_card_show(:priority => NOT_SET, :tester => NOT_SET)
  end

  def test_tranisions_should_be_deleted_when_dependent_user_properties_are_deleted
    user_property = 'tester'
    tester = create_property_definition_for(@project, user_property, :type => 'user')
    @project.reload.activate

    transition_to_be_deleted_with_property = create_transition_for(@project, 'Open', :required_properties => { STATUS => NEW, :priority => HIGH }, :set_properties => { STATUS => OPEN, user_property => @project_admin_user.name })
    navigate_to_property_management_page_for(@project)
    delete_property_for(@project, user_property, :stop_at_confirmation => true)
    @browser.assert_text_present("Used by 1 Transition: #{transition_to_be_deleted_with_property.name}. This will be deleted.")
    @browser.click_and_wait("link=Continue to delete")
    assert_notice_message("Property #{user_property} has been deleted.")
    assert_property_does_not_exist(user_property)
    assert_transition_not_present_for(@project, transition_to_be_deleted_with_property)
  end

  def test_in_transition_for_user_property_set_for_perticular_user_cannot_be_used_by_other_user
    user_property = 'Owner'
    create_property_definition_for(@project, user_property, :type => 'user')
    @project.reload.activate
    transition_dev_complete_for_dev = create_transition_for(@project, 'Dev Complete', :set_properties => { STATUS => DONE, user_property => '(current user)' }, :required_properties => { STATUS => IN_PROGRESS, user_property => '(current user)' }, :for_team_members => [@non_admin_user])
    transition_qa_complete_for_qa = create_transition_for(@project, 'QA Complete', :set_properties => { STATUS => CLOSE, user_property => '(current user)' }, :required_properties => { STATUS => DONE, user_property => @non_admin_user.name }, :for_team_members => [@admin_user])
    card_for_transitioning = create_card!(:name => 'plain card', OWNER => @non_admin_user.id)
    open_card(@project, card_for_transitioning.number)
    set_properties_on_card_show(STATUS => IN_PROGRESS)
    assert_transition_not_present_on_card(transition_dev_complete_for_dev)
    set_properties_on_card_show(STATUS => '(not set)')

    login_as("#{@admin_user.login}")
    open_card(@project, card_for_transitioning.number)
    set_properties_on_card_show(STATUS => IN_PROGRESS)
    assert_transition_not_present_on_card(transition_dev_complete_for_dev)

    login_as("#{@non_admin_user.login}", 'longtest')
    open_card(@project, card_for_transitioning.number)
    assert_transition_present_on_card(transition_dev_complete_for_dev)
    click_transition_link_on_card(transition_dev_complete_for_dev)
    assert_transition_success_message(transition_dev_complete_for_dev.name, card_for_transitioning.number) # for sake of bug #8312
    assert_transition_not_present_on_card(transition_dev_complete_for_dev)

    login_as("#{@admin_user.login}")
    open_card(@project, card_for_transitioning.number)
    assert_transition_present_on_card(transition_qa_complete_for_qa)
    assert_properties_set_on_card_show(STATUS => DONE)
    click_transition_link_on_card(transition_qa_complete_for_qa)
    assert_transition_success_message(transition_qa_complete_for_qa.name, card_for_transitioning.number)
    assert_transition_not_present_on_card(transition_qa_complete_for_qa)
    assert_properties_set_on_card_show(STATUS => CLOSE)
  end

  def test_transitions_bulk_edit_for_user_properties_for_current_user
    user_property = 'Owner'
    create_property_definition_for(@project, user_property, :type => 'user')
    @project.reload.activate
    transition_dev_complete_for_dev = create_transition_for(@project, 'Dev Complete', :set_properties => { STATUS => DONE, user_property => '(current user)' }, :required_properties => { STATUS => IN_PROGRESS, user_property => '(current user)' }, :for_team_members => [@non_admin_user])
    card_for_transitioning = create_card!(:name => 'plain card', OWNER => @non_admin_user.id)
    card_not_for_transitioning = create_card!(:name => 'plain card', OWNER => @admin_user.id)
    open_card(@project, card_for_transitioning.number)
    set_properties_on_card_show(STATUS => IN_PROGRESS)
    assert_transition_not_present_on_card(transition_dev_complete_for_dev)

    login_as("#{@non_admin_user.login}", 'longtest')
    navigate_to_favorites_management_page_for(@project)
    click_all_tab
    @browser.click("checkbox_1")
    click_edit_properties_button
    execute_bulk_transition_action(transition_dev_complete_for_dev)
    assert_bulk_action_for_transitions_applied_for_selected_card(transition_dev_complete_for_dev.name, card_for_transitioning.number)
    open_card(@project, card_for_transitioning.number)
    assert_properties_set_on_card_show(STATUS => DONE)
  end

  def test_global_properties_displayed_when_card_type_is_any_and_check_default_values_to_properties_during_transition_creation
    edit_card_type_for_project(@project, 'Card', :new_card_type_name => TYPE_STORY, :properties => [STATUS, PRIORITY])
    create_card_type_for_project(@project, TYPE_BUG, :properties => [PRIORITY, BUG_STATUS])
    navigate_to_transition_management_for(@project)
    click_create_new_transition_link

    assert_sets_card_type_set_to_no_change
    assert_requires_property_present(PRIORITY)
    assert_requires_property_not_present(BUG_STATUS, STATUS)
    assert_sets_property_present(PRIORITY)
    assert_sets_property_not_present(BUG_STATUS, STATUS)
    assert_requires_property(PRIORITY => ANY)
    assert_sets_property(PRIORITY => NO_CHANGE)
  end

  def test_only_card_type_specific_properties_displayed_while_transition_creation_and_default_values
    edit_card_type_for_project(@project, 'Card', :new_card_type_name => TYPE_STORY, :properties => [STATUS, PRIORITY])
    create_card_type_for_project(@project, TYPE_BUG, :properties => [PRIORITY, BUG_STATUS])
    navigate_to_transition_management_for(@project)
    click_create_new_transition_link

    set_card_type_on_transitions_page(TYPE_STORY)
    assert_sets_card_type_set_to_no_change
    assert_requires_property_present(PRIORITY, STATUS)
    assert_requires_property_not_present(BUG_STATUS)
    assert_sets_property_present(PRIORITY, STATUS)
    assert_sets_property_not_present(BUG_STATUS)
    assert_requires_property(PRIORITY => ANY, STATUS => ANY)
    assert_sets_property(PRIORITY => NO_CHANGE, STATUS => NO_CHANGE)

    set_card_type_on_transitions_page(TYPE_BUG)
    assert_sets_card_type_set_to_no_change
    assert_requires_property_present(PRIORITY, BUG_STATUS)
    assert_requires_property_not_present(STATUS)
    assert_sets_property_present(PRIORITY, BUG_STATUS)
    assert_sets_property_not_present(STATUS)
    assert_requires_property(PRIORITY => ANY, BUG_STATUS => ANY)
    assert_sets_property(PRIORITY => NO_CHANGE, BUG_STATUS => NO_CHANGE)
  end

  def test_card_type_specific_properties_on_edit
    edit_card_type_for_project(@project, 'Card', :new_card_type_name => TYPE_STORY, :properties => [STATUS, PRIORITY])
    create_card_type_for_project(@project, TYPE_BUG, :properties => [PRIORITY, BUG_STATUS])
    transition1 = create_transition_for(@project, 'Bug to close', :type => TYPE_BUG, :set_properties => { BUG_STATUS => 'Closed' })
    open_transition_for_edit(@project, transition1)
    assert_sets_card_type_set_to_no_change
    assert_requires_property_present(PRIORITY, BUG_STATUS)
    assert_requires_property_not_present(STATUS)
    assert_sets_property_present(PRIORITY, BUG_STATUS)
    assert_sets_property_not_present(STATUS)
    assert_requires_property(PRIORITY => ANY, BUG_STATUS => ANY)
    assert_sets_property(PRIORITY => NO_CHANGE, BUG_STATUS => 'Closed')
  end

  def test_required_comment_dialog_for_transition_with_comment_required_to_complete_transition_on_card_view
    mark_closed = 'Mark Closed'
    comment = "this is a test"
    transition1 = create_transition_for(@project, mark_closed, :set_properties => { BUG_STATUS => 'Closed' }, :require_comment => true)
    card1 = create_card!(:name => 'card1')
    open_card(@project, card1.number)
    click_transition_link_on_card_with_input_required(transition1)
    add_comment_for_transition_to_complete_and_complete_the_transaction(comment)
    assert_comment_present(comment)
  end

  def test_transition_can_be_completed_only_if_added_comment_for_transition_with_comment_required_on_card_view
    mark_closed = 'Mark Closed'
    comment = "this is a test"
    transition1 = create_transition_for(@project, mark_closed, :set_properties => { BUG_STATUS => 'Closed' }, :require_comment => true)
    card1 = create_card!(:name => 'card1')
    open_card(@project, card1.number)
    click_transition_link_on_card_with_input_required(transition1)
    assert_disabled('complete_transition')
    add_comment_for_transition_to_complete_text_area(comment)
    assert_enabled('complete_transition')
    click_on_complete_transition
    assert_comment_present(comment)
  end

  def test_transition_with_comment_required_does_not_accept_blank_spaces
    mark_closed = 'Mark Closed'
    comment_blank = "    "
    comment_with_spaces = "             this has spaces      "
    transition1 = create_transition_for(@project, mark_closed, :set_properties => { BUG_STATUS => 'Closed' }, :require_comment => true)
    card1 = create_card!(:name => 'card1')
    open_card(@project, card1.number)
    click_transition_link_on_card_with_input_required(transition1)
    assert_disabled('complete_transition')
    add_comment_for_transition_to_complete_text_area(comment_blank)
    assert_disabled('complete_transition')
    add_comment_for_transition_to_complete_text_area(comment_with_spaces)
    assert_enabled('complete_transition')
    click_on_complete_transition
    assert_comment_not_present(comment_with_spaces)
    assert_comment_present("this has spaces")
  end

end
