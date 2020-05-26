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

#Tags: properties
class Scenario156UseArrowKeyOnDropDownTest < ActiveSupport::TestCase
  
  CARD = 'Card'
  TYPE = 'Type'
  STORY = 'story'
  ITERATION = 'Iteration'
 
  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin = users(:proj_admin)
    @project_member = users(:project_member)
    @project = create_project(:prefix => 'scenario_156', :admins => [@project_admin], :users => [@project_member])
    @status = setup_property_definitions(STATUS => [NEW, OPEN,CLOSED])
    @size = create_managed_number_list_property(SIZE,[1,11,121])
    @start_date = create_date_property(START_DATE)
    @release = create_card_type_property(RELEASE)
    @revision = create_allow_any_text_property(RIVISION)
    @estimate = create_allow_any_number_property(ESTIMATE)
    @owner = create_team_property(OWNER)
    login_as_admin_user
    @card = create_card!(:name => 'new card', :card_type => CARD)
  end

  def test_use_arrow_keys_to_set_filter_on_history_filter  
    navigate_to_history_for(@project)
    open_card_type_involved_value_list
    can_use_up_or_down_arrow_key_to_move_highlight_on_card_type_involved_drop_down([ANY,NOT_SET,CARD])

    press_enter_on_card_type_involved_drop_down_on_history_filter
    card_type_is_set_in_the_first_condition(ANY)

    open_value_list_for_property_in_second_condition(STATUS)
    can_use_up_or_down_arrow_key_to_move_highlight_on_value_drop_down_for_property_in_second_condition(STATUS,[ANY,ANY_CHANGE,NOT_SET,NEW,OPEN,CLOSED])

    press_enter_on_value_drop_down_for_property_in_second_condition(STATUS)
    value_is_set_for_property_in_the_second_filter(STATUS,ANY)
  end

  def test_use_arrow_keys_to_set_filter_on_cards_filter_drop_down__add_cards_to_tree_on_tree_view
    there_is_a_ris_tree_with_cards
    open_card_explorer_for(@project, @planning_tree)
    add_new_filter_for_explorer

    open_filter_property_list(1)
    can_use_up_or_down_arrow_key_to_move_highlight_on_cards_filter_properties_drop_down(1,[TYPE,OWNER,RELEASE,SIZE,START_DATE,STATUS])

    set_the_filter_property_and_value(1,:property => START_DATE,:operator => "is",:value => ANY)
    open_filter_operator_list(1)
    option_should_be_highlighted_on_cards_filter_operators_drop_down(1,'is')
    can_use_up_or_down_arrow_key_to_move_highlight_on_cards_filter_operators_drop_down(1,["is","is not","is before","is after"])

    open_filter_value_list(1)
    can_use_up_or_down_arrow_key_to_move_highlight_on_cards_filter_values_drop_down(1,[ANY,NOT_SET,TODAY])

    press_down_arrow_key_on_cards_filter_properties_drop_down(1)
    press_enter_on_cards_filter_properties_drop_down(1)
    assert_selected_value_for_the_filter(1,NOT_SET)
  end

  def test_use_arrow_keys_to_move_highlight_on_tree_filter_drop_down
    Outline(<<-Examples) do | go_to_card_view_for_tree                                    |
      |{ navigate_to_tree_view_for(@project, @planning_tree.name,[])}|
      |{ navigate_to_hierarchy_view_for(@project,@planning_tree)}|
      |{navigate_to_grid_view_for(@project,:tree_name => @planning_tree.name)}|
      |{navigate_to_list_view_for(@project,@planning_tree)}|
      Examples

      there_is_a_ris_tree_with_cards
      go_to_card_view_for_tree.happened
      add_new_tree_filter_for(@release_type)
      open_tree_filter_property_list(@release_type, 0)
      can_use_up_or_down_arrow_key_to_move_highlight_on_tree_filter_properties_drop_down_for_card_type(0,@release_type,
      ["planning-release",OWNER,RELEASE,SIZE,START_DATE,STATUS])

      add_new_tree_filter_for(@iteration_type)
      set_the_tree_filter_property_option(@iteration_type,0,SIZE)
      open_tree_filter_operator_list(@iteration_type, 0)
      can_use_up_or_down_arrow_key_to_move_highlight_on_tree_filter_operators_drop_down_for_card_type(0,@iteration_type,["is","is not","is less than","is greater than"])

      add_new_tree_filter_for(@story_type)
      set_the_tree_filter_property_option(@story_type,0,SIZE)
      open_tree_filter_value_list(@story_type, 0)
      can_use_up_or_down_arrow_key_to_move_highlight_on_tree_filter_values_drop_down_for_card_type(0,@story_type,[ANY,NOT_SET,1,11,121])
    end
  end

  def test_press_enter_should_select_the_highlighted_value_on_cards_filter_drop_down_on_card_list_and_grid_view
    Outline(<<-Examples) do | go_to_card_view                      |
      |{ navigate_to_card_list_for(@project)}|
      |{ navigate_to_grid_view_for(@project)}|

      Examples

      there_are_some_date_plv_available_for_property
      go_to_card_view.happened
      add_new_filter
      set_the_filter_property_and_value(1,:property => START_DATE,:operator => "is after",:value => "(#{DATE_PLV_1})")

      open_filter_operator_list(1)
      option_should_be_highlighted_on_cards_filter_operators_drop_down(1,"is after")
      press_up_arrow_key_on_cards_filter_operators_drop_down(1)
      press_enter_on_cards_filter_operators_drop_down(1)
      assert_filter_operator_set_to(1,"is before")

      open_filter_value_list(1)
      option_should_be_highlighted_on_cards_filter_values_drop_down(1,"(#{DATE_PLV_1})")
      press_down_arrow_key_on_cards_filter_values_drop_down(1)
      press_enter_on_cards_filter_values_drop_down(1)
      assert_selected_value_for_the_filter(1,"(#{DATE_PLV_2})")

      open_filter_property_list(1)
      option_should_be_highlighted_on_cards_filter_properties_drop_down(1,START_DATE)
      press_down_arrow_key_on_cards_filter_properties_drop_down(1)
      press_enter_on_cards_filter_properties_drop_down(1)
      assert_selected_property_for_the_filter(1,STATUS)
    end
  end

  def test_use_arrow_keys_to_move_highlight_on_cards_filter_drop_down_on_card_list_view
    Outline(<<-Examples) do | go_to_card_view                      |
      |{ navigate_to_card_list_for(@project)}|
      |{ navigate_to_grid_view_for(@project)}|
      Examples

      go_to_card_view.happened
      add_new_filter
      open_filter_property_list(1)
      can_use_up_or_down_arrow_key_to_move_highlight_on_cards_filter_properties_drop_down(1,[TYPE,OWNER,RELEASE,SIZE,START_DATE,STATUS])

      set_the_filter_property_option(1,SIZE)
      open_filter_operator_list(1)
      can_use_up_or_down_arrow_key_to_move_highlight_on_cards_filter_operators_drop_down(1,["is","is not","is less than","is greater than"])

      open_filter_value_list(1)
      can_use_up_or_down_arrow_key_to_move_highlight_on_cards_filter_values_drop_down(1,[ANY,NOT_SET,1,11,121])
    end
  end

  def test_use_arrow_keys_to_set_value_for_managed_number_property_on_transition_edit_page
    navigate_to_transition_management_for(@project)
    click_create_new_transition_link
    click_property_on_transition_edit_page(SETS,SIZE)
    option_should_be_hightlighted_on_drop_down_on_transiton_edit(SETS,SIZE,NO_CHANGE)
    can_use_up_or_down_arrow_key_to_move_highlight_on_property_drop_down_on_transition_edit_page(SETS,SIZE,
    [NO_CHANGE,NOT_SET,OPTIONAL_USER_INPUT,REQUIRE_USER_INPUT,1,11,121])
  end


  def test_use_arrow_keys_to_set_value_for_managed_number_property_on_card_default
    open_edit_defaults_page_for(@project, CARD)
    click_property_on_card_edit(SIZE)
    option_should_be_hightlighted_on_drop_down(SIZE,NOT_SET,'edit')

    type_keyword_to_search_value_for_property_on_card_edit(SIZE,'1')
    can_use_up_or_down_arrow_key_to_move_highlight_on_property_drop_down(SIZE,[1,11,121],'edit')
  end

  def test_press_enter_should_select_the_highlighted_value_on_card_default
    open_to_edit_a_card_whose_status_is(OWNER)
    click_property_on_card_edit(OWNER)
    press_down_arrow_key_on_property_drop_down(OWNER,'edit')
    press_enter_to_select_the_highlighted_value(OWNER,'edit')
    value_should_be_assign_to_property_on_card_edit(OWNER,CURRENT_USER)

    click_property_on_card_edit(OWNER)
    press_up_arrow_key_on_property_drop_down(OWNER,'edit')
    press_enter_to_select_the_highlighted_value(OWNER,'edit')
    value_should_be_assign_to_property_on_card_edit(OWNER,NOT_SET)
  end

  def test_use_arrow_keys_to_set_value_for_managed_text_property_on_card_edit
    open_to_edit_a_card_whose_status_is(OPEN)
    click_property_on_card_edit(STATUS)
    option_should_be_hightlighted_on_drop_down(STATUS,OPEN,'edit')

    type_keyword_to_search_value_for_property_on_card_edit(STATUS,'o')
    can_use_up_or_down_arrow_key_to_move_highlight_on_property_drop_down(STATUS,[NOT_SET,OPEN,CLOSED],'edit')
  end

  def test_press_enter_should_select_the_highlighted_value_on_card_edit
    open_to_edit_a_card_whose_status_is(OPEN)
    click_property_on_card_edit(STATUS)
    press_down_arrow_key_on_property_drop_down(STATUS,'edit')
    press_enter_to_select_the_highlighted_value(STATUS,'edit')
    value_should_be_assign_to_property_on_card_edit(STATUS,CLOSED)

    click_property_on_card_edit(STATUS)
    press_up_arrow_key_on_property_drop_down(STATUS,'edit')
    press_enter_to_select_the_highlighted_value(STATUS,'edit')
    value_should_be_assign_to_property_on_card_edit(STATUS,OPEN)
  end

  def test_use_arrow_keys_to_move_highlight_on_card_show_drop_down_for_card_type
    there_are_some_card_types(@project)
    open_card(@project,@card)
    click_to_edit_card_type
    can_use_up_or_down_arrow_key_to_move_highlight_on_card_shown_card_type_drop_down([CARD,ITERATION,RELEASE,STORY])
  end

  def test_use_arrow_keys_to_move_highlight_on_card_show_drop_down_for_card_type_property
    there_are_some_card_plv_available_for_property
    open_card(@project,@card)
    click_property_on_card_show(RELEASE)
    can_use_up_or_down_arrow_key_to_move_highlight_on_property_drop_down(RELEASE,[NOT_SET,"(#{CARD_PLV_1})","(#{CARD_PLV_2})","(#{CARD_PLV_3})"],'show')
  end

  def test_use_arrow_keys_to_move_highlight_on_card_show_drop_down_for_any_number_property
    there_are_some_number_plv_available_for_any_number_property
    open_card(@project,@card)
    click_property_on_card_show(ESTIMATE)
    can_use_up_or_down_arrow_key_to_move_highlight_on_property_drop_down(ESTIMATE,[NOT_SET,"(#{NUMBER_PLV_1})","(#{NUMBER_PLV_2})","(#{NUMBER_PLV_3})"],'show')
  end


  def test_use_arrow_keys_to_move_highlight_on_card_show_drop_down_for_any_text_property
    there_are_some_text_plv_available_for_any_text_property
    open_card(@project,@card)
    click_property_on_card_show(RIVISION)
    can_use_up_or_down_arrow_key_to_move_highlight_on_property_drop_down(RIVISION,[NOT_SET,"(#{TEXT_PLV_1})","(#{TEXT_PLV_2})","(#{TEXT_PLV_3})"],'show')
  end


  def test_use_arrow_keys_to_move_highlight_on_card_show_drop_down_for_user_type_property
    open_card(@project,@card)
    click_property_on_card_show(OWNER)
    type_keyword_to_search_value_for_property_on_card_show(OWNER,'@email.com')
    can_use_up_or_down_arrow_key_to_move_highlight_on_property_drop_down(OWNER,[@project_member.name,@project_admin.name],'show')
  end

  def test_use_arrow_keys_to_move_highlight_on_card_show_drop_down_for_managed_number_property
    open_card(@project,@card)
    click_property_on_card_show(SIZE)
    type_keyword_to_search_value_for_property_on_card_show(SIZE,'1')
    can_use_up_or_down_arrow_key_to_move_highlight_on_property_drop_down(SIZE,[1,11,121],'show')
  end

  def test_use_arrow_keys_to_move_highlight_on_card_show_drop_down_for_managed_text_property
    open_card(@project,@card)
    click_property_on_card_show(STATUS)
    type_keyword_to_search_value_for_property_on_card_show(STATUS,'o')
    can_use_up_or_down_arrow_key_to_move_highlight_on_property_drop_down(STATUS,[NOT_SET,OPEN,CLOSED],'show')
  end

  def test_press_enter_should_select_the_highlighted_value__bulk_edit
    there_are_some_number_plv_available_for_any_number_property
    select_cards_in_card_list_view
    bulk_edit_property(ESTIMATE)
    press_down_arrow_key_on_property_drop_down(ESTIMATE,'bulk')

    press_enter_to_select_the_highlighted_value(ESTIMATE,'bulk')
    the_hightlighted_value_should_be_assign_to_estimate_property
  end

  def test_left_and_right_arrow_keys_shoud_be_ignored
    there_are_some_card_types(@project)
    select_cards_to_bulk_edit_card_type
    press_left_arrow_key_on_bulk_edit_card_type_drop_down
    highlight_should_be_changed

    press_right_arrow_key_on_bulk_edit_card_type_drop_down
    highlight_should_be_changed
  end

  def test_arrow_keys_should_be_ignored_if_the_highlight_already_hit_boundaries
    there_are_some_card_types(@project)
    select_cards_to_bulk_edit_card_type
    card_type_should_be_hightlighted_on_bulk_edit_panel(CARD)
    press_up_arrow_key_on_bulk_edit_card_type_drop_down
    card_type_should_be_hightlighted_on_bulk_edit_panel(CARD)

    press_down_arrow_key_on_bulk_edit_card_type_drop_down
    press_down_arrow_key_on_bulk_edit_card_type_drop_down
    press_down_arrow_key_on_bulk_edit_card_type_drop_down    
    card_type_should_be_hightlighted_on_bulk_edit_panel(STORY)

    press_down_arrow_key_on_bulk_edit_card_type_drop_down
    card_type_should_be_hightlighted_on_bulk_edit_panel(STORY)
  end

  def test_use_arrow_keys_to_move_highlight_on_drop_down__bulk_edit_card_type
    there_are_some_card_types(@project)
    select_cards_to_bulk_edit_card_type
    can_use_up_or_down_arrow_key_to_move_highlight_on_bulk_edit_card_type_drop_down([CARD,ITERATION,RELEASE,STORY])
  end

  def test_use_arrow_keys_to_move_highlight_on_drop_down__bulk_edit_managed_number_property
    select_cards_in_card_list_view
    bulk_edit_property(SIZE)
    can_use_up_or_down_arrow_key_to_move_highlight_on_property_drop_down(SIZE,[NOT_SET,1,11,121],'bulk')
  end

  def test_use_arrow_keys_to_move_highlight_on_drop_down__bulk_edit_managed_text_property
    select_cards_in_card_list_view
    bulk_edit_property(STATUS)
    can_use_up_or_down_arrow_key_to_move_highlight_on_property_drop_down(STATUS,[NOT_SET,NEW,OPEN],'bulk')
  end

  def test_use_arrow_keys_to_move_highlight_on_drop_down__bulk_edit_user_property
    select_cards_in_card_list_view
    bulk_edit_property(OWNER)
    can_use_up_or_down_arrow_key_to_move_highlight_on_property_drop_down(OWNER,[NOT_SET,CURRENT_USER,@project_member.name,@project_admin.name],'bulk')  
  end

  def test_use_arrow_keys_to_move_highlight_on_drop_down__bulk_edit_date_type_property
    there_are_some_date_plv_available_for_property
    select_cards_in_card_list_view
    bulk_edit_property(START_DATE)
    can_use_up_or_down_arrow_key_to_move_highlight_on_property_drop_down(START_DATE,[NOT_SET,"(#{DATE_PLV_1})","(#{DATE_PLV_2})",TODAY],'bulk')    
  end

  def test_use_arrow_keys_to_move_highlight_on_drop_down__bulk_edit_card_type_property
    there_are_some_card_plv_available_for_property
    select_cards_in_card_list_view
    bulk_edit_property(RELEASE)
    can_use_up_or_down_arrow_key_to_move_highlight_on_property_drop_down(RELEASE,[NOT_SET,"(#{CARD_PLV_1})","(#{CARD_PLV_2})","(#{CARD_PLV_3})"],'bulk')    
  end

  def test_use_arrow_keys_to_move_highlight_on_drop_down__bulk_edit_any_number_property
    there_are_some_number_plv_available_for_any_number_property
    select_cards_in_card_list_view
    bulk_edit_property(ESTIMATE)
    can_use_up_or_down_arrow_key_to_move_highlight_on_property_drop_down(ESTIMATE,[NOT_SET,"(#{NUMBER_PLV_1})","(#{NUMBER_PLV_2})","(#{NUMBER_PLV_3})"],'bulk')
  end

  def test_use_arrow_keys_to_move_highlight_on_drop_down__bulk_edit_any_text_property
    there_are_some_text_plv_available_for_any_text_property
    select_cards_in_card_list_view
    bulk_edit_property(RIVISION)
    can_use_up_or_down_arrow_key_to_move_highlight_on_property_drop_down(RIVISION,[NOT_SET,"(#{TEXT_PLV_1})","(#{TEXT_PLV_2})","(#{TEXT_PLV_3})"],'bulk')
  end

  #bug #8295 [property value selector] The drop down list should stay if user hits "Enter" but nothing matches his search.
  def test_should_keep_showing_dropdown_after_hit_enter__nothing_match
    open_card(@project,@card)
    click_property_on_card_show(SIZE)
    type_keyword_to_search_value_for_property_on_card_show(SIZE,'blabla')
    press_enter_on_property_dropdown(SIZE)
    should_still_see_dropdown(SIZE)
  end

end
