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

# Tags: tree-usage, aggregate-properties

class Scenario77AggregatePropertiesUsageTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  PRIORITY = 'priority'
  STATUS = 'status'
  SIZE = 'size'
  SIZE2 = 'size2'
  ITERATION = 'iteration'
  OWNER = 'Zowner'
  START_DATE = 'start date'
  END_DATE = 'end date'

  RELEASE = 'Release'
  ITERATION_TYPE = 'Iteration'
  STORY = 'Story'
  DEFECT = 'Defect'
  TASK = 'Task'
  CARD = 'Card'

  RELEASE_PROPERTY = 'PT release'
  ITERATION_PROPERTY = 'PT iteration'
  STORY_PROPERTY = 'PT story'

  TYPE = 'Type'
  NEW = 'new'
  OPEN = 'open'
  LOW = 'low'

  SUM = 'Sum'
  COUNT = 'Count'
  AVERAGE = 'Average'

  PLANNING_TREE = 'planning tree'

  CALCULATED = '(calculated)'
  NOT_SET = '(not set)'
  FORMULA_USING_DATE = "'#{END_DATE}' - '#{START_DATE}'"
  FORMULA_USING_NUMERIC = "'#{SIZE}' * 2"
  FORMULA_RESULTING_DATE = "'#{END_DATE}' + 2"
  BLANK = ''

  ALL_DESCENANTS = 'All descendants'
  TREE_STORY = 'tree_story'
  TREE_DEFECT = 'tree_defect'
  TREE_RELEASE = 'tree_release'
  TREE_ITERATION = 'tree_iteration'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_admin_user = users(:longbob)
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_77', :users => [@non_admin_user], :admins => [@project_admin_user, users(:admin)], :anonymous_accessible => true)
    login_as_admin_user
    setup_property_definitions(PRIORITY => ['high', LOW], STATUS => [NEW,  'close', OPEN], ITERATION => [1,2,3,4], OWNER  => ['a', 'b', 'c'])
    @size_property = setup_numeric_property_definition(SIZE, [1, 2, 4])
    @size2_property = setup_numeric_property_definition(SIZE2, [0, 3, 5])
    @start_date = setup_date_property_definition(START_DATE)
    @end_date = setup_date_property_definition(END_DATE)

    @formula_actual_effort = setup_formula_property_definition('actual effort',FORMULA_USING_DATE)
    @formula_size_times_2 = setup_formula_property_definition('size time 2', FORMULA_USING_NUMERIC)
    @formula_effective_end_date = setup_formula_property_definition('effective end date', FORMULA_RESULTING_DATE)

    @type_story = setup_card_type(@project, STORY, :properties => [PRIORITY, SIZE, ITERATION, OWNER, @start_date, @end_date, @formula_actual_effort, @formula_size_times_2, @formula_effective_end_date])
    @type_defect = setup_card_type(@project, DEFECT, :properties => [PRIORITY, STATUS, OWNER])
    @type_task = setup_card_type(@project, TASK, :properties => [PRIORITY, SIZE2, ITERATION, STATUS, OWNER])
    @type_iteration = setup_card_type(@project, ITERATION_TYPE)
    @type_release = setup_card_type(@project, RELEASE)
  end

  def test_aggregate_properties_set_on_card_show_and_show_updated_data_for_anon_user
    register_license_that_allows_anonymous_users
    login_as_admin_user
    get_tree_built_with_aggregates_and_cards_in_it
    open_card(@project, @release_cards[0])
    assert_stale_value(@sum_of_size.name, NOT_SET)
    assert_stale_value(@count_of_stories.name, NOT_SET)
    assert_aggregate_value_being_out_of_date_tool_tip_shown_for(@sum_of_size)
    AggregateComputation.run_once
    open_card(@project, @release_cards[0])
    waitForAggregateValuesToBeComputed(@project,@count_of_stories.name,@release_cards[0])
    assert_property_set_on_card_show(@count_of_stories.name, '5')
    assert_property_set_on_card_show(@sum_of_size.name, '10')
    as_anon_user do
      open_card(@project, @release_cards[0])
      assert_property_set_on_card_show(@count_of_stories.name, '5')
      assert_property_set_on_card_show(@sum_of_size.name, '10')
    end
  end

  def test_removing_card_from_tree_recalculate_aggregate_propertis_on_card_show
    get_tree_built_with_aggregates_and_cards_in_it
    AggregateComputation.run_once
    open_card(@project, @release_cards[0])
    waitForAggregateValuesToBeComputed(@project,@sum_of_size.name,@release_cards[0])
    assert_property_set_on_card_show(@sum_of_size.name, '10')
    assert_property_set_on_card_show(@count_of_stories.name, '5')
    navigate_to_tree_view_for(@project, @planning_tree.name)
    remove_card_and_its_children_from_tree_for(@project, @planning_tree.name, @iteration_cards[0])
    open_card(@project, @release_cards[0])
    assert_aggregate_value_being_out_of_date_tool_tip_shown_for(@sum_of_size)
    assert_aggregate_value_being_out_of_date_tool_tip_shown_for(@count_of_stories)
    AggregateComputation.run_once
    open_card(@project, @release_cards[0])
    # in MRI the aggregation of 'not set' values comes out to 0, so we only look at the jruby one here
    waitForAggregateValuesToBeComputed(@project,@sum_of_size.name,@release_cards[0])
    assert_property_set_on_card_show(@sum_of_size.name, '(not set)')
    assert_property_set_on_card_show(@count_of_stories.name, '0')
  end

  def test_adding_card_to_a_tree_recalculate_aggregates_on_card_show
    get_tree_built_with_aggregates_and_cards_in_it
    AggregateComputation.run_once
    new_stories = create_cards(@project, 2, :card_type => @type_story)
    open_card(@project, @release_cards[0])
    waitForAggregateValuesToBeComputed(@project,@sum_of_size.name,@release_cards[0])
    assert_property_set_on_card_show(@sum_of_size.name, '10')
    assert_property_set_on_card_show(@count_of_stories.name, '5')
    add_card_to_tree(@planning_tree, new_stories, @iteration_cards[1])
    open_card(@project, @release_cards[0])
    assert_stale_value(@sum_of_size.name, "10")
    assert_stale_value(@count_of_stories.name, "5")
    AggregateComputation.run_once
    open_card(@project, @release_cards[0])
    waitForAggregateValuesToBeComputed(@project,@sum_of_size.name,@release_cards[0])
    assert_property_set_on_card_show(@sum_of_size.name, '10')
    assert_property_set_on_card_show(@count_of_stories.name, '7')
  end

  # bug 7355
  def test_removing_card_from_tree_shows_dirty_star_on_fathers_card_popup
    get_tree_built_with_aggregates_and_cards_in_it
    @sum_of_size.aggregate_scope = AggregateScope::ALL_DESCENDANTS
    @sum_of_size.save!

    AggregateComputation.run_once

    navigate_to_tree_view_for(@project, @planning_tree.name)
    remove_card_and_its_children_from_tree_for(@project, @planning_tree.name, @story_1)

    click_on_card_in_tree(@release_cards.first)
    assert_property_on_popup_on_tree_view("sumofsize:*10", @release_cards.first.number, 1)
  end

  #bug 5366
  def test_aggregate_on_one_card_should_work_if_you_bulk_delete_its_parent_card_and_children_card
    new_tree = setup_tree(@project, PLANNING_TREE, :types => [@type_release, @type_iteration, @type_story, @type_defect, @type_task], :relationship_names => [TREE_RELEASE, TREE_ITERATION, TREE_STORY, TREE_DEFECT])
    aggregate_property_for_release = create_aggregate_property_for(@project, 'all_desendants_of_release', new_tree, @type_release, :aggregation_type => COUNT, :scope => ALL_DESCENANTS)
    aggregate_property_for_iteration = create_aggregate_property_for(@project, 'all_desendants_of_iteration', new_tree, @type_iteration, :aggregation_type => COUNT, :scope => ALL_DESCENANTS)
    aggregate_property_for_story = create_aggregate_property_for(@project, 'all_desendants_of_story', new_tree, @type_story, :aggregation_type => COUNT, :scope => ALL_DESCENANTS)
    aggregate_property_for_defect = create_aggregate_property_for(@project, 'all_desendants_of_defect', new_tree, @type_defect, :aggregation_type => COUNT, :scope => ALL_DESCENANTS)
    release_1 = create_card!(:name => 'release_1', :card_type => @type_release)
    iteration_1 = create_card!(:name => 'iteration_1', :card_type => @type_iteration)
    story_1  = create_card!(:name => 'story_1', :card_type => @type_story)
    defect_1 = create_card!(:name => 'defect_1', :card_type => @type_defect)
    task_1 = create_card!(:name => 'task_1', :card_type => @type_task)
    task_2 = create_card!(:name => 'task_2', :card_type => @type_task)
    add_card_to_tree(new_tree, release_1)
    add_card_to_tree(new_tree, iteration_1, release_1)
    add_card_to_tree(new_tree, story_1, iteration_1)
    add_card_to_tree(new_tree, defect_1, story_1)
    add_card_to_tree(new_tree, [task_1, task_2], defect_1)
    AggregateComputation.run_once
    open_card(@project, story_1)
    waitForAggregateValuesToBeComputed(@project,aggregate_property_for_story.name,story_1)
    assert_property_set_on_card_show(aggregate_property_for_story.name, '3')
    navigate_to_card_list_for(@project)
    check_cards_in_list_view(iteration_1, defect_1)
    click_bulk_delete_button
    click_on_continue_to_delete_link
    AggregateComputation.run_once
    open_card(@project, story_1)
    waitForAggregateValuesToBeComputed(@project,aggregate_property_for_story.name,story_1)
    assert_property_set_on_card_show(aggregate_property_for_story.name, '2')
  end

  def test_aggregate_properties_shown_which_are_not_on_tree_should_be_set_to_notset
    get_tree_built_with_aggregates_and_cards_in_it
    open_card(@project, @release_cards[1])
    assert_stale_value(@sum_of_size.name, NOT_SET)
    assert_stale_value(@count_of_stories.name, NOT_SET)
  end

  def test_aggregate_properties_are_readonly
    get_tree_built_with_aggregates_and_cards_in_it
    AggregateComputation.run_once
    open_card(@project, @release_cards[0])
    waitForAggregateValuesToBeComputed(@project,@sum_of_size.name,@release_cards[0])
    assert_property_not_editable_on_card_show(@sum_of_size.name)
    assert_property_not_editable_on_card_show(@count_of_stories.name)
  end

  def test_aggregate_properties_are_read_only_for_card_defaults_page
    get_tree_built_with_aggregates_and_cards_in_it
    open_edit_defaults_page_for(@project, @type_release)
    assert_property_present_on_card_defaults(@sum_of_size.name)
    assert_property_present_on_card_defaults(@count_of_stories.name)
    assert_property_set_on_card_defaults(@project, @sum_of_size.name, CALCULATED)
    assert_property_set_on_card_defaults(@project, @count_of_stories.name, CALCULATED)
    assert_property_not_editable_on_card_defaults(@project, @sum_of_size)
    assert_property_not_editable_on_card_defaults(@project, @count_of_stories)
  end

  def test_changing_card_type_on_card_show_updates_or_removes_irrelevant_aggregate_properties
    get_tree_built_with_aggregates_and_cards_in_it
    open_card(@project, @release_cards[0])
    set_card_type_on_card_show(@type_iteration.name)
    assert_property_not_present_on_card_show(@sum_of_size.name)
    assert_property_not_present_on_card_show(@count_of_stories.name)
  end

  # bug 7217
  def test_aggregate_should_recalculate_when_changing_cards_types
    get_tree_built_with_aggregates_and_cards_in_it
    AggregateComputation.run_once
    open_card(@project, @release_cards[0])
    waitForAggregateValuesToBeComputed(@project,@count_of_stories.name,@release_cards[0])
    assert_property_set_on_card_show(@count_of_stories.name, '5')
    open_card(@project, @story_1)
    set_card_type_on_card_show(@type_iteration.name)
    AggregateComputation.run_once
    open_card(@project, @release_cards[0])
    waitForAggregateValuesToBeComputed(@project,@count_of_stories.name,@release_cards[0])
    assert_property_set_on_card_show(@count_of_stories.name, '4')
  end

  def test_aggreate_property_can_use_formula_properties_which_result_in_number
    get_tree_built_with_aggregates_and_cards_in_it
    actual_effort = create_aggregate_property_for(@project, 'actual efforts', @planning_tree, @type_release, :aggregation_type => SUM,  :property_to_aggregate => @formula_actual_effort.name)
    assert_notice_message("Aggregate property #{actual_effort.name} was successfully created")
    size_times_2 = create_aggregate_property_for(@project, 'sum of size time 2', @planning_tree, @type_release, :aggregation_type => SUM,  :property_to_aggregate => @formula_size_times_2.name)
    assert_notice_message("Aggregate property #{size_times_2.name} was successfully created")
    open_card(@project, @story_1)
    add_new_value_to_property_on_card_show(@project, START_DATE, '22 Jan 2000')
    add_new_value_to_property_on_card_show(@project, END_DATE, '24 Jan 2000')
    AggregateComputation.run_once
    open_card(@project, @release_cards[0])
    waitForAggregateValuesToBeComputed(@project,@sum_of_size.name,@release_cards[0])
    assert_property_set_on_card_show(@sum_of_size.name, '10')
    assert_property_set_on_card_show(size_times_2.name, '20')
    assert_property_set_on_card_show(actual_effort.name, '2')
  end

  #bug 4618
  def test_aggregates_using_formula_should_be_recalculated_when_aggregates_updated
    get_tree_built_with_aggregates_and_cards_in_it
    actual_effort = create_aggregate_property_for(@project, 'actual efforts', @planning_tree, @type_release, :aggregation_type => SUM,  :property_to_aggregate => @formula_actual_effort.name)
    assert_notice_message("Aggregate property #{actual_effort.name} was successfully created")
    open_card(@project, @story_1)
    add_new_value_to_property_on_card_show(@project, START_DATE, '22 Jan 2000')
    add_new_value_to_property_on_card_show(@project, END_DATE, '24 Jan 2000')
    AggregateComputation.run_once
    open_card(@project, @release_cards[0])
    waitForAggregateValuesToBeComputed(@project,actual_effort.name,@release_cards[0])
    assert_property_set_on_card_show(actual_effort.name, '2')
    new_aggregate = edit_aggregate_property_for(@project, @planning_tree, @type_release, actual_effort, :aggregate_property_name => 'double sizes', :aggregation_type => SUM, :scope => 'All descendants', :property_to_aggregate => "size time 2")
    AggregateComputation.run_once
    open_card(@project, @release_cards[0])
    waitForAggregateValuesToBeComputed(@project,new_aggregate.name,@release_cards[0])
    assert_property_set_on_card_show(new_aggregate.name, '20')
  end

  def test_formula_property_resulting_in_date_will_not_be_listed_in_properties_to_be_aggregated_dropdown
    get_tree_built_with_aggregates_and_cards_in_it
    open_aggregate_property_management_page_for(@project, @planning_tree)
    click_on_edit_aggregate_link_on_a_node_for(@type_release)
    assert_properties_not_available_on_target_property_drop_down(@formula_effective_end_date)
    assert_properties_available_on_target_property_drop_down(@formula_actual_effort, @formula_size_times_2)
  end

  def test_user_cannot_edit_fromula_property_to_date_resulting_if_its_used_in_aggregates
    get_tree_built_with_aggregates_and_cards_in_it
    actual_effort = create_aggregate_property_for(@project, 'actual efforts', @planning_tree, @type_release, :aggregation_type => SUM,  :property_to_aggregate => @formula_actual_effort.name)
    assert_notice_message("Aggregate property #{actual_effort.name} was successfully created")
    edit_property_definition_for(@project, @formula_actual_effort.name, :new_formula => FORMULA_RESULTING_DATE)
    assert_error_message("#{@formula_actual_effort.name} cannot have a formula that results in a date, as it is being used in the following aggregate property: #{actual_effort.name}")
  end

  #bug 3215
  def test_aggregate_property_gets_recalculated_on_removal_of_one_type_from_the_tree
    get_tree_built_with_aggregates_and_cards_in_it
    count_of_all_descendants = edit_aggregate_property_for(@project, @planning_tree, @type_release, @count_of_stories, :aggregate_property_name =>  'count all', :scope => 'All descendants')
    assert_notice_message("Aggregate property #{count_of_all_descendants.name} updated successfully")
    AggregateComputation.run_once
    open_card(@project, @release_cards[0])
    waitForAggregateValuesToBeComputed(@project,count_of_all_descendants.name,@release_cards[0])
    assert_property_set_on_card_show(count_of_all_descendants.name, '12')
    open_configure_a_tree_through_url(@project, @planning_tree)
    remove_card_type_node_from_tree(3)
    save_tree_permanently
    open_card(@project, @release_cards[0])
    assert_stale_value(count_of_all_descendants.name, "12")
    AggregateComputation.run_once
    open_card(@project, @release_cards[0])
    waitForAggregateValuesToBeComputed(@project,count_of_all_descendants.name,@release_cards[0])
    assert_property_set_on_card_show(count_of_all_descendants.name, '7')
  end

  # bug 3212
  def test_aggregate_proeprties_should_not_be_available_for_transitions
    get_tree_built_with_aggregates_and_cards_in_it
    open_transition_create_page(@project)
    set_card_type_on_transitions_page(@type_release.name)
    assert_requires_property_not_present(@sum_of_size.name, @count_of_stories.name)
    assert_sets_property_not_present(@sum_of_size.name, @count_of_stories.name)
  end

  # bug 3608
  def test_can_update_card_type_name_or_color_without_effecting_aggregate_that_is_using_card_type
    get_tree_built_with_aggregates_and_cards_in_it
    AggregateComputation.run_once
    new_name_for_story = 'new story name'
    edit_card_type_for_project(@project, STORY, :new_card_type_name => new_name_for_story)
    assert_notice_message("Card Type #{new_name_for_story} was successfully updated")
    open_aggregate_property_management_page_for(@project, @planning_tree)
    click_on_edit_aggregate_link_on_a_node_for(@type_release)
    assert_aggregate_property_present_on_configuration_for(@sum_of_size)
    open_card(@project, @release_cards[0])
    waitForAggregateValuesToBeComputed(@project,@sum_of_size,@release_cards[0])
    assert_property_set_on_card_show(@sum_of_size, @total_sum_of_story_sizes)
  end

  def test_aggregate_property_deleted_when_removing_property_association_from_card_type_in_tree_when_scope_is_that_type_is_not_allowed
    # Previously bug 3374 but story #4515 now prevents deletion.
    get_tree_built_with_aggregates_and_cards_in_it
    open_edit_card_type_page(@project, STORY)
    uncheck_properties_required_for_card_type(@project, [SIZE])
    save_card_type
    @browser.assert_text_present("Story cannot be updated because it is used by this project in the following areas:")
    @browser.assert_text_present("used as the target property of #{@sum_of_size.name}. To manage #{@sum_of_size.name}, please go to configure aggregate properties page.")
  end

  # bug 3200
  def test_aggregate_property_is_recalculated_when_type_of_card_is_changed_through_bulk_edit
    planning_tree = setup_tree(@project, 'Planning Tree', :types => [@type_release, @type_iteration], :relationship_names => ['Planning tree - release'])
    count_of_iterations = setup_aggregate_property_definition('count of iterations', AggregateType::COUNT, nil, planning_tree.id, @type_release.id, @type_iteration)
    release_1 = create_card!(:name => 'release 1', :card_type => @type_release)
    iteration_1 = create_card!(:name => 'iteration 1', :card_type => @type_iteration)
    add_card_to_tree(planning_tree, release_1)
    add_card_to_tree(planning_tree, iteration_1, release_1)
    AggregateComputation.run_once
    sleep 1
    navigate_to_list_view_of_tree(@project, planning_tree)
    add_column_for(@project, ['count of iterations'])
    assert_table_row_data_for('cards', :row_number => 3, :cell_values => [BLANK, '1', 'release 1', '1'])
    select_all
    click_edit_properties_button
    set_card_type_on_bulk_edit('Iteration')
    add_card_to_tree(planning_tree, release_1)

    navigate_to_list_view_of_tree(@project, planning_tree)
    add_column_for(@project, ['count of iterations'])

    assert_table_row_data_for('cards', :row_number => 3, :cell_values => [BLANK, '1', 'release 1', BLANK])
  end

  # bug 3581
  def test_stale_indicator_should_appear_in_list_and_hierarchy_views
    @tree = setup_tree(@project, 'Some Tree', :types => [@type_release, @type_iteration, @type_story], :relationship_names => [RELEASE_PROPERTY, ITERATION_PROPERTY])

    @release1 = create_card!(:name => 'release 1', :description => 'super plan', :card_type => RELEASE)
    @iteration1 = create_card!(:name => 'iteration 1', :card_type => ITERATION_TYPE)
    @story1 = create_card!(:name => 'story 1', :card_type => STORY)

    children_count = setup_aggregate_property_definition('count of children', AggregateType::COUNT, nil, @tree.id, @type_release.id, AggregateScope::ALL_DESCENDANTS)
    add_card_to_tree(@tree, @release1)
    add_card_to_tree(@tree, @iteration1, @release1)
    AggregateComputation.run_once
    add_card_to_tree(@tree, @story1, @iteration1)
    navigate_to_hierarchy_view_for(@project, @tree)
    add_column_for(@project, [children_count])
    assert_stale_indicator_for_column(children_count, @release1)

    navigate_to_card_list_for(@project)
    add_column_for(@project, [children_count])
    assert_stale_indicator_for_column(children_count, @release1)
  end

  # Bug 3617.
  def test_the_sum_of_all_nulls_should_not_be_zero
    planning_tree = setup_tree(@project, 'Planning Tree', :types => [@type_release, @type_iteration], :relationship_names => [RELEASE_PROPERTY])
    sum_of_iterations = setup_aggregate_property_definition('sum of iterations', AggregateType::SUM, @size_property, planning_tree.id, @type_release.id, @type_iteration)
    release_1 = create_card!(:name => 'release 1', :card_type => @type_release)
    iteration_1 = create_card!(:name => 'iteration 1', :card_type => @type_iteration)
    iteration_2 = create_card!(:name => 'iteration 2', :card_type => @type_iteration)
    add_cards_to_tree(planning_tree, release_1, [
                                       iteration_1,
                                       iteration_2])
    AggregateComputation.run_once
    open_card(@project, release_1)
     waitForAggregateValuesToBeComputed(@project,sum_of_iterations.name,release_1)
    assert_property_set_on_card_show(sum_of_iterations.name, NOT_SET)
  end

  # Bug 3199.
  def test_count_should_be_zero_when_no_cards_in_aggregation
    planning_tree = setup_tree(@project, 'Planning Tree', :types => [@type_release, @type_iteration], :relationship_names => ['PT release'])
    count_of_iterations = setup_aggregate_property_definition('sum of iterations', AggregateType::COUNT, nil, planning_tree.id, @type_release.id, @type_iteration)
    release_1 = create_card!(:name => 'release 1', :card_type => @type_release)
    add_card_to_tree(planning_tree, release_1)
    AggregateComputation.run_once
    open_card(@project, release_1)
    waitForAggregateValuesToBeComputed(@project,count_of_iterations.name,release_1)
    assert_property_set_on_card_show(count_of_iterations.name, '0')
  end

  # Bug 4161.
  def test_removing_card_from_tree_sets_count_aggregates_to_nil_for_cards_that_do_not_have_that_aggregate
    create_planning_tree
    release_count_of_stories = setup_aggregate_property_definition('count of stories', AggregateType::COUNT, nil, @planning_tree.id, @type_release.id, @type_story)
    iteration_count_of_all_descendants = setup_aggregate_property_definition('count of all descendants', AggregateType::COUNT, nil, @planning_tree.id, @type_iteration.id, AggregateScope::ALL_DESCENDANTS)
    quick_add_cards_on_tree(@project, @planning_tree, :root, :card_names => ['r1'], :card_type => RELEASE)
    r1 = @project.cards.find_by_name('r1')
    quick_add_cards_on_tree(@project, @planning_tree, r1, :card_names => ['i1'], :card_type => ITERATION_TYPE)
    i1 = @project.cards.find_by_name('i1')
    @project.reload
    quick_add_cards_on_tree(@project, @planning_tree, i1, :card_names => ['s1', 's2'], :card_type => STORY)
    AggregateComputation.run_once
    navigate_to_hierarchy_view_for(@project, @planning_tree)
    add_column_for(@project, [release_count_of_stories, iteration_count_of_all_descendants])

    assert_card_list_property_value(release_count_of_stories, r1, '2')
    assert_card_list_property_value(iteration_count_of_all_descendants, r1, '')
    click_twisty_for(r1)
    assert_card_list_property_value(release_count_of_stories, i1, '')
    assert_card_list_property_value(iteration_count_of_all_descendants, i1, '2')

    navigate_to_tree_view_for(@project, @planning_tree.name)
    s2 = @project.cards.find_by_name('s2')
    click_remove_card_from_tree(s2, @planning_tree)
    AggregateComputation.run_once
    navigate_to_hierarchy_view_for(@project, @planning_tree)
    add_column_for(@project, [release_count_of_stories, iteration_count_of_all_descendants])

    assert_card_list_property_value(release_count_of_stories, r1, '1')
    assert_card_list_property_value(iteration_count_of_all_descendants, r1, '')
    click_twisty_for(r1)
    assert_card_list_property_value(release_count_of_stories, i1, '')
    assert_card_list_property_value(iteration_count_of_all_descendants, i1, '1')
  end

  #bug 3556
  def test_scenario_of_getting_empty_history_entries_on_card_used_in_two_trees
    get_tree_built_with_aggregates_and_cards_in_it

    tree_the_second = setup_tree(@project, 'Tree the second', :types => [@type_release, @type_iteration, @type_story], :relationship_names => ["RELEASE_PROPERTY", "ITERATION_PROPERTY"])
    sum_of_size_fortree_the_second =  setup_aggregate_property_definition('sum of size2', AggregateType::SUM, @size_property, tree_the_second.id, @type_release.id, @type_story)

    open_card(@project, @release_cards[0])
    assert_history_for(:card, @release_cards[0]).version(2).not_present

    add_card_to_tree(tree_the_second, @release_cards)
    add_card_to_tree(tree_the_second, @iteration_cards[0], @release_cards[0])
    add_card_to_tree(tree_the_second, [@story_1, @story_2], @iteration_cards[0])
    AggregateComputation.run_once
    open_card(@project, @release_cards[0])

    assert_history_for(:card, @release_cards[0]).version(2).not_present
  end

  #bug 7227
  def test_dirty_star_should_show_right_away_when_quick_adding_card_to_tree
    @tree = setup_three_level_tree
    release_1 = @project.cards.find_by_name('release 1')
    navigate_to_tree_view_for(@project, @tree.name)
    quick_add_cards_on_tree(@project, @tree, release_1, :card_names => ['iteration1'], :card_type => ITERATION_TYPE)
    click_on_card_in_tree(@project.cards.find_by_name('release 1'))
    @browser.assert_text_present("* 1")
  end

  #bug 7227
  def test_dirty_star_should_show_right_away_when_remove_card_from_tree
    @tree = setup_three_level_tree
    navigate_to_tree_view_for(@project, @tree.name)
    click_remove_link_for_card(@project.cards.find_by_name('iteration 2'))
    @browser.assert_text_present("* 1")
  end

  private

  def setup_three_level_tree
    tree = setup_tree(@project, 'Some Tree', :types => [@type_release, @type_iteration, @type_story], :relationship_names => [RELEASE_PROPERTY, ITERATION_PROPERTY])
    children_count = setup_aggregate_property_definition('count of children', AggregateType::COUNT, nil, tree.id, @type_release.id, AggregateScope::ALL_DESCENDANTS)
    release_1 = create_card!(:name => 'release 1', :card_type => @type_release)
    iteration_2 = create_card!(:name => 'iteration 2', :card_type => @type_iteration)
    add_cards_to_tree(tree, release_1, iteration_2)
    AggregateComputation.run_once
    tree
  end
  def create_planning_tree
    @planning_tree = setup_tree(@project, 'Planning Tree', :types => [@type_release, @type_iteration, @type_story, @type_task],
      :relationship_names => [RELEASE_PROPERTY, ITERATION_PROPERTY, STORY_PROPERTY])
  end

  def get_tree_built_with_aggregates_and_cards_in_it
    create_planning_tree
    @sum_of_size =  setup_aggregate_property_definition('sum of size', AggregateType::SUM, @size_property, @planning_tree.id, @type_release.id, @type_story)
      @count_of_stories = setup_aggregate_property_definition('count of stories', AggregateType::COUNT, nil, @planning_tree.id, @type_release.id, @type_story)

    @release_cards = create_cards(@project, 2, :card_type => @type_release)
    @iteration_cards = create_cards(@project, 2, :card_type => @type_iteration)
    @story_1 = create_card!(:name => 'story 1', :card_type => @type_story, SIZE => '2')
    @story_2 = create_card!(:name => 'story 2', :card_type => @type_story, SIZE => '1')
    @story_3 = create_card!(:name => 'story 3', :card_type => @type_story, SIZE => '4')
    @story_4 = create_card!(:name => 'story 4', :card_type => @type_story, SIZE => '2')
    @story_5 = create_card!(:name => 'story 5', :card_type => @type_story, SIZE => '1')
    @total_sum_of_story_sizes = '10'

    @task_cards = create_cards(@project, 5, :card_type => @type_task)

    add_card_to_tree(@planning_tree, @release_cards)
    add_card_to_tree(@planning_tree, @iteration_cards, @release_cards[0])
    add_card_to_tree(@planning_tree, [@story_1, @story_2, @story_3, @story_4, @story_5], @iteration_cards[0])
    add_card_to_tree(@planning_tree, @task_cards, @iteration_cards[1])
  end

  #bug 12546
  def test_changing_card_type_of_card_in_tree_should_not_throw_500_error
    dev_effort = setup_numeric_property_definition("dev effort", []).update_attributes(:card_types=>[@type_story, @type_task])
    test_effort = setup_numeric_property_definition("test effort", []).update_attributes(:card_types => [@type_story, @type_task])
    total_effort = setup_formula_property_definition('total effort',"'test effort' + 'dev effort'").update_attributes(:card_types => [@type_story, @type_task])

   setup_numeric_property_definition("task estimate", []).update_attributes(:card_types=>[@type_task])
   task_estimate = @project.all_property_definitions.find_by_name('task estimate');
    ris_tree = setup_tree(@project, 'RIS Tree', :types => [@type_release, @type_iteration, @type_story, @type_task], :relationship_names => [RELEASE_PROPERTY, ITERATION_PROPERTY, STORY_PROPERTY])
    total_effort_of_release =create_aggregate_property_for(@project, 'total effort in release', ris_tree, @type_release, :aggregation_type => SUM, :scope => AggregateScope::DEFINE_CONDITION, :condition => 'type = Story', :property_to_aggregate => "total effort")
    count_of_tasks = setup_aggregate_property_definition('count of tasks', AggregateType::COUNT, nil, ris_tree.id, @type_release.id, @type_task)
    total_estimate_of_story =  setup_aggregate_property_definition('total estimate of story', AggregateType::SUM, task_estimate, ris_tree.id, @type_story.id, @type_task)

    @release_1 = create_card!(:name => 'Release 1', :card_type => @type_release)
    @iteration_1 = create_card!(:name => 'Iteration 1', :card_type => @type_iteration)
    @iteration_2 = create_card!(:name => 'Iteration 2', :card_type => @type_iteration)

    @story_1 = create_card!(:name => 'story 1', :card_type => @type_story, 'dev effort' => 3, 'test effort' => 4)
    @story_2 = create_card!(:name => 'story 2', :card_type => @type_story, 'dev effort' => 1, 'test effort' => 2)
    @task_1 = create_card!(:name => 'Task 1', :card_type => @type_task, task_estimate => '1')

    add_card_to_tree(ris_tree, @release_1)
    add_card_to_tree(ris_tree, [@iteration_1, @iteration_2, @story_2] , @release_1)
    add_card_to_tree(ris_tree, @story_1, @iteration_1)
    add_card_to_tree(ris_tree, @task_1, @story_1)
    AggregateComputation.run_once

    navigate_to_tree_view_for(@project, ris_tree.name)
    open_card_via_clicking_link_on_mini_card(@iteration_2)

    click_edit_link_on_card
    set_properties_in_card_edit(TYPE => TASK)
    click_save_for_card_type_change

    AggregateComputation.run_once
    navigate_to_tree_view_for(@project, ris_tree.name)

    open_card_via_clicking_link_on_mini_card(@release_1)
     waitForAggregateValuesToBeComputed(@project,'count of tasks',@release_1)
    assert_property_set_on_card_show('count of tasks', '2')
    assert_property_set_on_card_show('total effort in release', '10')

    navigate_to_tree_view_for(@project, ris_tree.name)
    open_card_via_clicking_link_on_mini_card(@story_1)
    waitForAggregateValuesToBeComputed(@project,'total estimate of story',@story_1)
    assert_property_set_on_card_show('total estimate of story','1')
  end
end
