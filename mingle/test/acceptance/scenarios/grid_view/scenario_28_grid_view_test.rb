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

# Tags: scenario, gridview
class Scenario28GridViewTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  STATUS = 'Status'
  NEW = 'new'
  OPEN = 'open'
  SIZE = 'size'
  SIZE1 = 'size1'
  ITERATION_SIZE = 'iteration size'
  AVERAGE = 'avg'

  STORY = 'story'
  DEFECT = 'defect'
  ITERATION = 'iteration'

  PRIORITY = 'priority'
  URGENT = 'URGENT'
  HIGH = 'High'
  TYPE = 'Type'

  RELEASE = 'Release'
  CARD = 'Card'


  PROPERTY_WITHOUT_VALUES = 'property_without_values'
  PASSWORD_FOR_LONGBOB_USER = 'longtest'

  MANAGED_TEXT_PROPERTY = 'managed text list'


  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @mingle_admin = users(:admin)
    @project_admin_user = users(:proj_admin)
    @team_member = users(:project_member)
    @project = create_project(:prefix => 'scenario_28', :users => [@team_member], :admins => [@project_admin_user])
    setup_property_definitions(STATUS => [NEW, OPEN], PRIORITY => [URGENT, HIGH], :property_without_values => [])
    login_as_proj_admin_user
    @card = create_card!(:name => 'first card')
  end

  # 12676 - Change config to limit the cards on grid view size to small size only for testing.
  def test_grid_view_checks_500_limit_on_filter_and_add_remove_column_changes
    with_grid_cards_size_limit(6) do
      card_type = @project.card_types.find_by_name(CARD)
      story_type = setup_card_type(@project, STORY)
      create_cards(@project, 2, :card_type => card_type)
      create_cards(@project, 3, :card_type => story_type)

      navigate_to_grid_view_for(@project)
      add_card_via_quick_add("Special Name")

      assert_text_present("7 cards requested (6 maximum)")
      last_card = @project.cards.find_by_name("Special Name")
      assert_cards_not_present_in_grid_view(@card, last_card)

      group_columns_by(TYPE)
      assert_text_present("7 cards requested (6 maximum)")
      add_new_filter
      set_the_filter_property_and_value(0, :property => 'Type', :value => STORY)
      assert_text_not_present("7 cards requested (6 maximum)")
      add_new_filter
      set_the_filter_property_and_value(1, :property => 'Type', :value => CARD)
      assert_text_present("7 cards requested (6 maximum)")
    end
  end

  def test_grid_view_with_tree_selected_checks_500_limit_on_tree_filter
    with_grid_cards_size_limit(6) do
      card_type = @project.card_types.find_by_name(CARD)
      story_type = setup_card_type(@project, STORY, :properties => [STATUS])
      story_cards = create_cards(@project, 6, :card_type => story_type, :card_name => "Story", :tag => "Beavor")

      story_tree = setup_tree(@project, "Story Tree", :types => [card_type, story_type], :relationship_names => ["Card - Story"])
      add_card_to_tree(story_tree, @card)
      add_card_to_tree(story_tree, story_cards, @card)

      navigate_to_grid_view_for(@project, :tree_name => "Story Tree")
      assert_text_present("7 cards requested (6 maximum)")

      click_exclude_card_type_checkbox(STORY)
      assert_cards_present_in_grid_view(@card)

      story_card = @project.cards.find_by_name("Story 3")
      story_card.update_properties(STATUS => NEW)
      story_card.save!
      click_exclude_card_type_checkbox(STORY)

      set_tree_filter_for(story_type, 0, :property => STATUS, :value => NEW)
      assert_cards_present_in_grid_view(story_card)
    end
  end

# Story 12578
  def test_card_defaults_on_quick_add
    @team_member.update_attributes(:name => "beavor")
    @project_admin_user.update_attributes(:name => "panda")
    status = @project.all_property_definitions.find_by_name(STATUS)
    owner = setup_user_definition("Owner")
    start_date = setup_date_property_definition("Start_Date")
    end_date = setup_date_property_definition("End_Date")
    end_date.update_attributes(:hidden => true)
    task_type = setup_card_type(@project, "Task", :properties => [STATUS, "Owner", "Start_Date"])
    story_type = setup_card_type(@project, "Story", :properties => [STATUS, "Owner","End_Date"])


    set_card_default("Task", {:status => "jiajun", :Start_Date => "12 Dec 2011", :owner => "#{@team_member.id}"})
    set_card_default("Story", {:status => "beavor", :owner => "#{@project_admin_user.id}", :End_Date => "15 Jun 2012"})

    navigate_to_grid_view_for(@project)

    open_add_card_via_quick_add
    set_quick_add_card_type_to("Task")
    assert_properties_set_on_quick_add_card(:status => "jiajun", :owner => @team_member.name, :Start_Date => "12 Dec 2011")
    set_quick_add_card_type_to("Story")
    assert_properties_set_on_quick_add_card(:status => "beavor", :owner => @project_admin_user.name)
    assert_properties_not_present_on_quick_add_card(PRIORITY, "Start_Date", "End_Date")
    cancel_quick_add_card_creation

    end_date.update_attributes(:hidden => false)
    open_add_card_via_quick_add
    set_quick_add_card_type_to("Story")
    assert_properties_set_on_quick_add_card(:status => "beavor", :owner => @project_admin_user.name, :End_Date => "15 Jun 2012")

    type_card_name("Testing Card 111")
    set_managed_text_prop_on_quick_add_card(STATUS, NEW)
    submit_quick_add_card

    open_card_via_clicking_link_on_mini_card(@project.cards.find_by_name('Testing Card 111'))
    assert_properties_set_on_card_show(:status => NEW, :owner => @project_admin_user.name, :End_Date => "15 Jun 2012" )
  end

  def test_card_displayed_in_correct_cell_after_saved
    task_type = setup_card_type(@project, "Task", :properties => [PRIORITY])
    set_card_default("Task", {PRIORITY => URGENT})
    navigate_to_grid_view_for(@project)
    set_the_filter_value_option(0, "Task")
    group_columns_by(TYPE)
    group_rows_by(PRIORITY)

    open_add_card_via_quick_add
    set_quick_add_card_type_to("Task")
    type_card_name("Task Card with a unique Name")
    submit_quick_add_card

    newly_created_card = @project.cards.find_by_name("Task Card with a unique Name")
    assert_card_in_lane_and_row(newly_created_card, 'Task', URGENT)

    open_add_card_via_quick_add
    set_quick_add_card_type_to("Card")
    type_card_name("Testing Task Card")
    submit_quick_add_card
    assert_notice_message"was successfully created, but is not shown because it does not match the current filter."
  end

  #bug 4753
  def test_color_legends_should_be_in_sync_with_the_color_and_sort_by_dorp_down
    size1 = setup_numeric_property_definition(SIZE1, ['1', '3', '5'])
    setup_card_type(@project, STORY, :properties => [SIZE1, PRIORITY, STATUS])
    setup_card_type(@project, DEFECT, :properties => [SIZE1, PRIORITY])
    create_card!(:name =>'story_card1', :card_type => STORY, SIZE1 => 1,  PRIORITY => HIGH, STATUS => NEW)
    create_card!(:name =>'story_card2', :card_type => STORY, SIZE1 => 3,  PRIORITY => HIGH, STATUS => NEW)
    create_card!(:name => 'defect_card1', :card_type => DEFECT, SIZE1 => 3, PRIORITY => URGENT)
    navigate_to_grid_view_for(@project)
    assert_group_lane_number(4)
    set_the_filter_value_option(0, STORY)
    group_columns_by(SIZE1)
    color_by(STATUS)
    assert_color_legend_displayed
    assert_color_legend_contains_type(NEW)
    assert_color_legend_contains_type(OPEN)
    set_the_filter_value_option(0, DEFECT)
    assert_color_legend_not_displayed
  end

  #bug 4709
  def test_changing_properties_and_types_by_drag_and_drop_on_a_filtered_grid_view_should_show_correct_cards
    setup_numeric_property_definition(SIZE1, ['1', '3', '5'])
    setup_card_type(@project, STORY, :properties => [SIZE1, PRIORITY, STATUS])
    story_card1 = create_card!(:name =>'story_card1', :card_type => STORY, SIZE1 => 1,  PRIORITY => HIGH, STATUS => NEW)
    create_card!(:name =>'story_card2', :card_type => STORY, SIZE1 => 1,  PRIORITY => HIGH, STATUS => NEW)
    create_card!(:name =>'story_card3', :card_type => STORY, SIZE1 => 1,  PRIORITY => HIGH, STATUS => NEW)
    create_card!(:name =>'story_card4', :card_type => STORY, SIZE1 => 3,  PRIORITY => HIGH, STATUS => NEW)
    navigate_to_grid_view_for(@project)
    set_the_filter_value_option(0, STORY)
    add_new_filter
    set_the_filter_property_and_value(1, :property => SIZE1, :value => 1)
    group_columns_by(SIZE1)
    assert_property_present_in_color_by(SIZE1)
    assert_lane_not_present(SIZE1, '5')
    add_lanes(@project, SIZE1, ['5'])
    drag_and_drop_card_from_lane(story_card1.html_id, SIZE1, '5')

    assert_card_not_in_lane(SIZE1, '5', story_card1.number)
    assert_card_not_in_lane(SIZE1, '1', story_card1.number)
    @browser.assert_text_present("card ##{story_card1.number} property was updated, but is not shown because it does not match the current filter.")

    set_the_filter_value_option(0, "(any)")
    remove_a_filter_set(1)
    assert_group_lane_number(1, :lane => [SIZE1, '5'])
    assert_group_lane_number(2, :lane => [SIZE1, '1'])
    group_columns_by(TYPE)
    assert_group_lane_number(1, :lane => [TYPE, CARD])
    drag_and_drop_card_from_lane(story_card1.html_id, TYPE, CARD)
    assert_card_in_lane(TYPE, CARD, story_card1.number)
    assert_equal CARD, @project.cards.find_by_number(story_card1.number).card_type.name
  end

  def test_drag_and_drop_columns_update_property_value
    setup_card_type(@project, STORY, :properties => [STATUS])
    story_card1 = create_card!(:name =>'story_card1', :card_type => STORY,STATUS => NEW)
    create_card!(:name =>'story_card2', :card_type => STORY,STATUS => OPEN)
    navigate_to_grid_view_for(@project)
    set_the_filter_value_option(0, STORY)
    group_columns_by(STATUS)
    assert_order_of_lanes_in_grid_view(NEW,OPEN)
    assert_draggable_lanes_present
    drag_and_drop_lanes(NEW, OPEN)
    assert_order_of_lanes_in_grid_view(OPEN,NEW)
    open_edit_enumeration_values_list_for(@project, STATUS)
    assert_enum_values_in_order(@project.find_enumeration_value(STATUS, OPEN), @project.find_enumeration_value(STATUS, NEW))

    # check reorder lanes only accessible for admin user
    login_as(@team_member.login)
    navigate_to_grid_view_for(@project)
    group_columns_by(STATUS)
    assert_order_of_lanes_in_grid_view('(not set)', OPEN, NEW)
    assert_draggable_lanes_not_present
  end

  def test_add_lane_dropdown_reflects_order_of_columns_in_grid_view
    setup_card_type(@project, STORY, :properties => [STATUS])
    story_card1 = create_card!(:name =>'story_card1', :card_type => STORY,STATUS => NEW)
    create_card!(:name =>'story_card2', :card_type => STORY,STATUS => OPEN)
    navigate_to_grid_view_for(@project)
    set_the_filter_value_option(0, STORY)
    group_columns_by(STATUS)
    open_add_lane_dropdown
    assert_order_of_add_lane_dropdown('(not set)', NEW, OPEN)
    assert_draggable_lanes_present
    drag_and_drop_lanes(NEW, OPEN)
    open_add_lane_dropdown
    assert_order_of_add_lane_dropdown('(not set)', OPEN, NEW)
  end

  def test_hide_columns_from_grid_view
    navigate_to_grid_view_for(@project)
    group_columns_by(STATUS)
    add_lanes(@project, STATUS, [NEW, OPEN])
    assert_lane_present(STATUS, NEW)
    hide_grid_dimension(NEW)
    assert_lane_not_present(STATUS, NEW)
    assert_reset_to_tab_default_link_present

    setup_card_type(@project, STORY)
    group_columns_by(TYPE)
    add_lanes(@project, TYPE, [CARD, STORY], :type => true)
    assert_lane_present(TYPE, CARD)
    assert_lane_present(TYPE, STORY)
    hide_grid_dimension(STORY)
  end

  # this includes bug ZnY bug #
  def test_renaming_value_updates_filters
    new_value="new&old"
    navigate_to_grid_view_for(@project)
    add_new_filter
    set_the_filter_property_and_value(1, :property => STATUS, :value => NEW)
    group_columns_by(STATUS)
    add_lanes(@project, STATUS, [NEW, OPEN])
    drag_and_drop_quick_add_card_to("", NEW)
    submit_card_name_and_type("Testing Card")

    rename_lane(NEW, new_value)
    assert_filter_set_for(1, STATUS => new_value)
    assert_order_of_lanes_in_grid_view('(not set)', new_value, OPEN)
    hide_grid_dimension(OPEN)
    assert_order_of_lanes_in_grid_view('(not set)', new_value)
  end

  def test_cross_site_scripting_not_possible_in_edit_value
    script_in_value = "<SCRIPT> alert('XSS'); </SCRIPT>"
    navigate_to_grid_view_for(@project)
    add_new_filter
    set_the_filter_property_and_value(1, :property => STATUS, :value => NEW)
    group_columns_by(STATUS)
    add_lanes(@project, STATUS, [NEW])
    rename_lane(NEW, script_in_value)
    assert_order_of_lanes_in_grid_view('(not set)', script_in_value)
  end

  def test_group_by_property_with_no_values_should_allow_add_new_values
    status_with_no_value = 'status with no value'
    setup_property_definitions(status_with_no_value => [])
    navigate_to_grid_view_for(@project)
    group_columns_by(status_with_no_value)
    assert_lane_present(status_with_no_value, '')
    assert_add_column_present
  end

  def test_read_only_team_member_should_be_able_to_add_hide_columns
    light_user = create_user!(:name => 'light', :login => 'light', :password => MINGLE_TEST_DEFAULT_PASSWORD, :password_confirmation => MINGLE_TEST_DEFAULT_PASSWORD)
    project_with_readonly_user = create_project(:prefix => 'scenario_28_readonly', :admins => [@project_admin_user], :read_only_users => [light_user])
    project_with_readonly_user.activate
    setup_property_definitions(STATUS => [NEW, OPEN])
    login_as(light_user.login)
    navigate_to_grid_view_for(project_with_readonly_user)
    group_columns_by(STATUS)
    add_lanes(project_with_readonly_user, STATUS, [NEW, OPEN])
    assert_order_of_lanes_in_grid_view('(not set)',NEW, OPEN)
    assert_lane_present(STATUS, OPEN)
    hide_grid_dimension(OPEN)
    assert_lane_not_present(STATUS, OPEN)
    assert_lane_present(STATUS,NEW)
    assert_draggable_lanes_not_present
  end

  def test_rename_column_and_drag_card_in_renamed_should_have_updated_property_value
    new_property = 'very new'
    navigate_to_grid_view_for(@project)
    group_columns_by(STATUS)
    add_lanes(@project, STATUS, [NEW, OPEN])
    rename_lane(NEW, new_property)
    drag_and_drop_quick_add_card_to('',new_property)
    assert_properties_set_on_quick_add_card(STATUS => new_property)
    type_card_name("Another Card")
    submit_quick_add_card
    card = @project.cards.find_by_name('Another Card')
    assert_lane_present(STATUS, new_property)
    open_card(@project, card)
    assert_properties_set_on_card_show(STATUS => new_property)
  end

  def test_applying_transition_on_grid_view_switches_the_card_to_appropriate_lane_lane_count_get_updated
    card_open = create_card!(:name => 'card for admin', :status => OPEN)
    navigate_to_transition_management_for(@project)
    transition = create_transition_for(@project, 'Open this', :set_properties => {:status => OPEN})
    filter_type_story_priority_high_grid = "filters[]=[Type][is][Card]&group_by=#{STATUS}&color_by=Type"
    set_filter_by_url(@project, filter_type_story_priority_high_grid, 'grid')
    click_on_transition_for_card_in_grid_view(@card, transition)
    assert_group_lane_number(2, :lane => [STATUS, OPEN])
  end

  def test_opening_url_with_lane_which_does_not_exist_shows_no_lanes
    @decoy_project_member = users(:longbob)
    @decoy_project = create_project(:prefix => 'decoy_project', :users => [@decoy_project_member], :admins => [@project_admin_user])
    user_property_name = 'Owner'
    create_property_definition_for(@project, user_property_name, :type => 'user')
    @project.reload.activate
    card_with_user_property_set = create_card!(:name => 'card for admin', :owner => @project_admin_user.id)
    grid_view_url = "/projects/#{@project.identifier}/cards/grid?group_by=#{user_property_name}&lanes=#{@decoy_project_member.id}"
    @browser.open(grid_view_url)
    assert_grouped_by(user_property_name)
    assert_lane_not_present(user_property_name, @decoy_project_member.id)
    assert_info_message("There are no cards that match the current filter - Reset filter")


    value_that_does_not_exist_for_status = 'low'
    grid_view_url = "/projects/#{@project.identifier}/cards/grid?group_by=#{STATUS}&lanes=#{value_that_does_not_exist_for_status}"
    @browser.open(grid_view_url)
    assert_info_message("There are no cards that match the current filter - Reset filter")
  end

  def test_lanes_in_saved_view_survive_property_and_value_renames
    view_name = 'high_cards'
    new_property_name = 'importance'
    new_name = 'whoa!'
    new_value = 'big time'
    navigate_to_grid_view_for(@project)
    group_columns_by(PRIORITY)
    add_lanes(@project, PRIORITY, [HIGH])
    create_card_list_view_for(@project, view_name)
    reset_all_filters_return_to_all_tab
    newly_named_property_defintion = edit_property_definition_for(@project, PRIORITY, :new_property_name => new_property_name)
    open_saved_view(view_name)
    assert_grouped_by(new_property_name)
    assert_lane_present(new_property_name, HIGH)
    rename_lane(HIGH, new_name)
    create_new_lane(@project, new_property_name, new_value)
    assert_grouped_by(new_property_name)
    assert_lane_present(new_property_name, new_name)
  end

  def test_deleted_property_not_present_in_group_by_or_color_by_options
    navigate_to_property_management_page_for(@project)
    delete_property_for(@project, STATUS)
    navigate_to_grid_view_for(@project)
    assert_property_not_present_in_group_columns_by(STATUS)
    assert_property_not_present_in_color_by(STATUS)
    assert_property_not_present_on_card_list_filter(STATUS)
  end

  #bug 2499
  def test_url_eliminate_unwanted_keywords_when_switching_from_grid_to_list_view
    urgent_priority_card = create_card!(:name => 'card for admin', PRIORITY => URGENT)
    filter_type_story_priority_high_grid = "filters[]=[Type][is][Card]&filters[]=[#{PRIORITY}][is][#{URGENT}]&group_by=#{PRIORITY}&color_by=Type"
    set_filter_by_url(@project, filter_type_story_priority_high_grid, 'grid')
    tab_type_story_priority_high_grid = create_card_list_view_for(@project, 'card=urgent')
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(tab_type_story_priority_high_grid)
    click_tab('card=urgent')
    switch_to_list_view
    remove_a_filter_set(1)
    assert_reset_to_tab_default_link_present
    set_the_filter_value_option(0, '(any)')
    assert_reset_to_tab_default_link_present
    click_tab('All')
    assert_reset_to_tab_default_link_not_present
  end

  # bug 3277 & # bug 2960
  def test_card_popup_with_special_chars_render_on_grid_view_and_on_filtering_grid_view_refresh_with_no_popup
    text_with_hyphen = 'foo — bar'
    html_entity_for_hyphen = '&#8212;'
    text_with_html_enity = text_with_hyphen.gsub(/-/, html_entity_for_hyphen)
    card = create_card!(:name => 'for testing', :description => text_with_hyphen, STATUS => NEW)
    navigate_to_grid_view_for(@project)
    click_on_card_in_grid_view(card.number)
    assert_popup_present_for_card(card)
    assert_card_description_in_card_pop_up(text_with_hyphen)
    assert_not_card_description_in_card_pop_up(html_entity_for_hyphen)
    close_popup
    filter_card_list_by(@project, STATUS => NEW)
    assert_popup_not_present_for_card(card)
  end


  # Bug 3362.
  def test_should_average_lane_headings_should_ignore_card_types_that_do_not_have_the_property
    size = setup_numeric_property_definition(SIZE, [0, 1, 2])
    iteration_size = setup_numeric_property_definition(ITERATION_SIZE, [1, 2, 3])
    type_iteration = setup_card_type(@project, ITERATION, :properties => [SIZE, ITERATION_SIZE])
    type_story = setup_card_type(@project, STORY, :properties => [SIZE])
    create_card!(:name => 'iteration1', :card_type => type_iteration, SIZE => 2, ITERATION_SIZE => 3)
    create_card!(:name => 'iteration2', :card_type => type_iteration, SIZE => 2, ITERATION_SIZE => 2)
    create_card!(:name => 'iteration3',:card_type => type_iteration)
    create_card!(:name => 'story1', :card_type => type_story, SIZE => 2)
    create_card!(:name => 'story2', :card_type => type_story, SIZE => 2)

    navigate_to_grid_view_for(@project, :aggregate_type => AVERAGE, :aggregate_property => ITERATION_SIZE)
    assert_group_lane_number(2.5)
  end



  # bug 4080
  def test_deleting_property_value_that_is_displayed_lane_in_tabbed_saved_grid_view_informs_user_that_view_will_be_deleted
    view_name = 'foobar'
    new_card = create_card!(:name => 'card for admin', STATUS => NEW)
    navigate_to_grid_view_for(@project)
    group_columns_by(PRIORITY)
    add_lanes(@project, PRIORITY, [URGENT, HIGH])
    view = create_card_list_view_for(@project, view_name)
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(view)
    delete_enumeration_value_for(@project, PRIORITY, URGENT, :requires_confirmation => true, :stop_at_confirmation => true)
    assert_info_box_light_message("The following 1 card list view will be deleted: #{view_name}")
    click_continue_to_delete_link
    assert_tab_not_present(view_name)
    navigate_to_favorites_management_page_for(@project)
    assert_tabs_not_present_on_management_page(view)
    assert_favorites_not_present_on_management_page(view)
  end

  #bug 4077
  def test_team_member_or_admin_cannot_move_card_in_grid_view_when_group_by_is_transition_only
    status_grid_name = 'status grid'
    make_property_transition_only_for(@project, STATUS)
    card_new = create_card!(:name  => 'status new card', STATUS  => NEW)
    card_open = create_card!(:name  => 'status open card', STATUS  => OPEN)
    navigate_to_grid_view_for(@project, :group_by => STATUS)
    create_card_list_view_for(@project, status_grid_name)
    login_as(@team_member.login)
    open_project (@project)
    open_favorites_for(@project, status_grid_name)
    drag_and_drop_card_from_lane(card_open.html_id, STATUS, NEW)
    assert_transition_only_error_message_on_grid("Sorry, you cannot drag card to any lane because group by property is transition only and there are no transitions for this property.")

    login_as_admin_user
    open_project (@project)
    navigate_to_grid_view_for(@project, :group_by => STATUS)
    drag_and_drop_card_from_lane(card_open.html_id, STATUS, NEW)
    assert_transition_only_error_message_on_grid("Sorry, you cannot drag card to any lane because group by property is transition only and there are no transitions for this property.")

  end


  # bug 6616
  def test_card_type_should_be_updated_after_grop_by_type_in_grid_view_then_drag_and_drop_to_other_lane
    setup_card_type(@project, RELEASE)
    setup_card_type(@project, ITERATION)
    release_card = create_card!(:name =>'release', :card_type => RELEASE)
    iteration_card = create_card!(:name =>'iteration', :card_type => ITERATION)

    navigate_to_grid_view_for(@project)
    group_columns_by(TYPE)
    drag_and_drop_card_from_lane(release_card.html_id, TYPE, ITERATION)

    open_card(@project, release_card.number)
    assert_card_type_set_on_card_show(ITERATION)
  end

  #bug 7788
  def test_grouping_by_a_property_that_has_a_value_with_a_question_mark_should_not_result_in_500_error
    card_type = Project.find_by_identifier(@project.identifier).card_types.find_by_name(CARD) unless CARD.respond_to?(:name)
    managed_text_property = create_managed_text_list_property(MANAGED_TEXT_PROPERTY, ['open', 'close', 'new?'])
    add_properties_for_card_type(card_type, [managed_text_property])
    navigate_to_grid_view_for(@project)
    group_columns_by(MANAGED_TEXT_PROPERTY)
    add_lanes(@project, MANAGED_TEXT_PROPERTY, ['open', 'close', 'new?'])
    assert_cards_present_in_grid_view(@card)
  end

  #bug 8960
  def test_transition_on_grid_view_should_be_able_to_change_card_when_ranking_is_on
    #selenium drag and drop are highly unstable on ie
    does_not_work_on_ie do
      type_card = @project.card_types.find_by_name("Card")

      mixed_values = create_managed_text_list_property("mixed_values",  ["aa","bb","cc"])
      type_card.add_property_definition(mixed_values)
      navigate_to_transition_management_for(@project)
      click_create_new_transtion_workflow_link
      card_1 = create_card!(:name => 'card_1')
      card_2 = create_card!(:name => 'card_2')
      card_3 = create_card!(:name => 'card_3')
      card_4 = create_card!(:name => 'card_4')
      select_card_type_for_transtion_work_flow("Card")
      select_property_for_transtion_work_flow("mixed_values")
      click_the_generate_transition_workflow_link
      make_property_transition_only_for(@project, "mixed_values")

      navigate_to_grid_view_for(@project)
      group_columns_by("mixed_values")
      add_lanes(@project, 'mixed_values', ["aa","bb","cc"])

      drag_and_drop_card_from_lane(card_1.html_id, "mixed_values", 'aa')
      drag_and_drop_card_from_lane(card_2.html_id, "mixed_values", 'aa')
      # drag_and_drop_card_from_lane(card_3.html_id, "mixed_values", 'aa')
      # drag_and_drop_card_from_lane(card_4.html_id, "mixed_values", 'aa')
      drag_and_drop_card_to(card_3, card_1)
      drag_and_drop_card_to(card_4, card_2)
      click_all_tab
      assert_card_in_lane("mixed_values", "aa", card_1.number)
      assert_card_in_lane("mixed_values", "aa", card_2.number)
      assert_card_in_lane("mixed_values", "aa", card_3.number)
      assert_card_in_lane("mixed_values", "aa", card_4.number)
    end
  end

  #Story 8306 - Make card number on a popup as a link to card
  def test_should_have_card_number_as_link_on_card_popup_in_normal_grid_view
    navigate_to_grid_view_for(@project)
    click_on_card_in_grid_view(@card.number)
    @browser.assert_element_present(css_locator("a[href*='/cards/#{@card.number}']"))
    @browser.click_and_wait(css_locator("a[href*='/cards/#{@card.number}']"))
    assert_card_location_in_card_show(@project, @card)
    assert_card_name_in_show(@card.name)
  end

  def test_should_see_card_number_as_link_on_card_popup_in_maxmized_grid_view
    navigate_to_grid_view_for(@project)
    maximize_current_view
    click_on_card_in_grid_view(@card.number)
    @browser.assert_element_present(css_locator("a[href*='/cards/#{@card.number}']"))
    @browser.click_and_wait(css_locator("a[href*='/cards/#{@card.number}']"))
    assert_card_location_in_card_show(@project, @card)
    assert_card_name_in_show(@card.name)
  end

  def test_card_link_on_mini_card
    navigate_to_grid_view_for(@project)
    assert_link_present_on_mini_card(@card)
    assert_tooltip_for_mini_card_link_present
    open_card_via_clicking_link_on_mini_card(@card)
    assert_card_name_in_show(@card.name)
  end



  def test_quick_add_card_should_be_visible_on_maxmized_grid_view
    navigate_to_grid_view_for(@project)
    maximize_current_view
    assert_quick_add_card_is_visible
  end

  # bug 12464
  def test_group_by_type_should_be_preserved_for_a_team_favorite_after_renaming_the_card_type
    setup_card_type(@project, 'task', :properties => [STATUS])
    setup_card_type(@project, 'story', :properties => [STATUS])
    setup_card_type(@project, 'no_prop')
    navigate_to_grid_view_for(@project)
    set_mql_filter_for("type = story OR type = task")
    group_columns_by('Type')
    group_rows_by(STATUS)
    create_card_list_view_for(@project, 'favorito')
    edit_card_type_for_project(@project, 'story', :new_card_type_name => 'new story')
    open_favorites_for(@project, 'favorito')
    @browser.assert_element_text(group_by_rows_drop_link_id, STATUS)
  end

  def test_add_card_via_quick_add_on_grid_view
    as_project_member do
      navigate_to_grid_view_for(@project)
      open_add_card_via_quick_add
      type_card_name(name)
      cancel_quick_add_card_creation
      new_card_number = add_card_via_quick_add("new_card")
      @browser.assert_visible("card_#{new_card_number}")
    end
  end

  def test_grid_settings_panel_visibility_should_be_saved_as_user_preference
    as_project_member do
      navigate_to_grid_view_for(@project)
      hide_the_grid_settings
      @browser.assert_not_visible(group_by_columns_drop_link_id)
      navigate_to_card_list_for(@project)
      navigate_to_grid_view_for(@project)
      @browser.assert_not_visible(group_by_columns_drop_link_id)
      show_the_grid_settings
      @browser.assert_visible(group_by_columns_drop_link_id)
      end
  end

  private

  def open_saved_view(saved_view_name)
    @browser.open("/projects/#{@project.identifier}/cards?view=#{saved_view_name}")
  end
end
