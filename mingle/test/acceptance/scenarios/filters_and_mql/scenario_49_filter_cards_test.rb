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

# Tags: scenario, cards, card-list, filters, #2541, #2434, #2388
class Scenario49FilterCardsTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  CARD = 'Card'
  BUG = 'Bug'
  STORY = 'Story'
  NOTES = 'Notes'

  PRIORITY = 'Priority'
  STORY_STATUS = 'Story Status'
  BUG_STATUS = 'Bug Status'
  DESCRIPTION = 'Description_1'
  OWNER = 'Owner'

  ANY = '(any)'
  NOTSET = '(not set)'
  TYPE = 'Type'
  TAG_1 = 'story bug'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_team_member = users(:existingbob)
    @non_admin_user = users(:longbob)
    @admin = users(:admin)
    @team_member_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_49', :users => [@admin, @team_member_user, @non_admin_user])
    login_as_admin_user

    setup_property_definitions(PRIORITY => ['high','medium','low'], BUG_STATUS => ['new', 'open', 'closed'], STORY_STATUS => ['new', 'assigned', 'close'])
    setup_user_definition(OWNER)
    setup_card_type(@project, STORY, :properties => [STORY_STATUS, PRIORITY, OWNER])
    setup_card_type(@project, BUG, :properties => [BUG_STATUS, PRIORITY, OWNER])

    @card_1 = create_card!(:name => 'card without no property set', :card_type  => STORY, OWNER => @admin.id).tag_with(TAG_1)
    @card_2 = create_card!(:name => 'story1', :card_type  => STORY, PRIORITY  => 'high', STORY_STATUS  =>  'new', OWNER => @non_admin_user.id)
    @card_3 = create_card!(:name => 'story2', :card_type  => STORY, PRIORITY  => 'low', STORY_STATUS  =>  'assigned', OWNER => @team_member_user.id)
    @card_4 = create_card!(:name => 'bug1', :card_type  => BUG, PRIORITY  => 'high', BUG_STATUS  =>  'new', OWNER => @admin.id).tag_with(TAG_1)
    @card_5 = create_card!(:name => 'bug2', :card_type  => BUG, PRIORITY  => 'medium', BUG_STATUS  =>  'new', OWNER => @non_admin_user.id)
    @card_6 = create_card!(:name => 'bug3', :card_type  => BUG, PRIORITY  => 'low', BUG_STATUS  =>  'closed', OWNER => @team_member_user.id)
    navigate_to_card_list_for(@project)
  end

  def test_property_tooltip_when_filter_cards
    edit_property_definition_for(@project,OWNER,:description => "this property indicates who is the owner of the card.")

    navigate_to_card_list_for(@project)
    add_new_filter
    set_the_filter_property_option(1, OWNER)
    assert_property_tooltip_on_card_filter_panel(1,OWNER)

    navigate_to_grid_view_for(@project)
    add_new_filter
    set_the_filter_property_option(1, OWNER)
    assert_property_tooltip_on_card_filter_panel(1,OWNER)
  end

# bug 6612 scenario 1.
  def test_auto_enrolled_user_should_be_displayed_in_dropdown_of_filter
    grid_view = 'Grid View'
    set_the_filter_value_option(0, BUG)
    add_new_filter
    set_the_filter_property_and_value(1, :property => OWNER, :value => @team_member_user.name)
    @browser.click_and_wait('grid_view')

    group_columns_by(OWNER)
    saved_grid_view = create_card_list_view_for(@project, grid_view,:skip_clicking_all  => true)

    auto_enroll_all_users_as_full_users(@project)
    navigate_to_user_management_page
    click_new_user_link
    new_user = add_new_user("new_user@gmail.com", "password1.")

    navigate_to_card_list_for(@project)
    navigate_to_saved_view(grid_view)

    2.times do
    assert_filter_value_present_on(1, :property_values => [new_user.name], :search_term => new_user.name)
    add_lanes(@project, OWNER, [new_user.email])
    reload_current_page
    end
  end

  def test_changing_the_type_resets_the_whole_grid_view
    set_the_filter_value_option(0, STORY)
    @browser.click_and_wait "Link=Grid"
    group_columns_by(STORY_STATUS)
    add_lanes(@project, STORY_STATUS, ['new', 'assigned', 'close'])
    set_the_filter_value_option(0, BUG)
    assert_lane_not_present(STORY_STATUS, 'new')
    assert_lane_not_present(STORY_STATUS, 'assigned')
    assert_lane_not_present(STORY_STATUS, 'close')

    # 6612 scenario 2
    grid_view = 'Grid View'
    group_columns_by(OWNER)
    add_new_filter
    set_the_filter_property_and_value(1, :property => OWNER, :value => @admin.name)
    saved_grid_view = create_card_list_view_for(@project, grid_view,:skip_clicking_all  => true)

    navigate_to_user_management_page
    click_new_user_link
    new_user = add_new_user("new_user@gmail.com", "password1.")
    add_full_member_to_team_for(@project, new_user)

    navigate_to_card_list_for(@project)
    open_card_for_edit(@project, @card_4)
    assert_values_present_in_property_drop_down(OWNER, [new_user.name], "edit")
    navigate_to_saved_view(grid_view)
    open_card_for_edit(@project, @card_4)
    assert_values_present_in_property_drop_down(OWNER, [new_user.name], "edit")
  end

  def test_filter_type_always_exsists_and_set_to_any
    add_column_for(@project, ['Type'])
    assert_type_present_with_default_selected_as_any
    assert_filter_cannot_be_deleted(0)
    add_new_filter

    assert_filter_present_for(1)
    assert_filter_can_be_deleted(1)
  end

  def test_user_property_as_current_user_in_card_list_filter
    my_work_view = 'My Work'
    add_new_filter
    set_the_filter_property_and_value(1, :property => OWNER, :value => '(current user)')
    saved_view1 = create_card_list_view_for(@project, my_work_view)
    assert_card_favorites_link_present(my_work_view)
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(saved_view1)
    click_tab(my_work_view)
    assert_cards_present(@card_1, @card_4)
    login_as(@team_member_user.login)
    click_tab(my_work_view)
    assert_cards_present(@card_3, @card_6)
    login_as(@non_admin_user.login, 'longtest')
    click_tab(my_work_view)
    assert_cards_present(@card_2, @card_5)
  end

  def test_other_than_the_firstone_other_filters_can_be_deleted
    add_new_filter
    assert_filter_present_for(1)
    set_the_filter_property_option(1, PRIORITY)
    assert_filter_value_present_on(1, :property_values => ['high', 'medium', 'low'])
    assert_filter_can_be_deleted(1)
    add_new_filter
    assert_filter_present_for(2)
    assert_filter_can_be_deleted(2)
    assert_filter_value_present_on(2, :property_values => [])
  end

  def test_only_global_properties_displayed_for_filter_property_options_when_type_is_set_to_any
    add_new_filter
    assert_filter_property_present_on(1, :properties => [TYPE, PRIORITY])
    assert_filter_property_not_present_on(1, :properties => [BUG_STATUS, STORY_STATUS])
  end

  def test_when_type_is_set_then_only_relevent_properties_and_respective_values_display_in_added_filters
    set_the_filter_value_option(0, BUG)
    assert_cards_present(@card_4, @card_5, @card_6)
    add_new_filter
    assert_filter_present_for(1)
    assert_filter_property_present_on(1, :properties => [PRIORITY, BUG_STATUS])
    assert_filter_property_not_present_on(1, :properties => [STORY_STATUS])
    set_the_filter_property_option(1, BUG_STATUS)
    assert_filter_value_present_on(1, :property_values => ['new', 'open', 'closed', NOTSET, ANY])
    add_new_filter
    assert_filter_present_for(1)
    assert_filter_present_for(2)
    set_the_filter_value_option(0, STORY)
    assert_cards_present(@card_1, @card_2, @card_3)
    set_the_filter_property_option(2, STORY_STATUS)
    assert_filter_value_present_on(2, :property_values => ['new', 'assigned', 'close'])
  end

  def test_info_messages_for_various_invalid_filter_options
    invalid_prop = 'xyz'
    set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]&filters[]=[#{invalid_prop}][is][open]")
    assert_error_message("Filter is invalid. Property #{invalid_prop} does not exist.")

    set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]&filters[]=[#{BUG_STATUS}][is][open]")
    assert_error_message("Filter is invalid. Property #{BUG_STATUS} is not valid for card type #{STORY}.")

    set_filter_by_url(@project, "filters[]=[#{BUG_STATUS}][is][open]")
    assert_error_message("Filter is invalid. Please filter by appropriate card type in order to filter by property #{BUG_STATUS}.")

    #few more for property name duplication in message
    set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]&filters[]=[#{BUG_STATUS}][is][open]&filters[]=[#{BUG_STATUS}][is][closed]")
    assert_error_message("Filter is invalid. Property #{BUG_STATUS} is not valid for card type #{STORY}.")

    set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]&filters[]=[Type][is][#{BUG}]&filters[]=[#{BUG_STATUS}][is][open]")
    assert_error_message("Filter is invalid. Property #{BUG_STATUS} is not valid for card types #{STORY}, #{BUG}.")
  end

  def test_casing_insensitve_for_filters
    set_filter_by_url(@project, "filters[]=[type][Is][#{STORY}]&filters[]=[TYPE][is][#{BUG}]&filters[]=[PRIORITY][iS][HigH]&filters[]=[pRIORITY][IS][loW]")
    assert_cards_present(@card_2, @card_3, @card_4, @card_6)
  end

  def test_type_does_not_have_not_set_as_a_option_and_can_select_more_than_one_type
    assert_filter_value_not_present_on(0, :property_values => [NOTSET])
    add_new_filter
    assert_filter_present_for(1)
    assert_filter_property_present_on(1, :properties => [TYPE])
    set_the_filter_property_and_value(1, :property => TYPE, :value => STORY)
    set_the_filter_value_option(0, BUG)
    assert_cards_present(@card_1, @card_2, @card_3, @card_4, @card_5, @card_6)
    remove_a_filter_set(1)
    assert_cards_present(@card_4, @card_5, @card_6)
    assert_filter_not_present_for(1)
  end

  def test_filters_can_be_set_to_saved_views_and_can_be_added_as_tabs
    set_the_filter_value_option(0, STORY)
    filter_card_list_by(@project, STORY_STATUS => 'new', :keep_filters => [])
    create_card_list_view_for(@project, 'New Stories')
    assert_card_favorites_link_present('New Stories')
    assert_cards_present(@card_2)
    reset_view
    assert_cards_present(@card_1, @card_2, @card_3, @card_4, @card_5, @card_6)
    open_saved_view('New Stories')
    assert_cards_present(@card_2)
    assert_filter_value_present_on(0)
    assert_filter_value_present_on(1)
  end

  def test_and_or_support_for_types_in_filters
    assert_cards_present(@card_1, @card_2, @card_3, @card_4, @card_5, @card_6)
    set_the_filter_value_option(0, STORY)
    assert_cards_present(@card_1, @card_2, @card_3)
    add_new_filter
    set_the_filter_property_and_value(1, :property => TYPE, :value => BUG)
    assert_cards_present(@card_1, @card_2, @card_3, @card_4, @card_5, @card_6)
    add_new_filter
    set_the_filter_property_and_value(2, :property => PRIORITY, :value => 'low')
    assert_cards_present(@card_3, @card_6)
    remove_a_filter_set(2)
    assert_cards_present(@card_1, @card_2, @card_3, @card_4, @card_5, @card_6)
  end

  def test_or_support_for_properties_in_filter
    assert_cards_present(@card_1, @card_2, @card_3, @card_4, @card_5, @card_6)
    set_the_filter_value_option(0, STORY)
    assert_cards_present(@card_1, @card_2, @card_3)
    assert_cards_not_present(@card_4, @card_5, @card_6)
    add_new_filter
    set_the_filter_property_and_value(1, :property => PRIORITY, :value => 'low')
    assert_cards_present(@card_3)
    assert_cards_not_present(@card_1, @card_2, @card_4, @card_5, @card_6)

    add_new_filter
    set_the_filter_property_and_value(2, :property => PRIORITY, :value => 'high')
    assert_cards_present(@card_2, @card_3)
    assert_cards_not_present(@card_1, @card_4, @card_5, @card_6)
  end

  def test_and_support_with_multy_or_proeprties
    set_the_filter_value_option(0, STORY)
    add_new_filter
    set_the_filter_property_and_value(1, :property => PRIORITY, :value => 'low')
    add_new_filter
    set_the_filter_property_and_value(2, :property => PRIORITY, :value => 'high')
    add_new_filter
    set_the_filter_property_and_value(3, :property => STORY_STATUS, :value => 'new')
    assert_cards_present(@card_2)
    assert_cards_not_present(@card_1, @card_3, @card_4, @card_5, @card_6)

    add_new_filter
    set_the_filter_property_and_value(4, :property => STORY_STATUS, :value => 'assigned')
    assert_cards_present(@card_2, @card_3)
    assert_cards_not_present(@card_1, @card_4, @card_5, @card_6)
  end

  def test_deleting_filters_get_appropriate_filter_set
    set_the_filter_value_option(0, STORY)
    add_new_filter
    set_the_filter_property_and_value(1, :property => PRIORITY, :value => 'low')
    add_new_filter
    set_the_filter_property_and_value(2, :property => PRIORITY, :value => 'high')
    add_new_filter
    set_the_filter_property_and_value(3, :property => STORY_STATUS, :value => 'new')
    add_new_filter
    set_the_filter_property_and_value(4, :property => STORY_STATUS, :value => 'assigned')
    assert_cards_present(@card_2, @card_3)
    assert_cards_not_present(@card_1, @card_4, @card_5, @card_6)

    remove_a_filter_set(2)
    assert_cards_present(@card_3)
    assert_cards_not_present(@card_1, @card_2, @card_4, @card_5, @card_6)
  end

  #bug 2541
  def test_first_type_filter_should_not_be_able_to_be_removed
    add_new_filter
    set_the_filter_property_option(1, TYPE)
    remove_a_filter_set(1)
    assert_type_present_with_default_selected_as_any
  end

  #2434
  def test_filter_preperty_list_is_ordered_and_type_always_being_first
    set_the_filter_value_option(0, STORY)
    add_new_filter
    assert_filter_properties_options_ordered(1, TYPE, OWNER, PRIORITY, STORY_STATUS)
  end

  #2388
  def test_in_filter_property_option_does_not_hold_select_dot_dot_dot_as_a_property_option
    set_the_filter_value_option(0, STORY)
    add_new_filter
    assert_filter_property_not_present_on(1, :properties => ['select...'])
    set_the_filter_property_and_value(1, :property => PRIORITY, :value => 'high')
    assert_filter_property_not_present_on(1, :properties => ['select...'])
  end

  #bug test #2680
  def test_changing_the_type_on_a_grid_view_resets_all_the_lanes_and_group_by_which_are_irrelevent_to_the_current_filter
    navigate_to_grid_view_for(@project)
    set_the_filter_value_option(0, STORY)
    group_columns_by(STORY_STATUS)
    tab_story_with_status = create_card_list_view_for(@project, 'story with status')
    set_the_filter_value_option(0, BUG)

    group_columns_by(BUG_STATUS)
    tab_bug_with_status = create_card_list_view_for(@project, 'bug with status')
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(tab_story_with_status, tab_bug_with_status)
    click_tab('story with status')
    set_the_filter_value_option(0, BUG)
    assert_lane_not_present(STORY_STATUS, 'new')
    assert_lane_not_present(STORY_STATUS, 'assigned')
    assert_lane_not_present(STORY_STATUS, 'close')
    assert_grouped_by_not_set
  end

end
