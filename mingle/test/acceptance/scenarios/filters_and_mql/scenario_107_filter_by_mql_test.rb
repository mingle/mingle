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
require "uri/common"

# Tags: scenario, filters, mql
class Scenario107FilterByMqlTest < ActiveSupport::TestCase

  fixtures :users, :login_access
  STORY = 'story'
  CARD = 'Card'
  DEFECT = 'defect'
  TYPE = 'Type'

  SIZE = 'size'
  SIZE2 = 'size2'
  ITERATION = 'iteration'
  STATUS = 'status'
  OWNER = 'owner'
  START_DATE = 'start date'
  END_DATE = 'end date'
  ACTUAL_EFFORT = 'actual effort'

  CLOSED = 'closed'
  OPEN = 'open'
  TAG = 'new_tag'
  NONE = 'None'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin = users(:proj_admin)
    @team_member = users(:project_member)
    @read_only_user = users(:bob)
    @mingle_admin = users(:admin)
    @project = create_project(:prefix => 'scenario_107', :users => [@team_member], :admins => [@mingle_admin, @project_admin], :read_only_users => [@read_only_user])
    login_as_admin_user
    @text_property = setup_text_property_definition(ITERATION)
    @managed_text_property = setup_property_definitions(STATUS => [OPEN, CLOSED])
    @size = setup_numeric_text_property_definition(SIZE)
    @size2 = setup_numeric_property_definition(SIZE2, ['1', '3', '5'])
    @owner = setup_user_definition(OWNER)
    @start_date = setup_date_property_definition(START_DATE)
    @end_date = setup_date_property_definition(END_DATE)

    @actual_effort = setup_formula_property_definition(ACTUAL_EFFORT, "'#{END_DATE}' - '#{START_DATE}' + 1")
    @type_story = setup_card_type(@project, STORY, :properties => [STATUS, SIZE, START_DATE, END_DATE, OWNER, ACTUAL_EFFORT])
    @type_defect = setup_card_type(@project, DEFECT, :properties => [STATUS, SIZE2, START_DATE, END_DATE, OWNER])

    @card1 = create_card!(:name => 'card1', :tags => [TAG])
    @bug1 = create_card!(:name => 'bug1', :card_type => DEFECT, STATUS => CLOSED, SIZE2 => 3, START_DATE => '01 Jan 2001', END_DATE => '08 Jan 2001', OWNER => @mingle_admin.id, :tags => [TAG])
    @story1 = create_card!(:name => 'story1', :card_type => STORY, STATUS => OPEN, SIZE => 50, START_DATE => '01 Jan 2001', END_DATE => '05 Jan 2001', OWNER => @read_only_user.id)
    @story2 = create_card!(:name => 'story2', :card_type => STORY, STATUS => CLOSED, SIZE => 30, START_DATE => '01 Jan 2001', END_DATE => '07 Jan 2001', OWNER => @mingle_admin.id)
    navigate_to_card_list_for(@project)
  end

  def test_error_message_when_use_this_card_value_in_mql_filter
    navigate_to_card_list_for(@project)
    set_mql_filter_for("#{ITERATION} = this card.#{ITERATION}")
    assert_error_message("Filter is invalid. THIS CARD is not supported in MQL filters.")
  end

  def test_use_keyword_NUMBER_in_mql_filter
    story3 = create_card!(:name => 'story3', :card_type => STORY)
    story4 = create_card!(:name => 'story4', :card_type => STORY)
    story5 = create_card!(:name => 'story5', :card_type => STORY)
    other_card = create_property_definition_for(@project, 'other_card', :type => 'card', :types => [STORY])
    open_card(@project, @story1)
    set_relationship_properties_on_card_show('other_card' => @story2)
    open_card(@project, @story2)
    set_relationship_properties_on_card_show('other_card' => story3)
    open_card(@project, story3)
    set_relationship_properties_on_card_show('other_card' => story4)
    open_card(@project, story4)
    set_relationship_properties_on_card_show('other_card' => story5)
    open_card(@project, story5)
    set_relationship_properties_on_card_show('other_card' => @story1)
    navigate_to_card_list_for(@project)

    set_mql_filter_for("Type = #{STORY} AND other_card = NUMBER #{@story1.number}")
    assert_card_present_in_list(story5)

    set_mql_filter_for("Type = #{STORY} AND other_card > NUMBER #{@story1.number}")
    assert_card_present_in_list(@story1)
    assert_card_present_in_list(@story2)
    assert_card_present_in_list(story3)
    assert_card_present_in_list(story4)
    assert_card_not_present_in_list(story5)

    set_mql_filter_for("Type = #{STORY} AND other_card >= NUMBER #{story4.number}")
    assert_card_present_in_list(story3)
    assert_card_present_in_list(story4)
    assert_card_not_present_in_list(@story1)
    assert_card_not_present_in_list(@story2)
    assert_card_not_present_in_list(story5)

    set_mql_filter_for("Type = #{STORY} AND other_card < NUMBER #{story3.number}")
    assert_card_present_in_list(@story1)
    assert_card_present_in_list(story5)
    assert_card_not_present_in_list(@story2)
    assert_card_not_present_in_list(story3)
    assert_card_not_present_in_list(story4)

    set_mql_filter_for("Type = #{STORY} AND other_card <= NUMBER #{story3.number}")
    assert_card_present_in_list(@story1)
    assert_card_present_in_list(story5)
    assert_card_present_in_list(@story2)
    assert_card_not_present_in_list(story3)
    assert_card_not_present_in_list(story4)

    set_mql_filter_for("Type = #{STORY} AND other_card != NUMBER #{story3.number}")
    assert_card_present_in_list(@story1)
    assert_card_present_in_list(story3)
    assert_card_present_in_list(story4)
    assert_card_present_in_list(story5)
    assert_card_not_present_in_list(@story2)

    set_mql_filter_for("Type = #{STORY} AND other_card NUMBER IN (#{story3.number}, #{story4.number}, #{story5.number})")
    assert_card_present_in_list(@story2)
    assert_card_present_in_list(story3)
    assert_card_present_in_list(story4)
    assert_card_not_present_in_list(@story1)
    assert_card_not_present_in_list(story5)


    set_mql_filter_for("Type = #{STORY} AND other_card_xx < NUMBER #{story3.number}")
    assert_error_message("Filter is invalid. Card property 'other_card_xx' does not exist!")

    set_mql_filter_for("Type = #{STORY} AND other_card < NUMBER aa")
    assert_error_message("Filter is invalid. aa is not a valid value for other_card. Only numbers can be used as values in a 'column = NUMBER ...' clause")
  end


  def test_mql_filter_should_not_use_SELECT_WHERE_clauses_but_just_conditions
    set_mql_filter_for("SELECT #{STATUS} WHERE type=#{STORY}")
    assert_error_message("Filter is invalid. SELECT is not required to filter by MQL. Enter MQL conditions only.")

    set_mql_filter_for("type = card")
    assert_card_present_in_list(@card1)
  end

  def test_greater_than_or_less_than_or_equal_to_for_conditions_can_be_set_on_mql_filter
    condition_with_less_than_greater_than_AND = "Type=#{STORY} AND #{SIZE} >= 30 AND '#{ACTUAL_EFFORT}' <= 6"
    set_mql_filter_for(condition_with_less_than_greater_than_AND)
    assert_card_present_in_list(@story1)
    assert_card_not_present_in_list(@story2)
    assert_mql_filter(condition_with_less_than_greater_than_AND)
  end

  def test_should_escape_html_in_mql_filter
    condition_with_html_tag = "<b>123</b>"
    set_mql_filter_for(condition_with_html_tag)
    assert_raw_mql_filter("&lt;b&gt;123&lt;/b&gt;")
  end

  def test_should_not_escape_html_in_mql_edit_box_after_save_as_favorites
    condition_with_html_tag = %Q{"Type" is #{STORY} AND name != "<B>123</B>"}
    set_mql_filter_for(condition_with_html_tag)
    create_card_list_view_for(@project, condition_with_html_tag)
    assert_mql_window_content(condition_with_html_tag)
    click_on_edit_mql_filter
    click_cancel_mql
    assert_mql_window_content(condition_with_html_tag)
  end

  def test_IN_and_OR_operators_for_mql_filter
    story3 = create_card!(:name => 'story3', :card_type => STORY, STATUS => OPEN, SIZE => 20, START_DATE => '02 Jan 2001', END_DATE => '05 Jan 2001', OWNER => @read_only_user.id)
    condition_not_equal_and_NOT = "Type=#{STORY} AND (#{SIZE} IN(20, 50) OR '#{ACTUAL_EFFORT}' = 7)"
    set_mql_filter_for(condition_not_equal_and_NOT)
    assert_card_present_in_list(@story1)
    assert_card_present_in_list(@story2)
    assert_card_present_in_list(story3)
    assert_mql_filter(condition_not_equal_and_NOT)
  end

  def test_mql_condition_without_specifying_type
    condition = "#{SIZE} < 50 OR '#{SIZE2}' >= 1"
    set_mql_filter_for(condition)
    assert_card_not_present_in_list(@story1)
    assert_card_present_in_list(@story2)
    assert_card_present_in_list(@bug1)
    assert_mql_filter(condition)
  end

  def test_can_see_and_use_quick_add_action_bar_when_using_mql_filter
    condition = "TYPE = #{STORY} AND #{SIZE} = 30"
    set_mql_filter_for(condition)
    assert_card_present_in_list(@story2)
    add_card_via_quick_add('test can quick add card when using mql filter')
    assert_notice_message("Card #5 was successfully created.")
    navigate_to_grid_view_for(@project)
    set_mql_filter_for(condition)
    assert_cards_present_in_grid_view(@story2)
    add_card_via_quick_add('2 - test can quick add card to view when using mql filter')
    assert_notice_message("Card #6 was successfully created")
  end

  def test_tagged_with_for_mql_filters
    condition = "TAGGED WITH #{TAG}"
    set_mql_filter_for(condition)
    assert_card_present_in_list(@card1)
    assert_card_present_in_list(@bug1)
    assert_card_not_present_in_list(@story1)
    assert_card_not_present_in_list(@story2)
    assert_mql_filter(condition)
  end

  # bug 6998 bug 7845
  def test_bulk_adding_tag_when_use_mql_filter_to_filter_card_with_tag_out
    condition = "NOT TAGGED WITH #{TAG}"
    set_mql_filter_for(condition)
    assert_card_present_in_list(@story1)
    assert_card_present_in_list(@story2)
    check_cards_in_list_view(@story1)
    bulk_tag(TAG)
    assert_card_not_present_in_list(@story1)

    new_tag = "new tag which does not exit before"
    condition = "NOT TAGGED WITH '#{new_tag}'"
    set_mql_filter_for(condition)
    assert_card_present_in_list(@story1)
    assert_card_present_in_list(@story2)
    check_cards_in_list_view(@story1)
    bulk_tag(new_tag)
    assert_card_not_present_in_list(@story1)
  end

  def test_CURRENT_USER_and_TODAY_for_mql_filters
    fake_now(2001, 1, 8)
    navigate_to_card_list_for(@project)
    condition = "#{OWNER} = CURRENT USER AND '#{END_DATE}' = TODAY"
    set_mql_filter_for(condition)
    assert_card_not_present_in_list(@story1)
    assert_card_not_present_in_list(@story2)
    assert_card_present_in_list(@bug1)
  ensure
    @browser.reset_fake
  end

  def test_mql_filters_can_use_plvs
    project_variable = setup_project_variable(@project, :name => 'my plv', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => OPEN, :properties => [STATUS])
    condition = "#{STATUS} = (#{project_variable.name})"
    set_mql_filter_for(condition)
    assert_mql_filter(condition)
    assert_card_not_present_in_list(@story2)
    assert_card_present_in_list(@story1)
  end

  def test_property_comparison_in_mql_filter
    bug2 = create_card!(:name => 'bug2', :card_type => DEFECT, STATUS => CLOSED, SIZE2 => 30, START_DATE => '02 Jan 2001', END_DATE => '01 Jan 2001', OWNER => @mingle_admin.id, :tags => [TAG])
    condition = "'#{START_DATE}' > PROPERTY '#{END_DATE}'"
    set_mql_filter_for(condition)
    assert_card_present_in_list(bug2)
    assert_card_not_present_in_list(@story1)
    assert_card_not_present_in_list(@story2)
    assert_card_not_present_in_list(@bug1)
  end

  def test_mql_filter_set_can_be_made_as_favorite_or_tab
    condition_with_less_than_greater_than_AND = "Type=#{STORY} AND #{SIZE} >= 30 AND '#{ACTUAL_EFFORT}' <= 6"
    set_mql_filter_for(condition_with_less_than_greater_than_AND)
    favorite = create_card_list_view_for(@project, 'favorite one')
    assert_card_favorites_link_present(favorite.name)
    open_favorites_for(@project, favorite.name)
    assert_mql_filter(condition_with_less_than_greater_than_AND)
    assert_card_present_in_list(@story1)
    assert_card_not_present_in_list(@story2)

    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(favorite)
    click_tab(favorite.name)
    assert_mql_filter(condition_with_less_than_greater_than_AND)
    assert_card_present_in_list(@story1)
    assert_card_not_present_in_list(@story2)
  end

  def test_mql_filter_can_be_set_through_url
    condition_with_less_than_greater_than_AND = "Type=#{STORY} AND #{SIZE} >= 30 AND '#{ACTUAL_EFFORT}' <= 6"
    url = "/projects/#{@project.identifier}/cards/list?filters[mql]=#{URI.escape(condition_with_less_than_greater_than_AND)}&tab=All"
    @browser.open(url)
    assert_mql_filter(condition_with_less_than_greater_than_AND)
    assert_card_present_in_list(@story1)
    assert_card_not_present_in_list(@story2)
  end

  def test_card_context_miantained_for_list_view_filtered_by_mql
    story3 = create_card!(:name => 'story3', :card_type => STORY, STATUS => OPEN, SIZE => 20, START_DATE => '02 Jan 2001', END_DATE => '05 Jan 2001', OWNER => @read_only_user.id)
    condition_not_equal_and_NOT = "Type=#{STORY} AND (#{SIZE} IN(20, 50) OR '#{ACTUAL_EFFORT}' = 7)"
    set_mql_filter_for(condition_not_equal_and_NOT)
    click_card_on_list(story3.number)
    assert_card_context_present
    assert_context_text(:this_is => 1, :of => 3)
    assert_mouse_over_message_for_card_context(condition_not_equal_and_NOT)
  end

  def test_mql_filter_remembered_on_switching_between_list_and_grid_and_remember_columns
    condition_with_less_than_greater_than_AND = "Type=#{STORY} AND #{SIZE} >= 30 AND '#{ACTUAL_EFFORT}' <= 6"
    set_mql_filter_for(condition_with_less_than_greater_than_AND)
    add_column_for(@project, [@size,@start_date,@end_date])
    assert_card_present_in_list(@story1)
    assert_card_not_present_in_list(@story2)
    assert_mql_filter(condition_with_less_than_greater_than_AND)
    assert_column_present_for(SIZE,START_DATE,END_DATE)

    switch_to_grid_view
    assert_mql_filter(condition_with_less_than_greater_than_AND)

    switch_to_list_view
    assert_card_present_in_list(@story1)
    assert_card_not_present_in_list(@story2)
    assert_mql_filter(condition_with_less_than_greater_than_AND)
    assert_column_present_for(SIZE,START_DATE,END_DATE)
  end

  def test_bulk_property_update_for_mql_filter
    condition = "Type=#{STORY} AND #{SIZE} >= 30"
    set_mql_filter_for(condition)
    assert_card_present_in_list(@story1)
    assert_card_present_in_list(@story2)
    check_cards_in_list_view(@story1)
    click_edit_properties_button
    set_card_type_on_bulk_edit(DEFECT)
    assert_card_not_present_in_list(@story1)
    assert_card_present_in_list(@story2)
  end

  def test_bulk_tagging_for_mql_filter
    condition = "TAGGED WITH #{TAG}"
    set_mql_filter_for(condition)
    assert_card_present_in_list(@card1)
    assert_card_present_in_list(@bug1)
    assert_card_not_present_in_list(@story1)
    assert_card_not_present_in_list(@story2)
    assert_mql_filter(condition)
    check_cards_in_list_view(@bug1)
    click_bulk_tag_button
    bulk_remove_tag(TAG)
    assert_card_present_in_list(@card1)
    assert_card_not_present_in_list(@bug1)
    assert_card_not_present_in_list(@story1)
    assert_card_not_present_in_list(@story2)
  end

  def test_group_by_dropdown_shows_properties_as_per_mql_filter_condition
    edit_card_type_for_project(@project,  DEFECT, :properties => [SIZE2, START_DATE, END_DATE, OWNER])
    condition = "Type = #{STORY}"
    navigate_to_grid_view_for(@project)
    set_mql_filter_for(condition)
    assert_properties_present_on_group_columns_by_drop_down_list(TYPE, STATUS, OWNER)
    assert_property_not_present_in_group_columns_by(SIZE2)

    set_mql_filter_for("Type = #{DEFECT}")
    assert_properties_present_on_group_columns_by_drop_down_list(TYPE, SIZE2, OWNER)
    assert_property_not_present_in_group_columns_by(STATUS)
  end

  def test_should_be_able_to_group_by_and_lane_heading_in_grid_view_while_mql_filter_set
    condition = "#{STATUS} IN (#{OPEN}, #{CLOSED})"
    set_mql_filter_for(condition)
    navigate_to_grid_view_for(@project, :group_by  => STATUS, :aggregate_type => 'Sum', :aggregate_property => SIZE)
    assert_cards_present_in_grid_view(@story1)
    assert_cards_present_in_grid_view(@story2)
    assert_cards_present_in_grid_view(@bug1)
    assert_lane_present(STATUS,OPEN)
    assert_lane_present(STATUS,CLOSED)
    assert_lane_headings('sum', SIZE)
    assert_group_lane_number('50', :lane => [STATUS, OPEN])
    assert_group_lane_number('30', :lane => [STATUS, CLOSED])
  end

  def test_group_by_order_by_clauses_used_in_mql_filter_throws_proper_info
    condition = "SELECT STATUS WHERE Type = #{STORY} GROUP BY #{STATUS} ORDER BY #{SIZE}"
    navigate_to_grid_view_for(@project)
    set_mql_filter_for(condition)
    assert_error_message("Filter is invalid. SELECT, GROUP BY and ORDER BY are not required to filter by MQL. Enter MQL conditions only.")
  end

  def test_aggregate_types_in_mql_filter_should_be_invalid_and_show_proper_info
    condition = "Type = #{STORY} OR AVG(#{SIZE}) = 1 OR COUNT(#{SIZE}) = 1"
    navigate_to_grid_view_for(@project)
    set_mql_filter_for(condition)
    #assert_error_message("Filter is invalid. SUM, AVG is not required to filter by MQL. Enter MQL conditions only.")
  end

  def test_no_result_after_filter_by_mql_throws_proper_info
    conditon = "Type =#{STORY} AND #{SIZE} = 100"
    set_mql_filter_for(conditon)
    assert_info_message("There are no cards that match the current filter - Reset filter")
    click_on_reset_filter_link
    assert_type_present_with_default_selected_as_any
    click_on_mql_filter_tab
    assert_mql_filter_is_empty
    assert_card_present_in_list(@story1)
    assert_card_present_in_list(@story2)
    assert_card_present_in_list(@bug1)
    assert_card_present_in_list(@card1)
  end

  def test_apply_button_should_be_displayed_when_change_another_filter
    conditon = "Type =#{STORY}"
    set_mql_filter_for(conditon)
    click_on_interactive_filter_tab
    assert_apply_button_displayed_on_interactive_filter
    assert_card_present_in_list(@story1)
    assert_card_present_in_list(@story2)

    click_apply_this_filter
    assert_apply_button_not_displayed_on_interactive_filter
    assert_card_present_in_list(@story1)
    assert_card_present_in_list(@story2)
    assert_card_present_in_list(@bug1)
    assert_card_present_in_list(@card1)
    click_on_mql_filter_tab
    assert_apply_button_displayed_on_mql_filter

    click_apply_this_filter
    assert_apply_button_not_displayed_on_mql_filter
    assert_card_present_in_list(@story1)
    assert_card_present_in_list(@story2)
  end

  def test_renaming_property_used_by_mql_filter_favorite_will_be_deleted
    conditon = "Type = #{STORY} AND #{SIZE} >= 30"
    set_mql_filter_for(conditon)
    favorite = create_card_list_view_for(@project, 'favorite one')
    assert_card_favorites_link_present(favorite.name)
    navigate_to_property_management_page_for(@project)
    new_size = edit_property_definition_for(@project, SIZE, :new_property_name => 'new size')
    assert_notice_message("Property was successfully updated.")
    click_all_tab
    assert_error_message("Filter is invalid. Card property '#{SIZE}' does not exist!")
    open_saved_view(favorite.name)
    assert_mql_filter("Type = #{STORY} AND '#{new_size.name}' >= 30")
    assert_card_present_in_list(@story1)
    assert_card_present_in_list(@story2)
  end

  def test_clear_button_followed_by_submit_will_submit_no_filter
    condition = "Type =#{STORY} AND #{SIZE} >= 30"
    set_mql_filter_for(condition)
    assert_card_present_in_list(@story1)
    assert_card_present_in_list(@story2)
    click_on_edit_mql_filter
    click_clear_mql
    assert_mql_window_empty
    click_submit_mql
    assert_card_present_in_list(@story1)
    assert_card_present_in_list(@story2)
    assert_card_present_in_list(@bug1)
    assert_card_present_in_list(@card1)
  end

  def test_clear_button_followed_by_cancel_button_will_return_the_filter_before
    condition = "Type = #{STORY} AND #{SIZE} >= 30"
    set_mql_filter_for(condition)
    assert_card_present_in_list(@story1)
    assert_card_present_in_list(@story2)
    click_on_edit_mql_filter
    input_mql_conditions(condition)
    click_clear_mql
    click_cancel_mql
    assert_mql_filter(condition)
  end

  def test_mql_filter_should_support_FROM_TREE_and_FROM_TREE_WHERE
    tree = setup_tree(@project, 'Simple Tree', :types => [@type_story, @type_defect], :relationship_names => ["Story"])
    add_card_to_tree(tree, @story1)
    add_card_to_tree(tree, @bug1, @story1)
    navigate_to_card_list_for(@project)
    assert_card_present_in_list(@story2)
    assert_card_present_in_list(@card1)

    set_mql_filter_for("FROM TREE '#{tree.name}'")
    assert_card_present_in_list(@story1)
    assert_card_present_in_list(@bug1)
    assert_card_not_present_in_list(@story2)
    assert_card_not_present_in_list(@card1)

    set_mql_filter_for("FROM TREE '#{tree.name}' where type = defect")
    assert_card_not_present_in_list(@story1)

    assert_tree_selected("None")

    set_mql_filter_for("FROM TREE '#{tree.name}2' where type = defect")
    assert_error_message("Filter is invalid. Tree with name '#{tree.name}2' does not exist")
  end

  #bug 6976
  def test_should_be_able_to_delete_card_when_there_is_a_favorite_which_has_a_compare_condition_for_releationship_property
    tree = setup_tree(@project, 'Simple Tree', :types => [@type_story, @type_defect], :relationship_names => ["Story"])
    add_card_to_tree(tree, @story1)
    add_card_to_tree(tree, @bug1, @story1)
    navigate_to_card_list_for(@project)

    set_mql_filter_for("Story < story2")
    favorite = create_card_list_view_for(@project, 'favorite one')
    navigate_to_card_list_for(@project)
    click_card_on_list(@story1)
    click_card_delete_link
    click_continue_to_delete_on_confirmation_popup
    assert_text_present("Card #3 deleted successfully.")
  end

  # bug 4724
  def test_mql_filter_works_fine_in_grid_and_list_view_after_seleting_tree_and_switcting_filters
    tree = create_and_configure_new_card_tree(@project, :name => "tree", :types => [STORY, CARD])
    navigate_to_card_list_for(@project)
    set_mql_filter_for("#{STATUS} = #{OPEN}")
    assert_card_present_in_list(@story1)
    assert_cards_not_present_in_list(@story2, @bug1, @card1)

    select_tree(tree.name)
    select_tree(NONE)
    click_on_interactive_filter_tab
    set_the_filter_value_option(0, DEFECT)
    click_on_mql_filter_tab
    click_apply_this_filter
    assert_card_present_in_list(@story1)
    assert_cards_not_present_in_list(@story2, @bug1, @card1)

    navigate_to_grid_view_for(@project)
    set_mql_filter_for("#{STATUS} = #{OPEN}")
    select_tree(tree.name)
    select_tree(NONE)
    click_on_interactive_filter_tab
    set_the_filter_value_option(0, DEFECT)
    click_on_mql_filter_tab
    click_apply_this_filter
    assert_cards_present_in_grid_view(@story1)
    assert_cards_not_present_in_grid_view(@story2, @bug1, @card1)
  end

  # bug 4722
  def test_mql_filter_works_fine_in_grid_view_after_group_by_and_switching_filter
    navigate_to_grid_view_for(@project)
    set_the_filter_value_option(0, CARD)
    click_on_mql_filter_tab
    set_mql_filter_for("type = #{STORY}")
    group_columns_by(STATUS)
    assert_cards_not_present_in_grid_view(@card1)
    assert_cards_not_present_in_grid_view(@bug1)
    assert_cards_present_in_grid_view(@story1)
    assert_cards_present_in_grid_view(@story2)
    click_on_interactive_filter_tab
    set_the_filter_value_option(0, DEFECT)
    assert_cards_present_in_grid_view(@bug1)
    assert_cards_not_present_in_grid_view(@story1)
    assert_cards_not_present_in_grid_view(@story2)
    click_on_mql_filter_tab
    click_apply_this_filter
    assert_cards_not_present_in_grid_view(@bug1)
    assert_cards_present_in_grid_view(@story2)
    assert_cards_present_in_grid_view(@story1)

  end

  # bug 4725
  def test_mql_filter_works_fine_in_after_saved_as_fav_and_switching_filter
    navigate_to_card_list_for(@project)
    set_mql_filter_for("#{STATUS} = #{OPEN}")
    assert_card_present_in_list(@story1)
    assert_cards_not_present_in_list(@story2, @bug1, @card1)
    mql_view = create_card_list_view_for(@project, "mql view")

    reset_mql_filter_by
    open_saved_view mql_view.name
    click_on_interactive_filter_tab
    set_the_filter_value_option(0, DEFECT)
    assert_card_present_in_list(@bug1)
    assert_cards_not_present_in_list(@story1)
    click_on_mql_filter_tab
    click_apply_this_filter
    assert_cards_not_present_in_list(@bug1)
    assert_card_present_in_list(@story1)
  end

  #bug 4729
  def test_group_by_drodown_shows_options_when_using_IS_NOT_NULL_in_mql_filer
    navigate_to_grid_view_for(@project)
    set_mql_filter_for("type = story and size is not null")
    assert_properties_present_on_group_columns_by_drop_down_list(TYPE, OWNER, STATUS)
  end

  #bug 6569
  def test_MQL_filter_that_with_many_parenthesis_can_be_saved_as_favorite
    current_user = '(current user)'
    user1 = create_team_property('developer 1')
    user2 = create_team_property('developer 2')
    user3 = create_team_property('developer 3')
    user4 = create_team_property('developer 4')
    add_properties_for_card_type(@type_story,[user1, user2, user3])
    add_properties_for_card_type(@type_defect,[user1, user2, user3])
    new_card_1 = create_card!(:name => 'new_card_1', :card_type => DEFECT, 'developer 1' => current_user, 'developer 2' => current_user, 'developer 3' => current_user, 'developer 4' => current_user)
    new_card_2 = create_card!(:name => 'new_card_2', :card_type => STORY,  'developer 1' => current_user, 'developer 2' => current_user, 'developer 3' => current_user, 'developer 4' => current_user)
    new_card_3 = create_card!(:name => 'new_card_3', :card_type => STORY,  'developer 1' => current_user, 'developer 2' => current_user, 'developer 3' => current_user, 'developer 4' => current_user)
    navigate_to_card_list_for(@project)
    click_on_mql_filter_tab
    set_mql_filter_for("type = #{STORY} and ( 'developer 1' = current user or 'developer 2' = current user) or type = #{DEFECT} and ('developer 3' = current user or 'developer 4' = current user)")
    favorite = create_card_list_view_for(@project, 'favorite one')
    assert_card_favorites_link_present(favorite.name)
  end

  #bug 7636
  def test_filtering_by_mql_with_date_property_named_date_equals_card_created_on_date
    date_property = setup_date_property_definition("date")
    date_property.card_types = @project.card_types
    date_property.save!
    @project.reload
    @card1.update_attribute(:cp_date, @card1.created_on)
    @bug1.update_attribute(:cp_date, @bug1.created_on)
    set_mql_filter_for("'created on' = PROPERTY 'date'")
    assert_cards_not_present(@story1, @story2)
    assert_cards_present(@card1, @bug1)
  end

end
