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

# Tags: scenario, transitions, property
class Scenario104UserInputOptionalTransitionsTest < ActiveSupport::TestCase
  
  fixtures :users, :login_access   
  TYPE_BUG = 'Bug'
  TYPE_STORY = 'Story'
  TYPE_CARD = 'Card'
  
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
  
  NO_CHANGE = '(no change)'
  NOT_SET = '(not set)'
  ANY = '(any)'
  USER_INPUT_OPTIONAL = '(user input - optional)'
  USER_INPUT_REQUIRED = '(user input - required)'
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)   
    @browser = selenium_session
    @admin_user = users(:admin)
    @non_team_member = users(:existingbob)
    @non_admin_user = users(:longbob)
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_104', :users => [@admin_user, @non_admin_user], :admins => [@project_admin_user])
    setup_property_definitions(STATUS => [NEW, OPEN, IN_PROGRESS, DONE, CLOSE], PRIORITY => [HIGH, LOW], BUG_STATUS => ['Open', 'Fixed', 'Verified', 'Closed'])
    @created_date = setup_date_property_definition(CREATED)
    @address_text = setup_text_property_definition(ADDRESS)
    @owner = setup_user_definition(OWNER)
    login_as_proj_admin_user
  end
  
  # admin related test
  def test_transition_sets_properties_should_have_user_input_optional_field_in_drop_down
    all_properties = [STATUS, PRIORITY, BUG_STATUS, CREATED, ADDRESS, OWNER]
    open_transition_create_page(@project)
    set_card_type_on_transitions_page(TYPE_CARD)
    all_properties.each do |property|
      set_sets_properties(@project, property => USER_INPUT_OPTIONAL)
      assert_sets_property(property => USER_INPUT_OPTIONAL)
    end
  end
  
  def test_should_be_able_to_create_transition_with_only_user_input_optional_set
    new_transition = create_transition_for(@project, 'new transition',:type => TYPE_CARD, :set_properties => {STATUS => USER_INPUT_OPTIONAL})
    assert_notice_message("Transition #{new_transition.name} was successfully created")
    assert_transition_present_for(@project, new_transition)
  end
  
  def test_hidden_locked_and_transition_only_properties_can_set_user_input_optional_on_transition_creation_page
    hide_property(@project, CREATED)
    lock_property(@project, STATUS)
    make_property_transition_only_for(@project, BUG_STATUS)
    new_transition = create_transition_for(@project, 'new transition',:type => TYPE_CARD, :set_properties => {STATUS => USER_INPUT_OPTIONAL, CREATED => USER_INPUT_OPTIONAL, BUG_STATUS => USER_INPUT_OPTIONAL})
    assert_notice_message("Transition #{new_transition.name} was successfully created")
    assert_transition_present_for(@project, new_transition)
  end
  
  def test_property_set_as_user_input_optional_in_transition_will_get_deleted_when_property_is_deleted
    new_transition = create_transition_for(@project, 'new transition',:type => TYPE_CARD, :set_properties => {STATUS => USER_INPUT_OPTIONAL})
    navigate_to_property_management_page_for(@project)
    delete_property_for(@project, STATUS, :stop_at_confirmation => true)
    assert_info_box_light_message("Used by 1 Transition: #{new_transition.name}. This will be deleted.")
    click_continue_to_delete_link
    navigate_to_transition_management_for(@project)
    assert_transition_not_present_for(@project, new_transition)
  end
  
  def test_bulk_transition_panel_cannot_be_activted_because_user_propery_not_set
    new_transition = create_transition_for(@project, 'new transition',:type => TYPE_CARD, :set_properties => {STATUS => USER_INPUT_OPTIONAL})
    assert_info_message("Transition #{new_transition.name} cannot be activated using the bulk transitions panel because some properties are set to (user input - required) or (user input - optional).", :escape => true)
    assert_bulk_transition_message_on_transition_list_for(new_transition, "This transition cannot be activated using the bulk transitions panel because at least one property is set to (user input - optional).")
    new_transition2 = create_transition_for(@project, 'new transition2',:type => TYPE_CARD, :set_properties => {STATUS => USER_INPUT_REQUIRED})
    assert_bulk_transition_message_on_transition_list_for(new_transition2, "This transition cannot be activated using the bulk transitions panel because at least one property is set to (user input - required).")
    new_transition3 = create_transition_for(@project, 'new transition3',:type => TYPE_CARD, :set_properties => {STATUS => USER_INPUT_REQUIRED, CREATED => USER_INPUT_OPTIONAL})
    assert_bulk_transition_message_on_transition_list_for(new_transition3, "This transition cannot be activated using the bulk transitions panel because properties are set to (user input - required) and (user input - optional).")
  end
  
  # transition execution tests
  def test_user_input_optional_transition_pops_light_box_and_should_be_able_to_complete_transiton_without_setting_it
    transition1 = create_transition_for(@project, 'new transition',:type => TYPE_CARD, :set_properties => {STATUS => USER_INPUT_OPTIONAL})
    card1 = create_card!(:name => 'Card 1', :card_type => TYPE_CARD)
    open_card(@project, card1.number)
    assert_transition_present_on_card(transition1.name)
    click_transition_link_on_card_with_input_required(transition1)
    assert_transition_complete_button_enabled
    set_value_to_property_in_lightbox_editor_on_transition_execute(STATUS => DONE)
    click_on_complete_transition
    assert_property_set_on_card_show(STATUS, DONE)
  end
  
  def test_transition_with_user_input_optional_and_required_properties_the_lightbox_should_behave_as_expected
    transition2 = create_transition_for(@project, 'transition2',:type => TYPE_CARD, :set_properties => {STATUS => USER_INPUT_OPTIONAL, PRIORITY  => USER_INPUT_REQUIRED})
    card1 = create_card!(:name  => 'Card 1', :card_type => TYPE_CARD)
    open_card(@project,card1.number)
    assert_transition_present_on_card(transition2.name)
    click_transition_link_on_card_with_input_required(transition2)
    assert_transition_complete_button_disabled
    set_value_to_property_in_lightbox_editor_on_transition_execute(STATUS => DONE)
    assert_transition_complete_button_disabled
    set_value_to_property_in_lightbox_editor_on_transition_execute(PRIORITY => HIGH)
    assert_transition_complete_button_enabled
    click_on_complete_transition
    assert_property_set_on_card_show(STATUS, DONE)
    assert_property_set_on_card_show(PRIORITY, HIGH)
  end
   
  def test_transition_with_user_input_optional_and_reqiured_comments_the_lightbox_should_behave_as_expected
     transition2 = create_transition_for(@project, 'transition2',:type => TYPE_CARD,:require_comment => true, :set_properties => {STATUS => USER_INPUT_OPTIONAL})
     card1 = create_card!(:name  => 'Card 1', :card_type => TYPE_CARD)
     open_card(@project,card1.number)
     assert_transition_present_on_card(transition2.name)
     click_transition_link_on_card_with_input_required(transition2)
     assert_transition_complete_button_disabled
     set_value_to_property_in_lightbox_editor_on_transition_execute(STATUS => DONE)
     assert_transition_complete_button_disabled
     add_comment_for_transition_to_complete_text_area('comment from here')
     assert_transition_complete_button_enabled
     click_on_complete_transition
     assert_property_set_on_card_show(STATUS, DONE)
     assert_comment_present('comment from here')
  end
  
  def test_user_cannot_add_new_value_for_a_locked_property_in_light_box_window_when_excute_a_transition_for_non_admin_user
    lock_property(@project, STATUS)
    new_transition = create_transition_for(@project, 'new transition',:type => TYPE_CARD, :set_properties => {STATUS => USER_INPUT_OPTIONAL})
    assert_notice_message("Transition #{new_transition.name} was successfully created")
    card1 = create_card!(:name  => 'Card 1', :card_type => TYPE_CARD)
    login_as(@non_admin_user.login, 'longtest')
    open_card(@project,card1.number)
    click_transition_link_on_card_with_input_required(new_transition)
    assert_inline_enum_value_add_for_light_box_not_present_for(@project, STATUS)
  end
  
  #bug 4524
  def test_user_can_cancel_light_box_window_with_comment_requried_after_invoking_bulk_transition
    new_transition = create_transition_for(@project, 'FOO',:type => TYPE_CARD, :require_comment => true,:set_properties => {STATUS => NEW})
    card1 = create_card!(:name  => 'Card 1', :card_type => TYPE_CARD)
    navigate_to_card_list_by_clicking(@project)
    check_cards_in_list_view(card1)
    execute_bulk_transition_action_that_requires_input(new_transition)
    assert_transition_light_box_present
    click_cancel_on_transiton_light_box_window
    assert_transition_light_box_not_present
  end

  #bug 1022, 1268
  def test_user_should_be_able_to_use_transitions_with_confirmation_in_popup_on_non_grid_view_page
    comment = 'Completed FOO!'
    new_transition = create_transition_for(@project, 'FOO',:type => TYPE_CARD, :require_comment => true,:set_properties => {STATUS => OPEN})
    card1 = create_card!(:name  => 'Card 1', :card_type => TYPE_CARD)
    search_card_with_number(card1.number)
    click_transition_link_on_card_in_grid_view(new_transition)
    assert_transition_light_box_present
    add_comment_for_transition_to_complete_and_complete_the_transaction(comment)
    assert_transition_light_box_not_present
    assert_property_set_on_card_show(STATUS, OPEN)
    @browser.wait_for_text_present(comment)
  end

end
