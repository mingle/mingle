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

# Tags: scenario, new_user_role, user, readonly
class Scenario102ReadOnlyTeamMemberUsageTest < ActiveSupport::TestCase

  fixtures :users, :login_access
  SIZE = 'size'
  ITERATION = 'iteration'
  STATUS = 'status'
  ESTIMATE = 'estimate'
  OWNER = 'owner'
  START_DATE = 'start date'
  STORY = 'story'
  CARD = 'Card'
  BUG = 'bug'
  CLOSED = 'closed'
  OPEN = 'open'
  TAG = 'new_tag'
  TYPE = 'Type'

  THIS_CARD_BELONGS_TO_TREE = '(This card belongs to this tree.)'
  THIS_CARD_AWAILABLE_TO_TREE = '(This card is available to this tree.)'
  SPECIAL_HEADER_ACTIONS = 'Special:HeaderActions'
  ERROR_MESSAGE_FOR_CREATE_CARD_OR_WIKI_VIA_LINK ='Read only team member (or Anonymous user) does not have the required permission to perform that action.'
  ERROR_MESSAGE_FOR_CREATE_CARD_VIA_URL = 'Either the resource you requested does not exist or you do not have access rights to that resource.'
  ERROR_MESSAGE_FOR_CREATE_WIKI_PAGE_VIA_URL = 'Read only team member does not have access rights to create page'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin = users(:proj_admin)
    @team_member = users(:project_member)
    @read_only_user = users(:bob)
    @mingle_admin = users(:admin)
    @project = create_project(:prefix => 'scenario_102_project', :users => [@team_member], :admins => [@mingle_admin, @project_admin], :read_only_users => [@read_only_user])
    login_as_admin_user
    @text_property = setup_text_property_definition(ITERATION)
    @managed_text_property = setup_property_definitions(STATUS => [OPEN, CLOSED])
    @numeric_property = setup_numeric_text_property_definition(SIZE)
    @managed_numeric_property = setup_numeric_property_definition(ESTIMATE, ['1', '3', '5'])
    @user_property = setup_user_definition(OWNER)
    @date_property = setup_date_property_definition(START_DATE)
    @formula_property = setup_formula_property_definition('final estimate', "#{ESTIMATE} * 2")
    @card1 = create_card!(:name => 'card1', :tags => [TAG])
  end

  # Card show related tests

  def test_read_only_team_member_should_not_be_able_to_edit_any_proeprties
    login_as_read_only_team_member
    open_card(@project, @card1)
    assert_card_type_not_editable_on_card_show
    assert_properties_not_editable_on_card_show([SIZE, ITERATION, STATUS, START_DATE, ESTIMATE, OWNER, @formula_property.name])
  end

  def test_read_only_team_member_does_not_have_links_like_delete_edit_add_tag_add_description_transitions_etc
    @transition = create_transition(@project, 'close story', :set_properties => {STATUS => CLOSED})
    login_as_read_only_team_member
    open_card(@project, @card1)
    assert_links_not_present_for_read_only_user_on_card_show_page
    assert_formatting_help_side_bar_not_present
  end

  def test_read_only_user_should_have_links_for_via_feed_and_email_uplink_card_context_for_card_show
    cards = create_cards(@project, 2)
    login_as_read_only_team_member
    navigate_to_card_list_for(@project)
    click_card_on_list(@card1)
    assert_links_present_for_read_only_user_on_card_show
    assert_context_text(:this_is => 3, :of => 3)
    click_next_card_on_card_context
    assert_context_text(:this_is => 1, :of => 3)
    assert_card_location_in_card_show(@project, cards[1])
  end

  def test_parent_card_on_tree_shows_only_navigation_related_links_and_tree_related_messages_on_card_show_for_read_only_user
    story_type = setup_card_type(@project, STORY, :properties => [STATUS, SIZE, ESTIMATE, OWNER, START_DATE, @formula_property.name])
    bug_type = setup_card_type(@project, BUG, :properties => [STATUS])
    tree = setup_tree(@project, 'simple tree', :types => [story_type, bug_type], :relationship_names => ['relation - story'])
    aggregate = setup_aggregate_property_definition('bug count', AggregateType::COUNT, nil, tree.id, story_type.id, bug_type)

    story1_card = create_card!(:name => 'story 1', :type => story_type.name)
    story2_card = create_card!(:name => 'story 2', :type => story_type.name)
    bug_card = create_card!(:name => 'bug 1', :type => bug_type.name)
    add_card_to_tree(tree, story1_card)
    add_card_to_tree(tree, bug_card, story1_card)

    login_as_read_only_team_member
    open_card(@project, story1_card)
    assert_view_tree_link_present(tree)
    assert_create_new_children_link_not_present_for(tree)
    assert_remove_card_from_tree_link_is_not_present(tree)
    assert_card_belongs_to_or_not_message_on_card_show_for(tree, THIS_CARD_BELONGS_TO_TREE)
    assert_properties_not_editable_on_card_show([aggregate.name])
  end

  # bug 8509
  def test_card_show_should_show_link_to_tree_for_regular_and_read_only_users
    story_type = setup_card_type(@project, STORY, :properties => [STATUS, SIZE, ESTIMATE, OWNER, START_DATE, @formula_property.name])
    bug_type = setup_card_type(@project, BUG, :properties => [STATUS])
    tree = setup_tree(@project, 'simple tree', :types => [story_type, bug_type], :relationship_names => ['relation - story'])
    story1_card = create_card!(:name => 'story 1', :type => story_type.name)
    story1_card.update_attribute(:name, "story")
    bug_card = create_card!(:name => 'bug 1', :type => bug_type.name)
    add_card_to_tree(tree, story1_card, :root)
    add_card_to_tree(tree, bug_card, story1_card)

    open_card(@project, story1_card)
    assert_view_tree_link_present(tree)

    click_edit_link_on_card
    assert_view_tree_link_not_present(tree)

    load_card_history
    @browser.click_and_wait "link-to-card-#{story1_card.number}-1"
    assert_view_tree_link_not_present(tree)

    login_as_read_only_team_member

    open_card(@project, story1_card)
    assert_view_tree_link_present(tree)

    load_card_history
    @browser.click_and_wait "link-to-card-#{story1_card.number}-1"
    assert_view_tree_link_not_present(tree)
  end

  def test_child_card_on_tree_shows_only_navigation_related_links_and_tree_related_messages_on_card_show_for_read_only_user
    story_type = setup_card_type(@project, STORY, :properties => [STATUS, SIZE, ESTIMATE, OWNER, START_DATE, @formula_property.name])
    bug_type = setup_card_type(@project, BUG, :properties => [STATUS])
    tree = setup_tree(@project, 'simple tree', :types => [story_type, bug_type], :relationship_names => ['relation - story'])
    aggregate = setup_aggregate_property_definition('bug count', AggregateType::COUNT, nil, tree.id, story_type.id, bug_type)

    story1_card = create_card!(:name => 'story 1', :type => story_type.name)
    story2_card = create_card!(:name => 'story 2', :type => story_type.name)
    bug_card = create_card!(:name => 'bug 1', :type => bug_type.name)
    add_card_to_tree(tree, story1_card)
    add_card_to_tree(tree, bug_card, story1_card)

    login_as_read_only_team_member
    open_card(@project, bug_card)
    assert_card_belongs_to_or_not_message_on_card_show_for(tree, THIS_CARD_BELONGS_TO_TREE)
    assert_create_new_children_link_not_present_for(tree)
    assert_remove_card_from_tree_link_is_not_present(tree)
    assert_properties_not_editable_on_card_show(['relation - story'])
  end

  def test_card_not_belongs_to_tree_shows_only_navigation_related_links_and_tree_related_messages_on_card_show_for_read_only_user
    story_type = setup_card_type(@project, STORY, :properties => [STATUS, SIZE, ESTIMATE, OWNER, START_DATE, @formula_property.name])
    bug_type = setup_card_type(@project, BUG, :properties => [STATUS])
    tree = setup_tree(@project, 'simple tree', :types => [story_type, bug_type], :relationship_names => ['relation - story'])
    aggregate = setup_aggregate_property_definition('bug count', AggregateType::COUNT, nil, tree.id, story_type.id, bug_type)

    story1_card = create_card!(:name => 'story 1', :type => story_type.name)
    story2_card = create_card!(:name => 'story 2', :type => story_type.name)
    bug_card = create_card!(:name => 'bug 1', :type => bug_type.name)
    add_card_to_tree(tree, story1_card)
    add_card_to_tree(tree, bug_card, story1_card)

    login_as_read_only_team_member
    open_card(@project, story2_card)
    assert_card_belongs_to_or_not_message_on_card_show_for(tree, THIS_CARD_AWAILABLE_TO_TREE)
    assert_view_tree_link_present(tree)
  end

  # card list related tests
  def test_read_only_team_member_should_not_be_able_to_quickadd_add_wtih_detail_bulk_edit_manage_tree_link_on_card_list_view
    login_as_read_only_team_member
    navigate_to_card_list_for(@project)
    assert_bulk_edit_action_not_present_on_list_view
    assert_quick_add_not_visible
    assert_import_to_excel_link_not_present
    assert_export_to_excel_link_present
  end

  def test_read_only_team_member_should_be_able_to_see_print_link_to_this_page_add_remove_columns_and_grid_link_export_link
    login_as_read_only_team_member
    navigate_to_card_list_for(@project)
    assert_print_link_to_this_page_and_add_remove_columns_links_present_for_list_view
    assert_view_navigation_link_present(@project, :view => 'grid')
    assert_export_to_excel_link_present

    add_column_for(@project, [TYPE])
    assert_column_present_for(TYPE)
  end

  def test_read_only_user_should_be_able_to_view_favorites_on_list_view
    card_open_status = create_card!(:name => 'status open card', STATUS => OPEN)
    card_closed_status = create_card!(:name => 'status closed card', STATUS => CLOSED)
    navigate_to_card_list_for(@project)
    add_new_filter
    set_the_filter_property_and_value(1, :property => STATUS, :value => OPEN)
    favorite = create_card_list_view_for(@project, 'status open view')
    login_as_read_only_team_member
    navigate_to_card_list_for(@project)
    assert_card_favorites_link_present(favorite.name)

    open_saved_view(favorite.name)
    assert_card_present_in_list(card_open_status)
    assert_card_not_present_in_list(card_closed_status)
    assert_filter_set_for(1, STATUS => OPEN)
  end

  def test_read_only_user_should_be_able_to_set_filters_on_list_view
    card_open_status = create_card!(:name => 'status open card', STATUS => OPEN)
    card_closed_status = create_card!(:name => 'status closed card', STATUS => CLOSED)
    login_as_read_only_team_member
    navigate_to_card_list_for(@project)

    add_new_filter
    set_the_filter_property_and_value(1, :property => STATUS, :value => OPEN)
    assert_card_present_in_list(card_open_status)
    assert_card_not_present_in_list(card_closed_status)

    set_the_filter_value_option(1, CLOSED)
    assert_card_present_in_list(card_closed_status)
    assert_card_not_present_in_list(card_open_status)
  end

  def test_read_only_user_can_export_to_excel
    expected = %{Number,Name,Description,Type,estimate,final estimate,iteration,owner,size,start date,status,Created by,Modified by,Tags,Incomplete Checklist Items,Completed Checklist Items
3,status closed card,,Card,,,,,,,closed,admin,admin,"","",""
2,status open card,,Card,,,,,,,open,admin,admin,"","",""
1,card1,,Card,,,,,,,,admin,admin,new_tag,"",""}
    card_open_status = create_card!(:name => 'status open card', STATUS => OPEN)
    card_closed_status = create_card!(:name => 'status closed card', STATUS => CLOSED)
    login_as_read_only_team_member
    navigate_to_card_list_for(@project)
    export_all_columns_to_excel_with_description
    assert_equal_ignore_cr(expected, get_exported_data)
  end

  # Grid view related tests
  def test_read_only_user_should_have_group_by_color_and_sort_by_lane_headings_and_link_to_this_page_on_grid_view_and_can_add_remove_lanes
    login_as_read_only_team_member
    navigate_to_grid_view_for(@project)
    assert_grid_view_actions_bar_present
    assert_link_to_this_page_link_present
    assert_view_navigation_link_present(@project, :view => 'list')
    assert_export_to_excel_link_present

    group_columns_by(STATUS)
    assert_lane_not_present(STATUS,OPEN)
    add_lanes(@project, STATUS, [OPEN])
    assert_lane_present(STATUS,OPEN)
  end

  def test_read_only_user_should_be_able_to_group_by_color_by_and_able_to_change_lane_headings
    card_open_status = create_card!(:name => 'status open card', STATUS => OPEN, ESTIMATE => '1')
    card_closed_status = create_card!(:name => 'status closed card', STATUS => CLOSED, ESTIMATE => '3')
    login_as_read_only_team_member
    navigate_to_grid_view_for(@project)
    group_columns_by(STATUS)
    assert_card_in_lane(STATUS, OPEN, card_open_status.number)
    color_by(ESTIMATE)
    assert_color_legend_contains_type('1')
    assert_color_legend_contains_type('3')
    assert_color_legend_contains_type('5')
    assert_color_leged_popup_not_present_for(@project, ESTIMATE, '1')
  end

  # Tree view related tests
  def test_read_only_team_member_should_not_have_configure_delete_create_new_card_tree_link_on_tree_management_page
    story_type = setup_card_type(@project, STORY, :properties => [STATUS, SIZE, ESTIMATE, OWNER, START_DATE, @formula_property.name])
    bug_type = setup_card_type(@project, BUG, :properties => [STATUS])
    tree = setup_tree(@project, 'tree1', :types => [story_type, bug_type], :relationship_names => ['relation - story'])
    story_card = create_card!(:name => 'story 1', :type => story_type.name)
    bug_card = create_card!(:name => 'bug 1', :type => bug_type.name)
    add_card_to_tree(tree, story_card)
    add_card_to_tree(tree, bug_card, story_card)
    login_as_read_only_team_member
    navigate_to_tree_configuration_management_page_for(@project)
    assert_configure_delete_create_new_tree_link_not_present(@project, tree)
  end

  def test_read_only_team_member_should_have_tree_view_hierachy_view_link_on_tree_management_page
    story_type = setup_card_type(@project, STORY, :properties => [STATUS, SIZE, ESTIMATE, OWNER, START_DATE, @formula_property.name])
    bug_type = setup_card_type(@project, BUG, :properties => [STATUS])
    tree = setup_tree(@project, 'tree1', :types => [story_type, bug_type], :relationship_names => ['relation - story'])
    story_card = create_card!(:name => 'story 1', :type => story_type.name)
    bug_card = create_card!(:name => 'bug 1', :type => bug_type.name)
    add_card_to_tree(tree, story_card)
    add_card_to_tree(tree, bug_card, story_card)
    login_as_read_only_team_member
    navigate_to_tree_configuration_management_page_for(@project)
    assert_tree_and_hierarchy_view_navigation_link_present_on_tree_management_page
  end

  def test_read_only_team_member_should_have_select_tree_tree_view_tool_card_views_tool_bar_link_to_this_page_quick_search_tree_filter_on_tree_view
    story_type = setup_card_type(@project, STORY, :properties => [STATUS, SIZE, ESTIMATE, OWNER, START_DATE, @formula_property.name])
    bug_type = setup_card_type(@project, BUG, :properties => [STATUS])
    tree = setup_tree(@project, 'tree1', :types => [story_type, bug_type], :relationship_names => ['relation - story'])
    story_card = create_card!(:name => 'story 1', :type => story_type.name)
    bug_card = create_card!(:name => 'bug 1', :type => bug_type.name)
    add_card_to_tree(tree, story_card)
    add_card_to_tree(tree, bug_card, story_card)
    login_as_read_only_team_member
    navigate_to_tree_view_for(@project,tree.name, [])
    assert_tree_selected(tree.name)
    assert_tree_view_tool_bar_present
    assert_view_as_links_present_for(@project, tree, :view => 'List')
    assert_view_as_links_present_for(@project, tree, :view => 'Grid')
    assert_view_as_links_present_for(@project, tree, :view => 'Hierarchy')
    assert_link_to_this_page_link_present
    assert_quick_search_on_tree_present
    assert_tree_filter_present
    assert_export_to_excel_link_present
  end

  def test_read_only_team_member_should_not_have_quick_add_remove_node_configure_current_manage_trees_links_on_tree_view
    story_type = setup_card_type(@project, STORY, :properties => [STATUS, SIZE, ESTIMATE, OWNER, START_DATE, @formula_property.name])
    bug_type = setup_card_type(@project, BUG, :properties => [STATUS])
    tree = setup_tree(@project, 'tree1', :types => [story_type, bug_type], :relationship_names => ['relation - story'])
    story_card = create_card!(:name => 'story 1', :type => story_type.name)
    bug_card = create_card!(:name => 'bug 1', :type => bug_type.name)
    add_card_to_tree(tree, story_card)
    add_card_to_tree(tree, bug_card, story_card)
    login_as_read_only_team_member
    navigate_to_tree_view_for(@project,tree.name)

    assert_quick_add_link_not_present_on_card(story_card)
    assert_remove_card_link_not_present_on_card_in_tree_view(story_card)
    assert_quick_add_link_not_present_on_card(bug_card)
    assert_remove_card_link_not_present_on_card_in_tree_view(bug_card)

    assert_link_configure_tree_not_present_on_current_tree_configuration_widget
    assert_import_to_excel_link_not_present
  end

  def test_read_only_team_member_should_be_able_to_use_select_tree_link_to_navigate_tree
    story_type = setup_card_type(@project, STORY, :properties => [STATUS, SIZE, ESTIMATE, OWNER, START_DATE, @formula_property.name])
    bug_type = setup_card_type(@project, BUG, :properties => [STATUS])
    tree1 = setup_tree(@project, 'tree1', :types => [story_type, bug_type], :relationship_names => ['relation - story'])
    tree2 = setup_tree(@project, 'tree2', :types => [story_type, bug_type], :relationship_names => ['relation - story'])
    story_card = create_card!(:name => 'story 1', :type => story_type.name)
    bug_card = create_card!(:name => 'bug 1', :type => bug_type.name)
    add_card_to_tree(tree1, story_card)
    add_card_to_tree(tree1, bug_card, story_card)

    login_as_read_only_team_member
    navigate_to_tree_view_for(@project,tree1.name)
    assert_current_tree_on_view(tree1.name)
    select_tree(tree2.name)
    assert_current_tree_on_view(tree2.name)
  end

  def test_read_only_team_member_be_able_to_view_favorites_not_able_to_manage_updates_them_on_tree_view
    story_type = setup_card_type(@project, STORY, :properties => [STATUS, SIZE, ESTIMATE, OWNER, START_DATE, @formula_property.name])
    bug_type = setup_card_type(@project, BUG, :properties => [STATUS])
    tree1 = setup_tree(@project, 'tree1', :types => [story_type, bug_type], :relationship_names => ['relation - story'])
    tree2 = setup_tree(@project, 'tree2', :types => [story_type, bug_type], :relationship_names => ['relation - story'])
    story_card = create_card!(:name => 'story 1', :type => story_type.name)
    bug_card = create_card!(:name => 'bug 1', :type => bug_type.name)
    add_card_to_tree(tree1, story_card)
    add_card_to_tree(tree1, bug_card, story_card)
    navigate_to_tree_view_for(@project,tree1.name)
    favorite = create_card_list_view_for(@project, 'tree1')
    wait_for_tree_result_load
    login_as_read_only_team_member
    open_saved_view(favorite.name)
    wait_for_tree_result_load
    assert_current_tree_on_view(tree1.name)
    navigate_to_tree_view_for(@project,tree2.name)
    wait_for_tree_result_load
    assert_current_tree_on_view(tree2.name)
    assert_favorites_not_be_able_to_edit_or_update(favorite.name)
  end

  def test_read_only_user_can_filter_tree_view
    story_type = setup_card_type(@project, STORY, :properties => [STATUS, SIZE, ESTIMATE, OWNER, START_DATE, @formula_property.name])
    bug_type = setup_card_type(@project, BUG, :properties => [STATUS])
    tree = setup_tree(@project, 'tree1', :types => [story_type, bug_type], :relationship_names => ['relation - story'])
    story_card1 = create_card!(:name => 'story 1', :type => story_type.name)
    story_card2 = create_card!(:name => 'story 2', :type => story_type.name)
    bug_card = create_card!(:name => 'bug 1', :type => bug_type.name)
    add_card_to_tree(tree, [story_card1, story_card2])
    add_card_to_tree(tree, bug_card, story_card1)
    login_as_read_only_team_member
    navigate_to_tree_view_for(@project, tree.name)
    set_tree_filter_for(story_type, 0, :property => 'relation - story', :value => story_card2.number)
    assert_cards_showing_on_tree(story_card2)
    assert_cards_not_showing_on_tree(story_card1, bug_card)
  end

  # Hierarchy view related tests
  def test_read_only_team_member_should_have_select_tree_card_views_tool_bar_link_to_this_page_print_link_add_remove_columns_tree_filter_on_hierarchy_view
    story_type = setup_card_type(@project, STORY, :properties => [STATUS, SIZE, ESTIMATE, OWNER, START_DATE, @formula_property.name])
    bug_type = setup_card_type(@project, BUG, :properties => [STATUS])
    tree = setup_tree(@project, 'tree1', :types => [story_type, bug_type], :relationship_names => ['relation - story'])
    story_card = create_card!(:name => 'story 1', :type => story_type.name)
    bug_card = create_card!(:name => 'bug 1', :type => bug_type.name)
    add_card_to_tree(tree, story_card)
    add_card_to_tree(tree, bug_card, story_card)
    login_as_read_only_team_member
    navigate_to_hierarchy_view_for(@project, tree)

    assert_tree_selected(tree.name)
    assert_view_as_links_present_for(@project, tree, :view => 'List')
    assert_view_as_links_present_for(@project, tree, :view => 'Grid')
    assert_view_as_links_present_for(@project, tree, :view => 'Tree')
    assert_link_to_this_page_link_present
    assert_print_link_to_this_page_and_add_remove_columns_links_present_for_list_view
    assert_tree_filter_present
    assert_export_to_excel_link_present
  end

  def test_read_only_team_member_should_not_have_configure_current_manage_trees_links_on_hierarchy_view
    story_type = setup_card_type(@project, STORY, :properties => [STATUS, SIZE, ESTIMATE, OWNER, START_DATE, @formula_property.name])
    bug_type = setup_card_type(@project, BUG, :properties => [STATUS])
    tree = setup_tree(@project, 'tree1', :types => [story_type, bug_type], :relationship_names => ['relation - story'])
    story_card = create_card!(:name => 'story 1', :type => story_type.name)
    bug_card = create_card!(:name => 'bug 1', :type => bug_type.name)
    add_card_to_tree(tree, story_card)
    add_card_to_tree(tree, bug_card, story_card)
    login_as_read_only_team_member
    navigate_to_hierarchy_view_for(@project, tree)

    assert_link_configure_tree_not_present_on_current_tree_configuration_widget
    assert_import_to_excel_link_not_present
  end

  def test_read_only_team_member_should_be_able_to_expand_collapes_cards_in_hierarchy_view
    story_type = setup_card_type(@project, STORY, :properties => [STATUS, SIZE, ESTIMATE, OWNER, START_DATE, @formula_property.name])
    bug_type = setup_card_type(@project, BUG, :properties => [STATUS])
    tree = setup_tree(@project, 'tree1', :types => [story_type, bug_type], :relationship_names => ['relation - story'])
    story_card = create_card!(:name => 'story 1', :type => story_type.name)
    bug_card = create_card!(:name => 'bug 1', :type => bug_type.name)
    add_card_to_tree(tree, story_card)
    add_card_to_tree(tree, bug_card, story_card)
    login_as_read_only_team_member
    navigate_to_hierarchy_view_for(@project, tree)

    click_twisty_for(story_card)
    @browser.assert_element_present(class_locator('expanded'))
    click_twisty_for(story_card)
    @browser.assert_element_present(class_locator('collapsed'))
  end

  # Wiki related tests
  def test_read_only_user_should_not_create_edit_delete_make_favorite_or_tab_and_tags_for_wiki_pages
    overview_content = "this is a overview page \\n [[link1]]"
    link1_content = "this is a link1 page with link [[link2]]"
    navigate_to_project_overview_page(@project)
    add_content_to_wiki(overview_content)
    create_new_wiki_page(@project, 'link1', link1_content)

    login_as_read_only_team_member
    navigate_to_project_overview_page(@project)
    assert_links_not_present_on_wiki_page
    click_link('link1')
    assert_opened_wiki_page('link1')
    assert_links_not_present_on_wiki_page
    assert_non_existant_wiki_link_present

    open_new_wiki_page_for_edit(@project, 'link2')
    assert_error_message("Read only team members do not have access rights to create pages")
  end

  def test_read_only_user_should_have_feeds_history_and_recently_view_pages
    overview_content = "this is a overview page \\n [[link1]]"
    link1_content = "this is a link1 page with link [[link2]]"
    navigate_to_project_overview_page(@project)
    add_content_to_wiki(overview_content)
    create_new_wiki_page(@project, 'link1', link1_content)
    @browser.run_once_history_generation
    login_as_read_only_team_member
    navigate_to_project_overview_page(@project)
    click_link('link1')
    load_page_history
    assert_links_present_on_recently_viewed_page_for(@project, 'Overview Page')
    assert_index_of_pages_link_present
    assert_page_history_for(:page, 'link1').version(1).shows(:message => 'Content changed')
    assert_subscription_via_email_and_feeds_links_presnet
  end

  def ignored_test_read_only_team_member_should_not_be_able_to_see_special_headers
    create_special_header_for_creating_new_card(@project, CARD)
    login_as_read_only_team_member
    assert_special_header_not_present(CARD)
  end

  # bug 6230
  def test_read_only_team_member_should_not_be_able_to_see_ranking_turn_on_off_button
    login_as_read_only_team_member
    navigate_to_grid_view_for(@project)
    assert_ranking_option_button_is_not_present
  end

  def ignored_test_read_only_team_member_should_be_able_to_see_action_links_in_special_header_actions_wiki_page
    create_special_header_for_creating_new_card(@project, CARD)
    login_as_read_only_team_member
    open_wiki_page(@project, SPECIAL_HEADER_ACTIONS)
    assert_special_header_present(CARD)
  end

  def test_advanced_admin_page_is_not_visiable_for_project_read_only_user
    login_as_read_only_team_member
    open_project_admin_for(@project)
    assert_advanced_project_admin_link_is_not_present
  end

  def test_readonly_user_should_be_able_to_select_all_cards_from_card_list
    login_as_read_only_team_member
    navigate_to_card_list_for(@project)
    select_all
    assert_card_checked(@card1)
  end

  def test_readonly_user_should_not_able_to_see_the_quick_add_card
    login_as_read_only_team_member
    navigate_to_grid_view_for(@project)
    assert_quick_add_card_is_invisible
  end

  # Story 12754 -quick add on funky tray
  def test_read_only_user_should_not_be_able_to_quick_add_card
    login_as_read_only_team_member
    navigate_to_card_list_for(@project)
    assert_quick_add_link_not_present_on_funky_tray
  end


  ########################
  # following tests are related with #4585,
  # they could not work,because of the issues of selenium (could not get http reference when redirected)
  #########################
  # def test_read_only_team_member_should_not_be_able_to_create_cards_via_link
  #   create_special_header_for_creating_new_card(@project, CARD)
  #   login_as_read_only_team_member
  #   open_wiki_page(@project, SPECIAL_HEADER_ACTIONS)
  #
  #   assert_special_header_present(CARD)
  #   location = @browser.get_location
  #   p location
  #   @browser.click_and_wait("link=+Card")
  #   assert_redirected_to_with_error(location, ERROR_MESSAGE_FOR_CREATE_CARD_OR_WIKI_VIA_LINK)
  # end
  #
  #  def test_read_only_team_member_should_not_be_able_to_create_cards_via_url
  #    login_as_read_only_team_member
  #    @browser.open("/#{@project.identifier}/cards/new?properties[Type]=Card")
  #    location = "/projects/#{@project.identifier}"
  #    assert_redirected_to_with_error(location, ERROR_MESSAGE_FOR_CREATE_CARD_VIA_URL)
  #  end
  #
  #  def test_read_only_team_member_should_not_be_able_to_create_wiki_page_via_link
  #    link1_content = "this is a link1 page with link [[link2]]"
  #    create_new_wiki_page(@project, 'link1', link1_content)
  #    login_as_read_only_team_member
  #    open_wiki_page(@project,'link1')
  #    click_link('link2')
  #    location = @browser.get_location
  #    assert_redirected_to_with_error(location, ERROR_MESSAGE_FOR_CREATE_CARD_OR_WIKI_VIA_LINK)
  #  end
  #
  #
  #  def test_read_only_team_member_should_not_be_able_to_create_wiki_page_via_url
  #    new_wiki_name = 'new'
  #    login_as_read_only_team_member
  #    open_new_wiki_page_for_edit(@project)
  #    location = "/projects/#{@project.identifier}"
  #    assert_redirected_to_with_error(location, ERROR_MESSAGE_FOR_CREATE_WIKI_PAGE_VIA_URL)
  #  end


  private

  def assert_subscription_via_email_and_feeds_links_presnet
    @browser.assert_element_present('subscribe-link')
    @browser.assert_element_present('subscribe-via-email')
  end

  def assert_links_present_for_read_only_user_on_card_show
    assert_card_context_present
    assert_subscription_via_email_and_feeds_links_presnet
    @browser.assert_element_present('up')
    @browser.assert_element_present(class_locator('page-help-at-card-show', 0))
  end

  def assert_links_not_present_for_read_only_user_on_card_show_page
    @browser.assert_element_not_present(class_locator('edit', 0))
    @browser.assert_element_not_present(class_locator('edit', 1))
    assert_link_not_present("/projects/#{@project.identifier}/cards/#{@card1.id}/destroy")
    assert_edit_tags_link_not_present
    @browser.assert_text_not_present('Add description')
    @browser.assert_element_not_present("transition_#{@transition.id}")
    @browser.assert_element_not_present('card_comment')
    @browser.assert_element_not_present('add_comment')
    assert_link_not_present("/projects/#{@project.identifier}/favorites/manage_favorites_and_tabs")
    assert_manage_favorites_and_tabs_link_not_present
  end

  def assert_configure_delete_create_new_tree_link_not_present(project, tree)
    @browser.assert_element_not_present('link=Configure')
    @browser.assert_element_not_present('link=Delete')
    @browser.assert_element_not_present('link=Create new card tree')
  end

  def assert_links_not_present_on_wiki_page
    assert_edit_tags_link_not_present
    @browser.assert_element_not_present(class_locator('edit', 0))
    @browser.assert_element_not_present(class_locator('edit', 1))
    @browser.assert_element_not_present(class_locator('delete', 0))
    @browser.assert_element_not_present(class_locator('delete', 1))
    @browser.assert_element_not_present('link=Make team favorite')
    @browser.assert_element_not_present('link=Make tab')
  end

  def login_as_read_only_team_member
    login_as(@read_only_user.login)
  end

  def assert_favorites_not_be_able_to_edit_or_update(favorite_name)
    @browser.assert_element_not_present('view-save-link')
    @browser.assert_element_not_present(class_locator('tab-small'))
    @browser.assert_element_not_present(class_locator('icon', 0))
  end
end
