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
require File.expand_path(File.dirname(__FILE__) + '/card_tree_acceptance_support.rb')

#Tags: tree-view
class Scenario69CardTreeUsage1Test < ActiveSupport::TestCase

  include CardTreeAcceptanceSupport

  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_admin_user = users(:longbob)
    @member = users(:project_member)
    @project_admin_user = users(:proj_admin)
    admin = login_as_admin_user

    @project = with_new_project(:prefix => 'scenario_69', :users => [@non_admin_user, @member], :admins => [@project_admin_user, users(:admin)]) do |project|
      setup_property_definitions(PRIORITY => ['high', LOW], SIZE => [1, 2, 4], STATUS => [NEW, CLOSED, OPEN], ITERATION => [1, 2, 3, 4], OWNER => ['a', 'b', 'c'])
      @type_story = setup_card_type(project, STORY, :properties => [PRIORITY, SIZE, ITERATION, OWNER])
      @type_defect = setup_card_type(project, DEFECT, :properties => [PRIORITY, STATUS, OWNER])
      @type_task = setup_card_type(project, TASK, :properties => [PRIORITY, SIZE, ITERATION, STATUS, OWNER])
      @type_iteration = setup_card_type(project, ITERATION_TYPE)
      @type_release = setup_card_type(project, RELEASE)
      @r1 = create_card!(:name => 'release 1', :description => "Without software, most organizations could not survive in the current marketplace see bug100", :card_type => RELEASE)
      @r2 = create_card!(:name => 'release 2', :card_type => RELEASE)
      @i1 = create_card!(:name => 'iteration 1', :card_type => ITERATION_TYPE)
      @i2 = create_card!(:name => 'iteration 2', :card_type => ITERATION_TYPE)
      @stories = create_cards(project, 5, :card_type => @type_story)
      @tasks = create_cards(project, 2, :card_type => @type_task)
      @tree = setup_tree(project, 'planning tree', :types => [@type_release, @type_iteration, @type_story, @type_task], :relationship_names => [RELATION_PLANNING_RELEASE, RELATION_PLANNING_ITERATION, RELATION_PLANNING_STORY])
    end
    navigate_to_card_list_for(@project)
  end

  #Story 8306 - Make card number on a popup as a link to card
  def test_should_have_card_number_as_link_on_card_popup_in_normal_tree_view
    add_card_to_tree(@tree, @r1)
    add_card_to_tree(@tree, @i1, @r1)
    navigate_to_tree_view_for(@project, @tree.name)
    click_on_card_in_tree(@i1)
    assert_popup_present_for_card_on_tree_view(@i1)
    @browser.assert_element_present("card_show_link_on_popup_#{@i1.number}")
    @browser.click_and_wait("card_show_link_on_popup_#{@i1.number}")
    assert_card_location_in_card_show(@project, @i1)
    assert_card_name_in_show(@i1.name)
  end

  pending "Flaky on the build. Clicking on popup on card tree fails randomly"
  def test_should_have_card_number_as_link_on_card_popup_in_maxmized_tree_view
    add_card_to_tree(@tree, @r1)
    add_card_to_tree(@tree, @i1, @r1)
    navigate_to_tree_view_for(@project, @tree.name)
    maximize_current_view
    click_on_card_in_tree(@i1)
    assert_popup_present_for_card_on_tree_view(@i1)
    @browser.assert_element_present("card_show_link_on_popup_#{@i1.number}")
    @browser.click_and_wait("card_show_link_on_popup_#{@i1.number}")
    assert_card_location_in_card_show(@project, @i1)
    assert_card_name_in_show(@i1.name)
  end

  #bug 5594
  def test_I_can_use_card_type_that_with_multiple_spaces_in_its_name
    add_card_to_tree(@tree, @r1)
    edit_card_type_for_project(@project, RELEASE, :new_card_type_name => '2.2 -  release type')
    navigate_to_tree_view_for(@project, @tree.name)
    assert_cards_on_a_tree(@project, @r1)
  end

  #4926
  def test_usr_should_able_to_view_card_popup_after_drag_and_drop_it
    add_card_to_tree(@tree, @r1)
    add_card_to_tree(@tree, @r2)
    add_card_to_tree(@tree, @i1, @r1)
    add_card_to_tree(@tree, @i2, @r2)
    navigate_to_tree_view_for(@project, @tree.name)
    drag_and_drop_card_in_tree(@r1, @i2)
    navigate_to_tree_view_for(@project, @tree.name)
    click_on_card_in_tree(@i2)
    assert_popup_present_for_card_on_tree_view(@i2)
  end

  def test_navigation_through_card_list_view_in_a_project_with_no_trees_defined
    another_project = create_project(:prefix => 'trees')
    navigate_to_card_list_by_clicking(another_project)
    assert_no_configured_trees_for_a_project_on_select_tree_widget
    navigate_to_tree_configuration_management_page_for(another_project)
    @browser.assert_text_present("There are currently no trees to list. You can create a new tree from the action bar.")
  end

  def test_navigation_from_list_to_tree_view
    navigate_to_card_list_for(@project)
    select_tree(@tree.name)
    assert_switch_to_tree_view_link_present_on_action_bar
    switch_to_tree_view_through_action_bar
    assert_current_tree_on_view(@tree.name)

    select_tree(NONE)
    assert_switch_to_tree_view_link_not_present_on_action_bar
  end

  def test_trees_can_set_as_favorites_and_tabs
    add_card_to_tree(@tree, @r1)
    add_card_to_tree(@tree, @r2)
    navigate_to_card_list_for(@project)
    select_tree(@tree.name)
    switch_to_tree_view_through_action_bar
    tree_view = create_card_list_view_for(@project, 'Planning')
    assert_card_favorites_link_present(tree_view.name)

    navigate_to_favorites_management_page_for(@project)
    assert_card_favorites_present_on_management_page(@project, tree_view)
    @browser.assert_text_present('tree')

    toggle_tab_for_saved_view(tree_view)
    assert_tab_present(tree_view.name)
    click_tab(tree_view.name)
    wait_for_tree_result_load
    assert_current_tree_on_view(@tree.name)
  end

  def test_select_trees_widget_displays_all_trees_available
    tree2 = setup_tree(@project, 'Planning 2', :types => [@type_iteration, @type_story], :relationship_names => ['Planning 2 iteration'])
    tree3 = setup_tree(@project, 'Planning 3', :types => [@type_story, @type_task], :relationship_names => ['Planning 3 story'])
    navigate_to_card_list_for(@project)
    assert_trees_available_in_select_trees_drop_down_for(@project, @tree.name, tree2.name, tree3.name)
  end

  def test_project_member_should_not_have_configure_current_tree
    add_card_to_tree(@tree, @r1)
    navigate_to_card_list_for(@project)
    select_tree(@tree.name)
    assert_link_configure_tree_on_current_tree_configuration_widget
    login_as(@non_admin_user.login, 'longtest')
    navigate_to_card_list_for(@project)
    select_tree(@tree.name)
    assert_link_configure_tree_not_present_on_current_tree_configuration_widget
  end

  def test_using_relationship_properties_on_pivote_table
    get_planning_tree_generated_with_cards_on_tree
    edit_overview_page
    table_one = add_pivot_table_query_and_save_for(RELATION_PLANNING_RELEASE, RELATION_PLANNING_ITERATION, :empty_rows => 'true', :empty_columns => 'true', :totals => 'true')
    assert_table_row_data_for(table_one, :row_number => 1, :cell_values => ['7', '', '1'])
    assert_table_row_data_for(table_one, :row_number => 4, :cell_values => ['7', '', '4'])
  end

  def test_using_relationship_properties_on_table_query
    get_planning_tree_generated_with_cards_on_tree
    edit_overview_page
    query = generate_table_query(['name', 'number', 'Type', "'#{RELATION_PLANNING_RELEASE}'", "'#{RELATION_PLANNING_ITERATION}'", "'#{RELATION_PLANNING_STORY}'"])
    create_free_hand_macro(query)
    @browser.click SharedFeatureHelperPageId::SAVE_LINK
    @browser.wait_for_element_not_present SharedFeatureHelperPageId::SAVE_LINK
    @browser.wait_for_element_present 'page-content'
    assert_table_row_data_for('', :row_number => 1, :cell_values => ['card 2', '11', @type_task.name, card_number_and_name(@r1), card_number_and_name(@i1), card_number_and_name(@stories[1])])
  end

  def test_deleting_tree_will_remove_all_relationship_andaggregate_properties_from_project
    get_planning_tree_generated_with_cards_on_tree
    aggregate_story_count_for_release = setup_aggregate_property_definition('stroy count for release', AggregateType::COUNT, nil, @tree.id, @type_release.id, @type_story)
    pivot_table_query = generate_pivot_table_query(RELATION_PLANNING_RELEASE, RELATION_PLANNING_ITERATION, :empty_rows => 'true', :empty_columns => 'true', :totals => 'true')
    table_query_1 = generate_table_query(['name', 'number', 'Type', "'#{RELATION_PLANNING_RELEASE}'", "'#{RELATION_PLANNING_ITERATION}'", "'#{RELATION_PLANNING_STORY}'"])
    table_query_2 = generate_table_query(['name', 'number', 'Type', "'#{aggregate_story_count_for_release.name}'"])

    edit_overview_page
    create_free_hand_macro(pivot_table_query)
    create_free_hand_macro(table_query_1)
    paste_query_and_save(table_query_2)

    delete_tree_configuration_for(@project, @tree)
    @project.reload
    click_overview_tab
    assert_text_present("No such property: Planning tree - release")
    assert_text_present("Error in table macro using #{@project.name} project: Card property 'Planning tree - release' does not exist!")
    assert_text_present("Error in table macro using #{@project.name} project: Card property 'stroy count for release' does not exist!")
  end

  def test_deleting_tree_should_remove_saved_view_and_tabs_related_to_tree
    planning_tree = @tree.name
    get_planning_tree_generated_with_cards_on_tree
    navigate_to_tree_view_for(@project, @tree.name)
    planning_tree_view = create_card_list_view_for(@project, planning_tree)
    navigate_to_tree_configuration_management_page_for(@project)
    delete_tree_configuration_for(@project, @tree)
    navigate_to_favorites_management_page_for(@project)
    assert_favorites_not_present_on_management_page(@project, planning_tree_view)
  end

end
