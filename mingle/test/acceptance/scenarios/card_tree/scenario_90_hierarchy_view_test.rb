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

# Tags: scenario, tree-usage, card-selector
class Scenario90HierarchyViewTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  STATUS = 'status'
  NEW = 'new'
  OPEN = 'open'
  SIZE = 'size'
  BLANK = ''
  NOT_SET = '(not set)'
  TYPE = 'Type'
  CREATED_BY = 'Created by'
  MODIFIED_BY = 'Modified by'

  TREE = 'Planning Tree'
  RELEASE_PROPERTY = 'Planning Tree release'
  ITERATION_PROPERTY = 'Planning Tree iteration'
  RELEASE = 'Release'
  ITERATION = 'Iteration'
  STORY = 'Story'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_member = users(:project_member)
    @project = create_project(:prefix => 'scenario_90', :admins => [users(:admin)], :users => [@project_member])
    @size_property = setup_numeric_property_definition(SIZE, [1, 2, 4])
    setup_property_definitions(STATUS => [NEW, OPEN])
    @type_story = setup_card_type(@project, STORY, :properties => [STATUS, SIZE])
    @type_iteration = setup_card_type(@project, ITERATION)
    @type_release = setup_card_type(@project, RELEASE)
    login_as_admin_user
    @release1 = create_card!(:name => 'release 1', :description => "super plan", :card_type => RELEASE)
    @release2 = create_card!(:name => 'release 2', :card_type => RELEASE)
    @iteration1 = create_card!(:name => 'iteration 1', :card_type => ITERATION)
    @iteration2 = create_card!(:name => 'iteration 2', :card_type => ITERATION)
    @story1 = create_card!(:name => 'story 1', :card_type => STORY, SIZE => '4')
    @story2 = create_card!(:name => 'story 2', :card_type => STORY, SIZE => '2')
    @tree = setup_tree(@project, TREE, :types => [@type_release, @type_iteration, @type_story], :relationship_names => [RELEASE_PROPERTY, ITERATION_PROPERTY])
  end


  def test_should_be_able_to_add_or_remove_columns_and_the_order_of_columns
    add_card_to_tree(@tree, @release1)
    navigate_to_hierarchy_view_for(@project, @tree)
    add_all_columns
    assert_column_present_for(TYPE,CREATED_BY,MODIFIED_BY,RELEASE_PROPERTY,ITERATION_PROPERTY,STATUS,SIZE)
    assert_columns_ordered(TYPE,ITERATION_PROPERTY,RELEASE_PROPERTY,SIZE,STATUS,CREATED_BY,MODIFIED_BY)

    remove_column_for(@project,[CREATED_BY,RELEASE_PROPERTY,ITERATION_PROPERTY,SIZE])
    assert_column_not_present_for(CREATED_BY,RELEASE_PROPERTY,ITERATION_PROPERTY,SIZE)
    assert_column_present_for(TYPE,MODIFIED_BY,STATUS)

    add_column_for(@project,[CREATED_BY,ITERATION_PROPERTY])
    assert_columns_ordered(TYPE,STATUS,MODIFIED_BY,CREATED_BY)
  end
  # Expand collpse nodes related tests
  # bug 4594
  def test_favorite_remember_node_expand_collapse_state_during_making_changes_on_tree_filter
    add_card_to_tree(@tree, @release1)
    add_card_to_tree(@tree, @release2)
    add_card_to_tree(@tree, @iteration1, @release1)
    add_card_to_tree(@tree, @iteration2, @release2)
    add_card_to_tree(@tree, @story1, @iteration1)
    add_card_to_tree(@tree, @story2, @iteration2)

    navigate_to_hierarchy_view_for(@project, @tree)
    click_twisty_for(@release2, @release1)
    click_twisty_for(@iteration1, @release1)
    click_exclude_card_type_checkbox(@type_release)
    set_tree_filter_for(@type_iteration, 0, :property => ITERATION_PROPERTY, :value => @iteration1.number)

    view_name = "r1,i2 collapsed; r2,i1,expanded;do not show r; i1 filtered"
    favorite = create_card_list_view_for(@project, view_name)
    open_favorites_for(@project, favorite.name)
  end

  def test_on_clicking_link_to_this_page_reflects_expand_collapse_state_on_url
    add_card_to_tree(@tree, @release1)
    add_card_to_tree(@tree, [@iteration1, @iteration2], @release1)
    add_card_to_tree(@tree, @story1, @iteration1)
    add_card_to_tree(@tree, @story2, @iteration2)
    navigate_to_hierarchy_view_for(@project, @tree)
    click_twisty_for(@release1, @iteration1)
    assert_nodes_expanded_in_hierarchy_view(@release1, @iteration1)
    click_link_to_this_page
    assert_location_url("/projects/#{@project.identifier}/cards/hierarchy?expands=#{@release1.number}%2C#{@iteration1.number}&tab=All&tree_name=#{TREE.to_s.gsub("\s", '+')}")

    click_twisty_for(@iteration1)
    assert_nodes_collapsed_in_hierarchy_view(@iteration1)
    assert_nodes_expanded_in_hierarchy_view(@release1)
    click_link_to_this_page
    assert_location_url("/projects/#{@project.identifier}/cards/hierarchy?expands=#{@release1.number}&tab=All&tree_name=#{TREE.to_s.gsub("\s", '+')}")
  end

  def test_remember_the_expand_collapse_state_on_add_remove_columns
    add_card_to_tree(@tree, @release1)
    add_card_to_tree(@tree, [@iteration1, @iteration2], @release1)
    add_card_to_tree(@tree, @story1, @iteration1)
    add_card_to_tree(@tree, @story2, @iteration2)
    navigate_to_hierarchy_view_for(@project, @tree)
    click_twisty_for(@release1, @iteration1)
    add_column_for(@project, [SIZE])
    assert_nodes_expanded_in_hierarchy_view(@release1, @iteration1)
    assert_nodes_collapsed_in_hierarchy_view(@iteration2)
    assert_order_of_cards_in_list_or_hierarchy_view(@release1, @iteration2, @iteration1, @story1)

    favorite = create_card_list_view_for(@project, 'my view')

    remove_column_for(@project, [@size_property])
    assert_column_not_present_for(SIZE)
    assert_nodes_expanded_in_hierarchy_view(@release1, @iteration1)
    assert_nodes_collapsed_in_hierarchy_view(@iteration2)
  end

  def test_favorites_remember_the_expand_collapse_state_in_hierarchy_view
    add_card_to_tree(@tree, @release1)
    add_card_to_tree(@tree, [@iteration1, @iteration2], @release1)
    add_card_to_tree(@tree, @story1, @iteration1)
    add_card_to_tree(@tree, @story2, @iteration2)
    navigate_to_hierarchy_view_for(@project, @tree)
    click_twisty_for(@release1, @iteration1)
    assert_nodes_expanded_in_hierarchy_view(@release1, @iteration1)
    assert_nodes_collapsed_in_hierarchy_view(@iteration2)

    favorite = create_card_list_view_for(@project, 'my view')
    reset_view
    open_favorites_for(@project, favorite.name)
    assert_nodes_expanded_in_hierarchy_view(@release1, @iteration1)
    assert_nodes_collapsed_in_hierarchy_view(@iteration2)
  end

  def test_navigate_between_different_view_in_the_same_tree_the_expanded_and_collapsed_state_will_be_remembered_in_hierarchy_view
    add_card_to_tree(@tree, @release1)
    add_card_to_tree(@tree, [@iteration1, @iteration2], @release1)
    add_card_to_tree(@tree, @story1, @iteration1)
    add_card_to_tree(@tree, @story2, @iteration2)
    navigate_to_hierarchy_view_for(@project, @tree)
    click_twisty_for(@release1, @iteration1)

    switch_to_grid_view
    switch_to_hierarchy_view
    assert_nodes_expanded_in_hierarchy_view(@release1, @iteration1)
    assert_nodes_collapsed_in_hierarchy_view(@iteration2)

    switch_to_list_view
    switch_to_hierarchy_view
    assert_nodes_expanded_in_hierarchy_view(@release1, @iteration1)
    assert_nodes_collapsed_in_hierarchy_view(@iteration2)

    switch_to_tree_view
    switch_to_hierarchy_view
    assert_nodes_expanded_in_hierarchy_view(@release1, @iteration1)
    assert_nodes_collapsed_in_hierarchy_view(@iteration2)
  end

  def test_navigate_between_different_trees_the_expanded_and_collapsed_state_will_be_remembered_in_hierarchy_view
    tree2 = setup_tree(@project, 'non planning tree', :types => [@type_release, @type_iteration, @type_story], :relationship_names => ['RELEASE_PROPERTY', 'ITERATION_PROPERTY'])
    add_card_to_tree(@tree, @release1)
    add_card_to_tree(@tree, [@iteration1, @iteration2], @release1)
    add_card_to_tree(@tree, @story1, @iteration1)
    add_card_to_tree(@tree, @story2, @iteration2)
    add_card_to_tree(tree2, @release1)
    add_card_to_tree(tree2, [@iteration1, @iteration2], @release1)
    add_card_to_tree(tree2, @story1, @iteration1)
    add_card_to_tree(tree2, @story2, @iteration2)
    navigate_to_hierarchy_view_for(@project, @tree)
    click_twisty_for(@release1, @iteration1)

    select_tree('None')
    select_tree(@tree.name)
    assert_nodes_expanded_in_hierarchy_view(@release1, @iteration1)
    assert_nodes_collapsed_in_hierarchy_view(@iteration2)
    select_tree(tree2.name)
    assert_nodes_collapsed_in_hierarchy_view(@release1)

    select_tree(@tree.name)
    assert_nodes_expanded_in_hierarchy_view(@release1, @iteration1)
    assert_nodes_collapsed_in_hierarchy_view(@iteration2)
  end

  def test_removing_card_type_should_delete_favorite_when_it_existed_at_the_time_of_favarite_creation_or_last_update
    add_card_to_tree(@tree, @release1)
    add_card_to_tree(@tree, @iteration1, @release1)
    add_card_to_tree(@tree, @story1, @iteration1)
    navigate_to_hierarchy_view_for(@project, @tree)
    click_twisty_for(@release1, @iteration1)
    favorite1 = create_card_list_view_for(@project, 'fav' ,:skip_clicking_all => true)
    remove_a_card_type_and_wait_on_confirmation_page(@project, @tree, @type_iteration)
    assert_info_box_light_present
    assert_info_box_light_message("The following 1 team favorite or tab will be deleted: #{favorite1.name}")
  end

  def test_removing_card_type_should_not_delete_favorite_when_it_did_not_exist_at_the_time_of_favarite_creation_or_last_update
    add_card_to_tree(@tree, @release1)
    add_card_to_tree(@tree, @iteration1, @release1)
    add_card_to_tree(@tree, @story1, @iteration1)
    navigate_to_hierarchy_view_for(@project, @tree)
    click_twisty_for(@release1, @iteration1)
    favorite1 = create_card_list_view_for(@project, 'fav' ,:skip_clicking_all => true)
    type_defect = setup_card_type(@project, 'Defect')
    new_tree_object = edit_card_tree_configuration(@project, @tree.name, :types => [@type_release.name, @type_iteration.name, type_defect.name, @type_story.name])
    @project.reload.activate
    defect = create_card!(:name => 'defect 1', :card_type => type_defect)
    add_card_to_tree(new_tree_object, defect, @release1)
    remove_a_card_type_and_wait_on_confirmation_page(@project, new_tree_object, type_defect)
    assert_info_box_light_present
    assert_info_box_light_message_not_present("The following 1 team favorite or tab will be deleted: #{favorite1.name}")
  end

  # column add remove and order related tests
  def test_cards_are_displayed_in_order_as_per_column_in_hierarchy_view
    story3 = create_card!(:name => 'story 3', :card_type => STORY, SIZE => '1')
    story4 = create_card!(:name => 'story 4', :card_type => STORY, SIZE => '2')
    add_card_to_tree(@tree, @release1)
    add_card_to_tree(@tree, [@iteration1, @iteration2], @release1)
    add_card_to_tree(@tree, [@story1, @story2], @iteration1)
    add_card_to_tree(@tree, [story3, story4], @iteration2)

    navigate_to_hierarchy_view_for(@project, @tree)
    click_twisty_for(@release1, @iteration1, @iteration2)
    assert_order_of_cards_in_list_or_hierarchy_view(@release1, @iteration2, story4, story3, @iteration1, @story2, @story1)

    add_column_for(@project, [@size_property])
    click_card_list_column_and_wait(SIZE)
    assert_order_of_cards_in_list_or_hierarchy_view(@release1, @iteration2, story3, story4, @iteration1, @story2, @story1)

    click_card_list_column_and_wait(SIZE)
    assert_order_of_cards_in_list_or_hierarchy_view(@release1, @iteration2, story4, story3, @iteration1, @story1, @story2)

    click_card_list_column_and_wait('Name')
    assert_order_of_cards_in_list_or_hierarchy_view(@release1, @iteration1, @story1, @story2, @iteration2, story3, story4)
  end

  def test_switching_between_list_and_hierarchy_view_remember_the_columns_and_sort_order
    story3 = create_card!(:name => 'story 3', :card_type => STORY, SIZE => '1')
    story4 = create_card!(:name => 'story 4', :card_type => STORY, SIZE => '2')
    add_card_to_tree(@tree, @release1)
    add_card_to_tree(@tree, [@iteration1, @iteration2], @release1)
    add_card_to_tree(@tree, [@story1, @story2], @iteration1)
    add_card_to_tree(@tree, [story3, story4], @iteration2)

    navigate_to_hierarchy_view_for(@project, @tree)
    click_twisty_for(@release1, @iteration1, @iteration2)
    add_column_for(@project, [@size_property])
    click_card_list_column_and_wait(SIZE)
    assert_order_of_cards_in_list_or_hierarchy_view(@release1, @iteration2, story3, story4, @iteration1, @story2, @story1)

    switch_to_list_view
    assert_order_of_cards_in_list_or_hierarchy_view(story3, story4, @story2, @story1)
  end

  # bug 4607
  def test_node_should_be_able_to_expand_in_hierarchy_view
    add_card_to_tree(@tree, @release1)
    add_card_to_tree(@tree, @iteration1, @release1)
    add_card_to_tree(@tree, @story1, @iteration1)
    navigate_to_hierarchy_view_for(@project, @tree)
    click_twisty_for(@release1, @iteration1)
    switch_to_tree_view
    remove_card_without_its_children_from_tree_for(@project, @tree.name, @story1, :already_on_tree_view => true)
    switch_to_hierarchy_view
    click_twisty_for(@release1)
    click_twisty_for(@release1) # clicking twice to collapse and expand it
    assert_nodes_expanded_in_hierarchy_view(@release1)
  end

  def test_twisty_shows_respective_children_on_hierarchy_view
    add_card_to_tree(@tree, @release1)
    add_card_to_tree(@tree, [@iteration1, @iteration2], @release1)
    add_card_to_tree(@tree, @story1, @iteration1)
    add_card_to_tree(@tree, @story2, @iteration2)
    navigate_to_hierarchy_view_for(@project, @tree)
    click_exclude_card_type_checkbox(@type_release)
    click_twisty_for(@iteration1)
    assert_card_present_in_hierarchy_view(@story1)
    click_twisty_for(@iteration2)
    assert_card_present_in_hierarchy_view(@story2)
  end

  def test_saved_view_will_hold_filter_conditions_for_trees_on_hierarchy
    add_card_to_tree(@tree, @release1)
    add_card_to_tree(@tree, [@iteration1, @iteration2], @release1)
    add_card_to_tree(@tree, @story1, @iteration1)
    add_card_to_tree(@tree, @story2, @iteration2)
    navigate_to_hierarchy_view_for(@project, @tree)
    click_exclude_card_type_checkbox(@type_release)
    set_tree_filter_for(@type_iteration, 0, :property => ITERATION_PROPERTY, :value => @iteration1.number)
    saved_view = create_card_list_view_for(@project, "hierarchy i1")
    reset_view
    open_saved_view(saved_view.name)
    assert_properties_present_on_card_tree_filter(@type_iteration, 0, ITERATION_PROPERTY => card_number_and_name(@iteration1))
    assert_card_type_excluded(@type_release)
  end

  def test_created_by_modified_by_columns_available_for_hirarchy_view
    add_card_to_tree(@tree, @release1)
    add_card_to_tree(@tree, [@iteration1, @iteration2], @release1)

    navigate_to_hierarchy_view_for(@project, @tree)
    assert_created_by_modified_by_present_on_add_remove_column_dropdown
  end

  def test_hierarchy_view_shows_union_of_properties_for_select_column_drop_down
    add_card_to_tree(@tree, @release1)
    add_card_to_tree(@tree, [@iteration1, @iteration2], @release1)

    navigate_to_hierarchy_view_for(@project, @tree)
    assert_properties_present_on_add_remove_column_dropdown(@project, [RELEASE_PROPERTY, ITERATION_PROPERTY, SIZE, STATUS])

    click_exclude_card_type_checkbox(@type_story)
    assert_properties_present_on_add_remove_column_dropdown(@project, [RELEASE_PROPERTY])
    assert_properties_not_present_on_add_remove_column_dropdown(@project, [SIZE, STATUS, ITERATION_PROPERTY])
  end

  # story 12584
  def test_should_be_able_to_quick_add_card_on_hirarchy_view
    card_name = "New Card"
    add_card_to_tree(@tree, @release1)
    add_card_to_tree(@tree, [@iteration1, @iteration2], @release1)

    navigate_to_hierarchy_view_for(@project, @tree)
    add_card_via_quick_add(card_name)
    new_card = find_card_by_name(card_name)
    assert_notice_message("Card ##{new_card.number} was successfully created, but is not shown because it does not match the current filter.", :escape => true)
  end

  #bug 4605
  def test_should_be_able_to_export_via_excel_through_hierarchy_view
    expected_export = %{Number,Name,Description,Type,size,status,Planning Tree,Planning Tree release,Planning Tree iteration,Created by,Modified by,Incomplete Checklist Items,Completed Checklist Items
1,release 1,super plan,Release,,,yes,,,admin,admin,"",""
4,iteration 2,,Iteration,,,yes,#1 release 1,,admin,admin,"",""
3,iteration 1,,Iteration,,,yes,#1 release 1,,admin,admin,"",""}
    add_card_to_tree(@tree, @release1)
    add_card_to_tree(@tree, [@iteration1, @iteration2], @release1)
    navigate_to_hierarchy_view_for(@project, @tree)
    export_all_columns_to_excel_with_description
    assert_equal_ignore_cr(expected_export, get_exported_data)
  end

  #bug 4605
  def test_cards_which_are_marked_as_do_not_show_in_hierarchy_view_would_not_be_exported
    expected_export = %{Number,Name,Description,Type,size,status,Planning Tree,Planning Tree release,Planning Tree iteration,Created by,Modified by,Incomplete Checklist Items,Completed Checklist Items
1,release 1,super plan,Release,,,yes,,,admin,admin,"",""
6,story 2,,Story,2,,yes,#1 release 1,#3 iteration 1,admin,admin,"",""
5,story 1,,Story,4,,yes,#1 release 1,#3 iteration 1,admin,admin,"",""}
    add_card_to_tree(@tree, @release1)
    add_card_to_tree(@tree, [@iteration1, @iteration2], @release1)
    add_card_to_tree(@tree, [@story1, @story2], @iteration1)
    navigate_to_hierarchy_view_for(@project, @tree)
    click_exclude_card_type_checkbox(@type_iteration)
    export_all_columns_to_excel_with_description
    assert_equal_ignore_cr(expected_export, get_exported_data)
  end

  # bug 3574
  def test_aggregate_properties_appear_in_column_selector_on_hierarchy_view
    release_size = setup_aggregate_property_definition('release size', AggregateType::SUM, @size_property, @tree.id, @type_release.id, AggregateScope::ALL_DESCENDANTS)
    add_card_to_tree(@tree, @release1)
    navigate_to_hierarchy_view_for(@project, @tree)
    add_column_for(@project, [release_size])
    assert_column_present_for(release_size.name)
  end

  # bug 3558
  def test_clicking_card_will_take_you_to_the_card_show_page
    add_card_to_tree(@tree, @release1)
    add_card_to_tree(@tree, [@iteration1, @iteration2], @release1)

    navigate_to_hierarchy_view_for(@project, @tree)
    click_card_on_hierarchy_list(@release1)
    assert_card_name_in_show(@release1.name)

    navigate_to_hierarchy_view_for(@project, @tree)
    click_twisty_for(@release1)
    click_card_on_hierarchy_list(@iteration1)
    assert_card_name_in_show(@iteration1.name)
  end

  # bug 3360
  def test_link_to_this_page_maintains_exclude_card_type_filters
    add_card_to_tree(@tree, @release1)
    add_card_to_tree(@tree, @iteration1, @release1)
    add_card_to_tree(@tree, @story1, @iteration1)

    navigate_to_hierarchy_view_for(@project, @tree)
    add_column_for(@project, %w(Type))
    click_exclude_card_type_checkbox(STORY)
    click_exclude_card_type_checkbox(ITERATION)

    click_link_to_this_page
    assert_card_type_excluded(STORY)
    assert_card_type_excluded(ITERATION)
    assert_card_type_not_excluded(RELEASE)
    assert_column_present_for('Type')
  end

  #bug 3396
  def test_leaf_node_cards_displayed_on_clicking_all_exclude_type_expect_leaf_node_type_on_filter
    add_card_to_tree(@tree, @release1)
    add_card_to_tree(@tree, [@iteration1, @iteration2], @release1)
    add_card_to_tree(@tree, @story1, @iteration1)
    navigate_to_hierarchy_view_for(@project, @tree)
    click_exclude_card_type_checkbox(@type_release)
    click_exclude_card_type_checkbox(@type_iteration)
    assert_card_present_in_hierarchy_view(@story1)
  end

  # bug 4630
  def test_on_favorites_should_be_able_to_updated_after_nodes_are_collapsed_in_hierarchy_view
    add_card_to_tree(@tree, @release1)
    add_card_to_tree(@tree, @iteration1, @release1)
    add_card_to_tree(@tree, @story1, @iteration1)
    navigate_to_hierarchy_view_for(@project, @tree)
    click_twisty_for(@release1, @iteration1)
    favorite = create_card_list_view_for(@project, 'my view')
    click_twisty_for(@iteration1, @release1)
    update_favorites_for(1)
    assert_nodes_collapsed_in_hierarchy_view(@release1)
  end

  # bug 4609
  def test_Scenario90HierarchyViewTestexpand_collapse_node_doesnot_make_all_tab_lose_reset_view_icon
    add_card_to_tree(@tree, @release1)
    add_card_to_tree(@tree, [@iteration1, @iteration2], @release1)
    navigate_to_hierarchy_view_for(@project, @tree)
    click_twisty_for(@release1)
    assert_reset_to_tab_default_link_present
  end
end
