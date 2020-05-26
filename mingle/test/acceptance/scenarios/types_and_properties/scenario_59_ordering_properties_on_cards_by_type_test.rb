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

# Tags: scenario, properties

class Scenario59OrderingPropertiesOnCardsByTypeTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  PRIORITY = 'priority'
  STATUS = 'status'
  SIZE = 'size'
  ITERATION = 'iteration'
  OWNER = 'Zowner'

  STORY = 'Story'
  DEFECT = 'Defect'
  TASK = 'Task'
  CARD = 'Card'

  NOTSET = '(not set)'
  ANY = '(any)'
  TYPE = 'Type'
  NEW = 'new'
  OPEN = 'open'
  LOW = 'low'
  does_not_work_on_windows
  
  # Important : this test should be run on 1024,768 or higher... to all test pass... and do not resize window while test running
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_admin_user = users(:longbob)
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_59', :users => [@non_admin_user], :admins => [@project_admin_user])
    @browser.get_eval("window.resizeTo(1024,768)")
    setup_property_definitions(PRIORITY => ['high', LOW], SIZE => [1, 2, 4], STATUS => [NEW,  'close', OPEN], ITERATION => [1,2,3,4], OWNER  => ['a', 'b', 'c'])
    @story_type = setup_card_type(@project, STORY, :properties => [PRIORITY, SIZE, ITERATION, OWNER])
    @defect_type = setup_card_type(@project, DEFECT, :properties => [PRIORITY, STATUS, OWNER])
    @task_type = setup_card_type(@project, TASK, :properties => [PRIORITY, SIZE, ITERATION, STATUS, OWNER])
    login_as_proj_admin_user
    @card_1 = create_card!(:name => 'sample card_1', :card_type => TASK, STATUS => 'close')
    @card_2 = create_card!(:name => 'card_2', :card_type => TASK, STATUS => NEW)
    @card_3 = create_card!(:name => 'sample_3', :card_type => TASK, STATUS => 'close')
    @card_4 = create_card!(:name => 'card_4', :card_type => TASK, STATUS => OPEN)
    navigate_to_card_type_management_for(@project)
  end

  # tests for admin management page
  def test_should_be_able_to_re_arange_card_types_in_card_type_management_page
    drag_and_dorp_card_type_downward(@project, DEFECT, STORY)
    assert_card_types_ordered_in_card_type_management_page(@project, CARD, STORY, DEFECT, TASK)
    drag_and_dorp_card_type_upward(@project, TASK, DEFECT)
    assert_card_types_ordered_in_card_type_management_page(@project, CARD, STORY, TASK, DEFECT)
  end

  def test_reordering_properties_on_card_type_edit_page
    open_edit_card_type_page(@project, TASK)
    drag_and_drop_properties_downward(@project, PRIORITY, SIZE)
    drag_and_drop_properties_upward(@project, STATUS, ITERATION)
    save_card_type
    assert_notice_message("Card Type #{TASK} was successfully updated")
    open_edit_card_type_page(@project, TASK)
    assert_properties_order_in_card_type_edit_page(@project, SIZE, PRIORITY, STATUS, ITERATION)
  end
  
  # bug 7084
  def test_reordering_property_on_card_type_when_aggregate_existed_for_all_descendants 
    tree = setup_tree(@project, 'Tree', :types => [@story_type, @defect_type, @task_type],:relationship_names => ["story", "defect"]) 
    aggregate = setup_aggregate_property_definition('count', AggregateType::COUNT, nil, tree.id, @story_type.id, AggregateScope::ALL_DESCENDANTS)
    open_edit_card_type_page(@project, TASK)
    drag_and_drop_properties_downward(@project, PRIORITY, SIZE)
    drag_and_drop_properties_upward(@project, STATUS, ITERATION)
    save_card_type
    assert_notice_message("Card Type #{TASK} was successfully updated")
  end

  def test_only_admin_user_can_modify_order_of_properties_and_card_type
    as_user(@non_admin_user.login, 'longtest') do
      navigate_to_card_type_management_for(@project)
      assert_drag_and_drop_not_possible
    end
    
    as_user('proj_admin') do
      navigate_to_card_type_management_for(@project)
      assert_drag_and_drop_is_possible
    end
  end

  def test_renaming_properties_should_not_affect_the_order_of_property
    open_edit_card_type_page(@project, TASK)
    drag_and_drop_properties_downward(@project, PRIORITY, SIZE)
    drag_and_drop_properties_upward(@project, STATUS, ITERATION)
    assert_properties_order_in_card_type_edit_page(@project, SIZE, PRIORITY, STATUS, ITERATION)
    save_card_type
    assert_notice_message("Card Type #{TASK} was successfully updated")
    
    navigate_to_property_management_page_for(@project)
    edit_property_definition_for(@project, PRIORITY, :new_property_name => 'a priority')
    
    navigate_to_card_type_management_for(@project)
    open_edit_card_type_page(@project, TASK)
    assert_properties_order_in_card_type_edit_page(@project, SIZE, 'a priority', STATUS, ITERATION)
  end

  def test_unchecking_property_for_card_type_should_remove_dragdrop_funcitonality_to_that_property
    open_edit_card_type_page(@project, TASK)
    drag_and_drop_properties_downward(@project, PRIORITY, STATUS)
    drag_and_drop_properties_upward(@project, STATUS, ITERATION)
    assert_properties_order_in_card_type_edit_page(@project, SIZE, STATUS, ITERATION, PRIORITY)
    clear_all_selected_properties_for_card_type
    check_the_properties_required_for_card_type(@project, [SIZE, STATUS])
    assert_properties_not_draggable(@project, ITERATION, PRIORITY)
    assert_properties_draggable(@project, SIZE, STATUS)
  end

  def test_order_of_sets_type_specific_properties_in_transition_show_page
    open_edit_card_type_page(@project, TASK)
    drag_and_drop_properties_downward(@project, PRIORITY, STATUS)
    drag_and_drop_properties_upward(@project, STATUS, ITERATION)
    assert_properties_order_in_card_type_edit_page(@project, SIZE, STATUS, ITERATION, PRIORITY)
    save_card_type

    navigate_to_transition_management_for(@project)
    click_create_new_transition_link
    set_card_type_on_transitions_page(TASK)
    assert_order_of_properties_sets_on_transition_edit(@project, SIZE, STATUS, ITERATION, PRIORITY, OWNER)
    assert_order_of_properties_required_on_transition_edit(@project, SIZE, STATUS, ITERATION, PRIORITY, OWNER)
    set_sets_properties(@project, SIZE => NOTSET)
    set_sets_properties(@project, STATUS => NOTSET)
    set_sets_properties(@project, ITERATION => NOTSET)
    set_sets_properties(@project, PRIORITY => NOTSET)
    set_sets_properties(@project, OWNER => NOTSET)
    type_transition_name('test')
    click_create_transition
    assert_order_of_sets_properties_on_transition_management_show_page( [[SIZE, NOTSET], [STATUS, NOTSET], [ITERATION, NOTSET], [PRIORITY, NOTSET], [OWNER, NOTSET]])
  end
  
  # bug 2747
  def test_order_of_required_type_specific_properties_in_transition_show_page
    open_edit_card_type_page(@project, TASK)
    drag_and_drop_properties_downward(@project, PRIORITY, STATUS)
    drag_and_drop_properties_upward(@project, STATUS, ITERATION)
    assert_properties_order_in_card_type_edit_page(@project, SIZE, STATUS, ITERATION, PRIORITY)
    save_card_type
    
    navigate_to_transition_management_for(@project)
    click_create_new_transition_link
    set_card_type_on_transitions_page(TASK)
    assert_order_of_properties_sets_on_transition_edit(@project, SIZE, STATUS, ITERATION, PRIORITY, OWNER)
    assert_order_of_properties_required_on_transition_edit(@project, SIZE, STATUS, ITERATION, PRIORITY, OWNER)
    set_required_properties(@project, SIZE => NOTSET)
    set_required_properties(@project, STATUS => NOTSET)
    set_required_properties(@project, ITERATION => NOTSET)
    set_required_properties(@project, PRIORITY => NOTSET)
    set_sets_properties(@project, OWNER => NOTSET)
    type_transition_name('test')
    click_create_transition
    assert_order_of_required_properties_on_transition_management_show_page( [[TYPE, TASK], [SIZE, NOTSET], [STATUS, NOTSET], [ITERATION, NOTSET], [PRIORITY, NOTSET]])
  end

  # card and card list, and grid view, card defaults specific
  def test_order_of_properties_are_set_as_the_order_of_card_type_spectific_properties_on_card_show_and_card_edit
    open_edit_card_type_page(@project, TASK)
    drag_and_drop_properties_downward(@project, PRIORITY, SIZE)
    drag_and_drop_properties_upward(@project, STATUS, ITERATION)
    save_card_type
    assert_notice_message("Card Type #{TASK} was successfully updated")
    open_edit_card_type_page(@project, TASK)
    assert_properties_order_in_card_type_edit_page(@project, SIZE, PRIORITY, STATUS, ITERATION)
    open_card(@project, @card_1.number)
    assert_order_of_properties_on_card_show(@project, SIZE, PRIORITY, STATUS, ITERATION)
    click_edit_link_on_card
    assert_order_of_properties_on_card_edit(@project, SIZE, PRIORITY, STATUS, ITERATION)
  end

  def test_order_of_properties_are_maintained_even_when_card_type_changed_on_card_show_or_card_edit
    open_edit_card_type_page(@project, TASK)
    drag_and_drop_properties_downward(@project, PRIORITY, STATUS)
    drag_and_drop_properties_upward(@project, STATUS, ITERATION)
    assert_properties_order_in_card_type_edit_page(@project, SIZE, STATUS, ITERATION, PRIORITY)
    save_card_type
    assert_notice_message("Card Type #{TASK} was successfully updated")
    
    open_edit_card_type_page(@project, STORY)
    drag_and_drop_properties_downward(@project, ITERATION, SIZE)
    drag_and_drop_properties_upward(@project, SIZE, PRIORITY)
    assert_properties_order_in_card_type_edit_page(@project, SIZE, PRIORITY, ITERATION)
    save_card_type
    assert_notice_message("Card Type #{STORY} was successfully updated")
    
    open_card(@project, @card_1.number)
    assert_order_of_properties_on_card_show(@project, SIZE, STATUS, ITERATION, PRIORITY)
    set_card_type_on_card_show(STORY)
    assert_order_of_properties_on_card_show(@project, SIZE, PRIORITY, ITERATION)
    
    click_edit_link_on_card
    assert_order_of_properties_on_card_edit(@project, SIZE, PRIORITY, ITERATION)
  end

  def test_order_of_the_type_specific_properties_in_bulk_edit_property
    open_edit_card_type_page(@project, TASK)
    drag_and_drop_properties_downward(@project, PRIORITY, STATUS)
    drag_and_drop_properties_upward(@project, STATUS, ITERATION)
    assert_properties_order_in_card_type_edit_page(@project, SIZE, STATUS, ITERATION, PRIORITY)
    save_card_type
    assert_notice_message("Card Type #{TASK} was successfully updated")
    click_all_tab
    set_the_filter_value_option(0, TASK)
    select_all
    click_edit_properties_button
    assert_properties_order_in_bulk_edit(@project, SIZE, STATUS, ITERATION, PRIORITY)
  end

  def test_card_list_add_remove_column_drop_down_is_ordered_alphabetically_type_being_first
    open_edit_card_type_page(@project, TASK)
    drag_and_drop_properties_downward(@project, PRIORITY, STATUS)
    drag_and_drop_properties_upward(@project, STATUS, ITERATION)
    assert_properties_order_in_card_type_edit_page(@project, SIZE, STATUS, ITERATION, PRIORITY)
    save_card_type
    assert_notice_message("Card Type #{TASK} was successfully updated")
    click_all_tab
    set_the_filter_value_option(0, TASK)
    assert_properties_ordered_in_add_remove_columns_in_card_list(@project, ITERATION, PRIORITY, SIZE, STATUS, OWNER)
  end

  def test_card_defaults_hold_the_properties_ordered_as_set_in_type_management_page
    open_edit_card_type_page(@project, TASK)
    drag_and_drop_properties_downward(@project, PRIORITY, STATUS)
    drag_and_drop_properties_upward(@project, STATUS, ITERATION)
    assert_properties_order_in_card_type_edit_page(@project, SIZE, STATUS, ITERATION, PRIORITY)
    save_card_type
    assert_notice_message("Card Type #{TASK} was successfully updated")
    open_edit_defaults_page_for(@project, TASK)
    assert_order_of_properties_on_card_defaults(@project, SIZE, STATUS, ITERATION, PRIORITY)
  end

  def test_order_of_the_of_properties_in_grid_group_by_and_color_by_option_are_alphabetical
    open_edit_card_type_page(@project, TASK)
    drag_and_drop_properties_downward(@project, PRIORITY, STATUS)
    drag_and_drop_properties_upward(@project, STATUS, ITERATION)
    assert_properties_order_in_card_type_edit_page(@project, SIZE, STATUS, ITERATION, PRIORITY)
    save_card_type
    assert_notice_message("Card Type #{TASK} was successfully updated")
    navigate_to_grid_view_for(@project)
    assert_properties_in_group_by_are_ordered(PRIORITY, OWNER)
    assert_properties_in_color_by_are_ordered(PRIORITY, OWNER)
    set_the_filter_value_option(0, TASK)
    assert_properties_in_group_by_are_ordered(ITERATION, PRIORITY, SIZE, STATUS, OWNER)
    assert_properties_in_color_by_are_ordered(ITERATION, PRIORITY, SIZE, STATUS, OWNER)
  end

  # def test_order_of_the_type_specific_properties_in_grid_card_popup
  #   @card_5 = create_card!(:name => 'card_5', :card_type => TASK, PRIORITY => 'high', ITERATION => '1', SIZE => '2' ,STATUS => OPEN)
  #   open_edit_card_type_page(@project, TASK)
  #   drag_and_drop_properties_downward(@project, PRIORITY, STATUS)
  #   drag_and_drop_properties_upward(@project, STATUS, ITERATION)
  #   assert_properties_order_in_card_type_edit_page(@project, SIZE, STATUS, ITERATION, PRIORITY)
  #   save_card_type
  #   assert_notice_message("Card Type #{TASK} was successfully updated")
  #   navigate_to_grid_view_for(@project)
  #   assert_properties_order_in_grid_view_card_popup(@card_5.number, [TYPE, TASK],  [SIZE, '2'], [STATUS, OPEN], [ITERATION, '1'], [PRIORITY, 'high'])
  # end

  # Filters and history related tests
  def test_properties_are_ordered_alphabetically_in_filter_drop_down
    open_edit_card_type_page(@project, TASK)
    drag_and_drop_properties_downward(@project, PRIORITY, STATUS)
    drag_and_drop_properties_upward(@project, STATUS, ITERATION)
    assert_properties_order_in_card_type_edit_page(@project, SIZE, STATUS, ITERATION, PRIORITY)
    save_card_type
    assert_notice_message("Card Type #{TASK} was successfully updated")
    click_all_tab
    set_the_filter_value_option(0, TASK)
    add_new_filter
    assert_properties_ordered_in_filter_property_dropdown(1, TYPE, ITERATION, PRIORITY, SIZE, STATUS, OWNER)
  end

  def test_property_values_are_ordered_as_per_set_order_in_property_managementpage_for_filters_drop_down
    navigate_to_property_management_page_for(@project)
    open_edit_enumeration_values_list_for(@project, STATUS)
    drag_and_dorp_enumeration_value_downward_for(@project, STATUS, 'close', OPEN)
    assert_enumerated_values_order_in_propertys_edit_page(@project, STATUS, NEW, OPEN, 'close')
    click_all_tab
    set_the_filter_value_option(0, TASK)
    add_new_filter
    set_the_filter_property_option(1, STATUS)
    assert_enum_values_are_ordered_according_to_the_order_set_in_management_page(1, ANY, NOTSET, NEW, OPEN, 'close')
  end

  def test_card_types_are_ordered_in_filter_values_drop_link
    drag_and_dorp_card_type_downward(@project, DEFECT, STORY)
    assert_card_types_ordered_in_card_type_management_page(@project, CARD, STORY, DEFECT, TASK)
    drag_and_dorp_card_type_upward(@project, TASK, DEFECT)
    assert_card_types_ordered_in_card_type_management_page(@project, CARD, STORY, TASK, DEFECT)
    click_all_tab
    assert_enum_values_are_ordered_according_to_the_order_set_in_management_page(0, ANY, CARD, STORY, TASK, DEFECT)
  end

  def test_order_of_properties_in_history_are_alphabatical_irrespective_of_card_type_specific_order
    open_edit_card_type_page(@project, DEFECT)
    drag_and_drop_properties_downward(@project, PRIORITY, STATUS)
    assert_properties_order_in_card_type_edit_page(@project, STATUS, PRIORITY, OWNER)
    save_card_type
    assert_notice_message("Card Type #{DEFECT} was successfully updated")
    click_tab('History')

    assert_order_of_involved_properties_on_history_filter(@project, ITERATION, PRIORITY, SIZE, STATUS, OWNER)
    select_card_type_in_filter_involved(DEFECT)
    assert_order_of_involved_properties_on_history_filter(@project, PRIORITY, STATUS, OWNER)

    assert_order_of_acquired_properties_on_history_filter(@project, ITERATION, PRIORITY, SIZE, STATUS, OWNER)
    select_card_type_in_filter_acquired(DEFECT)
    assert_order_of_acquired_properties_on_history_filter(@project, PRIORITY, STATUS, OWNER)
  end

  #bug2728
  def test_greater_than_less_than_filter_operators_filter_cards_according_to_the_property_values_order
    navigate_to_property_management_page_for(@project)
    open_edit_enumeration_values_list_for(@project, STATUS)
    drag_and_dorp_enumeration_value_downward_for(@project, STATUS, 'close', OPEN)
    assert_enumerated_values_order_in_propertys_edit_page(@project, STATUS, NEW, OPEN, 'close')
    click_all_tab
    set_the_filter_value_option(0, TASK)
    add_new_filter
    set_the_filter_property_option(1, STATUS)
    select_is_greater_than(1)
    set_the_filter_value_option(1, NEW)
    assert_cards_present(@card_1, @card_3, @card_4)
    assert_cards_not_present(@card_2)

    select_is_less_than(1)
    set_the_filter_value_option(1, 'close')
    assert_cards_present(@card_2, @card_4)
    assert_cards_not_present(@card_1, @card_3)
  end

  #bug1650
  def test_order_of_lanes_in_grid_view_as_per_the_order_set_by_project_admin
    click_all_tab
    navigate_to_grid_view_for(@project)
    set_the_filter_value_option(0, TASK)
    group_columns_by(STATUS)
    assert_order_of_lanes_in_grid_view(NEW, 'close', OPEN)
  end
  
  # bug 2796
  def test_reordering_properties_for_card_type_that_has_hidden_properties_does_not_remove_property_from_type
    transition_setting_hidden_property = create_transition_for(@project, 'setting hidden', :type => TASK, :required_properties => {STATUS => NEW}, :set_properties => {STATUS => OPEN, PRIORITY => LOW})
    card = create_card!(:name => 'plain card', :type => TASK, STATUS => NEW)
    hide_property(@project, PRIORITY)
    open_card(@project, card.number)
    assert_transition_present_on_card(transition_setting_hidden_property)

    open_edit_card_type_page(@project, TASK)
    drag_and_drop_properties_downward(@project, OWNER, SIZE)
    drag_and_drop_properties_upward(@project, ITERATION, STATUS)
    save_card_type

    navigate_to_transition_management_for(@project)
    assert_transition_present_for(@project, transition_setting_hidden_property)

    open_property_for_edit(@project, PRIORITY)
    assert_card_types_checked_or_unchecked_in_create_new_property_page(@project, :card_types_checked => [TASK, STORY, DEFECT])

    open_edit_card_type_page(@project, TASK)
    assert_properties_selected_for_card_type(@project, STATUS, PRIORITY, SIZE, ITERATION, OWNER)

    open_card(@project, card.number)
    click_transition_link_on_card(transition_setting_hidden_property)
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {PRIORITY => LOW})
    assert_history_for(:card, card.number).version(2).shows(:changed => STATUS, :from => NEW, :to => OPEN)
   end
   
  # bug 2742
  def test_assert_order_of_properties_on_transition_management_page
    navigate_to_transition_management_for(@project)
    click_create_new_transition_link
    assert_order_of_properties_sets_on_transition_edit(@project, PRIORITY, OWNER)
    assert_order_of_properties_required_on_transition_edit(@project, PRIORITY, OWNER)
  end

end
