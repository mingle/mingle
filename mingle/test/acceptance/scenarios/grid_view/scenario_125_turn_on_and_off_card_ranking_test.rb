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

# Tags: cards, card-list, ranking
class Scenario125TurnOnAndOffCardRankingTest < ActiveSupport::TestCase
  fixtures :users, :login_access
  STATUS = "status"
  ESTIMATE_1 = "estimate_1"
  ESTIMATE_2 = "estimate_2"
  RANK = "Rank"
  NEW = "new"
  OPEN = "open"
  CARD = "Card"
  STORY = "Story"
  STORY_CARD = "story-card-relationship"
  TAG = "tag"

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @admin_user = users(:admin)
    @project_admin_user = users(:proj_admin)
    @read_only_user = users(:read_only_user)
    @team_member= users(:project_member)
    @project = create_project(:prefix => 'scenario_125', :users => [@team_member], :admins => [@project_admin_user], :anonymous_accessible => true,:read_only_users => [@read_only_user])
    @project.activate
    login_as_proj_admin_user

    @type_story = setup_card_type(@project, STORY)
    create_property_definition_for(@project, STATUS)
    create_property_definition_for(@project, ESTIMATE_1, :type => 'number list')
    create_property_definition_for(@project, ESTIMATE_2, :type => 'number list')
    @card1 = create_card!(:name => 'card1', :status => NEW, :estimate_1 => '1', :estimate_2 => '3', :card_type => CARD, :tags => [TAG])
    @card2 = create_card!(:name => 'card2', :status => OPEN, :estimate_1 => '2',:estimate_2 => '4', :card_type => CARD, :tags => [TAG])
    @card3 = create_card!(:name => 'card3', :status => NEW, :estimate_1 => '1', :estimate_2 => '3',:card_type => CARD)
    @card4 = create_card!(:name => 'card4', :status => OPEN, :estimate_1 => '2',:estimate_2 => '4',:card_type => CARD)
    @card5 = create_card!(:name => 'card5', :status => NEW, :estimate_1 => '1', :estimate_2 => '3',:card_type => CARD)
    @card6 = create_card!(:name => 'card6', :status => OPEN, :estimate_1 => '2',:estimate_2 => '4',:card_type => CARD)
    @card7 = create_card!(:name => 'card7', :status => NEW, :estimate_1 => '1',:estimate_2 => '3',:card_type => STORY, :tags =>  [TAG])
    @card8 = create_card!(:name => 'card8', :status => OPEN, :estimate_1 => '2',:estimate_2 => '4',:card_type => STORY, :tags =>  [TAG])

  end

  # TODO: move to controller test
  def test_only_admin_and_normal_team_member_can_see_ranking_option_button_in_grid_view
    register_license_that_allows_anonymous_users

    login_as_project_member
    navigate_to_grid_view_for(@project)
    assert_ranking_option_button_is_present
    assert_ranking_mode_is_turn_on

    login_as_admin_user
    navigate_to_user_management_page
    check_light_user_check_box_for(@team_member)
    logout

    login_as_project_member
    navigate_to_grid_view_for(@project)
    assert_ranking_option_button_is_not_present

    login_as_read_only_user
    navigate_to_grid_view_for(@project)
    assert_ranking_option_button_is_not_present

    logout
    navigate_to_grid_view_for(@project)
    assert_ranking_option_button_is_not_present
  end

  def test_card_ranking_mode_should_be_kept_on_when_user_does_follow_actions
    navigate_to_grid_view_for(@project)

    group_columns_by(STATUS)
    assert_ranking_mode_is_turn_on
    color_by(ESTIMATE_1)
    assert_ranking_mode_is_turn_on
    change_lane_heading('Minimum', 'estimate_2')
    assert_ranking_mode_is_turn_on

    set_the_filter_value_option(0, CARD)
    assert_ranking_mode_is_turn_on

    click_link_to_this_page
    assert_ranking_mode_is_turn_on

    group_columns_by(ESTIMATE_2)
    assert_ranking_mode_is_turn_on
    color_by(STATUS)
    assert_ranking_mode_is_turn_on
    change_lane_heading('Average', 'estimate_1')
    assert_ranking_mode_is_turn_on
    hide_grid_dimension('3')
    assert_ranking_mode_is_turn_on

    set_the_filter_value_option(0, STORY)
    assert_ranking_mode_is_turn_on

    set_the_filter_value_option(0, CARD)

    add_card_via_quick_add('testing quick add cards', :type => CARD)

    assert_ranking_mode_is_turn_on

    export_all_columns_to_excel_without_description
    click_back_link
    @browser.wait_for_all_ajax_finished
    assert_ranking_mode_is_turn_on

    header_row = ['number', 'name', 'type']
    card_data = [['8', 'card8', 'Card'],['9', 'card9', 'Card']]

    import_in_grid_view(excel_copy_string(header_row, card_data))
    @browser.wait_for_all_ajax_finished
    assert_ranking_mode_is_turn_on
  end

  # TODO: maybe...move to controller
  def test_ranking_mode_should_be_kept_on_when_user_set_filters_for_tree_in_grid_view
    @type_card = @project.card_types.find_by_name(CARD)
    @tree = setup_tree(@project, 'ranking mode tree', :types => [@type_story, @type_card], :relationship_names => [STORY_CARD])
    add_cards_to_tree(@tree, @card7, @card1)
    add_cards_to_tree(@tree, @card8, @card2)

    navigate_to_tree_view_for(@project, @tree.name)
    switch_to_grid_view
    assert_ranking_mode_is_turn_on

    add_new_tree_filter_for(@type_card)
    set_the_tree_filter_property_option(@type_card, 0, STATUS)
    set_the_tree_filter_value_option(@type_card, 0, NEW)
    assert_ranking_mode_is_turn_on

    add_new_tree_filter_for(@type_story)
    set_the_tree_filter_property_option(@type_story, 0, ESTIMATE_1)
    set_the_tree_filter_value_option(@type_story, 0, 1)
    assert_ranking_mode_is_turn_on

    click_exclude_card_type_checkbox(@type_card)
    assert_ranking_mode_is_turn_on
  end

  def test_when_user_leaves_grid_view_to_other_views_of_tree_while_ranking_mode_is_on_should_stay_on
    @type_card = @project.card_types.find_by_name(CARD)
    @tree = setup_tree(@project, 'ranking mode tree', :types => [@type_story, @type_card], :relationship_names => [STORY_CARD])
    add_card_to_tree(@tree, @card1)

    navigate_to_view_for(@project)
    assert_ranking_option_button_is_not_present

    navigate_to_grid_view_for(@project)
    assert_ranking_option_button_is_present
    assert_ranking_mode_is_turn_on
    assert_rank_is_selected_in_sort_by

    select_tree(@tree.name)
    assert_ranking_mode_is_turn_on

    switch_to_list_view
    assert_ranking_option_button_is_not_present

    switch_to_grid_view
    assert_ranking_mode_is_turn_on

    switch_to_tree_view
    assert_ranking_option_button_is_not_present

    switch_to_grid_view
    assert_ranking_mode_is_turn_on

    switch_to_hierarchy_view
    assert_ranking_option_button_is_not_present

    switch_to_grid_view
    assert_ranking_mode_is_turn_on

    select_tree("None")
    assert_ranking_mode_is_turn_on
  end

  # TODO: see how difficult it is to move to controller
  def test_transitions_should_be_available_when_ranking_mode_is_off
    does_not_work_on_ie do
      transition = create_transition(@project, 'status_new_open', :required_properties => {STATUS => NEW}, :set_properties => {STATUS => OPEN})
      navigate_to_grid_view_for(@project)
      turn_off_rank_mode
      assert_ranking_mode_is_turn_off

      click_on_card_in_grid_view(@card1.number)
      click_transition_link_on_card_in_grid_view(transition)
      open_card(@project, @card1.number)
      assert_property_set_on_card_show(STATUS, OPEN)
    end
  end

  # TODO: see how difficult it is to move to controller
  def test_transitions_should_be_available_when_ranking_mode_is_on
    does_not_work_on_ie do
      transition = create_transition(@project, 'status_new_open', :required_properties => {STATUS => NEW}, :set_properties => {STATUS => OPEN})
      navigate_to_grid_view_for(@project)
      assert_ranking_mode_is_turn_on

      click_on_card_in_grid_view(@card3.number)
      click_transition_link_on_card_in_grid_view(transition)
      open_card(@project, @card3.number)
      assert_property_set_on_card_show(STATUS, OPEN)
    end
  end
end
