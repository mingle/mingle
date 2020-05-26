# coding: utf-8

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

#Tags: tree-usage, import-export, excel

class Scenario80ExcelImportExportTreeTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  PRIORITY = 'priority'
  STATUS = 'status'
  SIZE = 'size'
  ITERATION = 'iteration'
  OWNER = 'Zowner'
  COUNT_OF_STORIES = 'count of stories'

  RELEASE = 'Release'
  ITERATION_TYPE = 'Iteration'
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

  PLANNING = 'Planning'
  NONE = 'None'
  BLANK = ''
  NO = 'no'
  YES = 'yes'

  RELATION_PLANNING_RELEASE = 'Planning tree - release'
  RELATION_PLANNING_ITERATION = 'Planning tree - iteration'
  RELATION_PLANNING_STORY = 'Planning tree - story'

  #does_not_work_on_google_chrome

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_admin_user = users(:longbob)
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_81', :users => [@non_admin_user], :admins => [@project_admin_user, users(:admin)])
    setup_property_definitions(PRIORITY => ['high', LOW], SIZE => [1, 2, 4], STATUS => [NEW,  'close', OPEN], ITERATION => [1,2,3,4], OWNER  => ['a', 'b', 'c'])
    @type_story = setup_card_type(@project, STORY, :properties => [PRIORITY, SIZE, ITERATION, OWNER])
    @type_defect = setup_card_type(@project, DEFECT, :properties => [PRIORITY, STATUS, OWNER])
    @type_task = setup_card_type(@project, TASK, :properties => [PRIORITY, SIZE, ITERATION, STATUS, OWNER])
    @type_iteration = setup_card_type(@project, ITERATION_TYPE)
    @type_release = setup_card_type(@project, RELEASE)
    login_as_admin_user
    @r1 = create_card!(:name => 'release 1', :description => "Without software, most organizations could not survive in the current marketplace see bug100", :card_type => RELEASE)
    @r2 = create_card!(:name => 'release 2', :card_type => RELEASE)
    @i1 = create_card!(:name => 'iteration 1', :card_type => ITERATION_TYPE)
    @i2 = create_card!(:name => 'iteration 2', :card_type => ITERATION_TYPE)
    @stories = create_cards(@project, 5, :card_type => @type_story)
    @tasks = create_cards(@project, 2, :card_type => @type_task)
    @tree = setup_tree(@project, 'planning tree', :types => [@type_release, @type_iteration, @type_story, @type_task],
      :relationship_names => [RELATION_PLANNING_RELEASE, RELATION_PLANNING_ITERATION, RELATION_PLANNING_STORY])
    @count_of_stories = setup_aggregate_property_definition(COUNT_OF_STORIES, AggregateType::COUNT, nil, @tree.id, @type_release.id, @type_story)
    AggregateComputation.run_once
    sleep 1
  end

  def test_export_to_excel_with_tree_will_export_relationship_properties_and_aggregates_along
    get_planning_tree_generated_with_cards_on_tree
    navigate_to_card_list_for(@project)
    export_all_columns_to_excel_with_description
    expected = %{Number,Name,Description,Type,iteration,priority,size,status,Zowner,planning tree,Planning tree - release,Planning tree - iteration,Planning tree - story,count of stories,Created by,Modified by,Incomplete Checklist Items,Completed Checklist Items\n11,card 2,,Task,,,,,,yes,#1 release 1,#3 iteration 1,#6 card 2,,admin,admin,"",""\n10,card 1,,Task,,,,,,yes,#1 release 1,#3 iteration 1,#6 card 2,,admin,admin,"",""\n9,card 5,,Story,,,,,,yes,#1 release 1,#3 iteration 1,,,admin,admin,"",""\n8,card 4,,Story,,,,,,yes,#1 release 1,#3 iteration 1,,,admin,admin,"",""\n7,card 3,,Story,,,,,,yes,#1 release 1,#3 iteration 1,,,admin,admin,"",""\n6,card 2,,Story,,,,,,yes,#1 release 1,#3 iteration 1,,,admin,admin,"",""\n5,card 1,,Story,,,,,,yes,#1 release 1,#3 iteration 1,,,admin,admin,"",""\n4,iteration 2,,Iteration,,,,,,no,,,,,admin,admin,"",""\n3,iteration 1,,Iteration,,,,,,yes,#1 release 1,,,,admin,admin,"",""\n2,release 2,,Release,,,,,,no,,,,,admin,admin,"",""\n1,release 1,\"Without software, most organizations could not survive in the current marketplace see bug100\",Release,,,,,,yes,,,,5.00,admin,admin,"",""}
    puts get_exported_data
    assert_equal_ignore_cr(expected, get_exported_data)

  end

  def test_can_import_cards_on_tree_and_update_existing_ones
    get_planning_tree_generated_with_cards_on_tree
    header_row = ['Number', 'name', 'Type', 'planning tree', 'Planning tree - release', 'Planning tree - iteration', 'Planning tree - story', 'count of stories']
    card_data = [
      ['1', 'Release 1', 'Release', NO, BLANK, BLANK, BLANK, BLANK],
      ['2', 'Release 2', 'Release', YES, BLANK, BLANK, BLANK, '15']
    ]
    navigate_to_card_list_for(@project)
    preview(excel_copy_string(header_row, card_data))
    assert_notice_message('Preparing preview completed.')
    select_tree_to_import(@tree.name)
    import_from_preview
    assert_import_complete_with(:rows => 2, :rows_created => 0, :rows_updated => 2, :errors => 0)
    navigate_to_tree_view_for(@project, @tree.name)
    assert_card_not_present_on_tree(@project, @r1)
    assert_cards_on_a_tree(@project, @r2, @i1, @stories[0], @stories[1], @tasks[0], @tasks[1])
  end

  # bug 5462
  def test_cannot_import_a_card_into_one_tree_without_its_specified_parent_card_in_that_tree
    header_row_1 = ['Number', 'name', 'Type', 'planning tree', 'Planning tree - release', 'Planning tree - iteration', 'Planning tree - story']
    card_data_1 = [
      ['12', 'new_iteration_card', ITERATION_TYPE, YES, '#1', BLANK, BLANK]
    ]
    navigate_to_card_list_for(@project)
    preview(excel_copy_string(header_row_1, card_data_1))
    select_tree_to_import(@tree.name)
    import_from_preview
    assert_error_message("Row 1: Validation failed: Suggested parent card isn't on tree planning tree")
    add_card_to_tree(@tree, @r1)
    header_row = ['Number', 'name', 'Type', 'planning tree', 'Planning tree - release', 'Planning tree - iteration', 'Planning tree - story']
    card_data = [
      ['12', 'new_iteration_card', ITERATION_TYPE, YES, '#1', BLANK, BLANK]
    ]
    navigate_to_card_list_for(@project)
    preview(excel_copy_string(header_row, card_data))
    select_tree_to_import(@tree.name)
    import_from_preview
    assert_notice_message("Importing complete, 1 row, 0 updated, 1 created, 0 errors")
    new_iteration_card = find_card_by_name('new_iteration_card')
    navigate_to_tree_view_for(@project, @tree.name)
    assert_card_showing_on_tree(new_iteration_card)
    assert_card_showing_on_tree(@r1)
  end

  #bgug 6173
  def test_tree_name_and_relationship_names_should_not_be_case_sensitive_during_excel_import
    get_planning_tree_generated_with_cards_on_tree
    header_row = ['Number', 'name', 'Type', 'Planning tree', 'planning tree - Release', 'planning tree - Iteration', 'planning tree - Story', 'count of stories']
    card_data = [
      ['1', 'Release 1', 'Release', NO, BLANK, BLANK, BLANK, BLANK],
      ['2', 'Release 2', 'Release', YES, BLANK, BLANK, BLANK, '15']
    ]
    navigate_to_card_list_for(@project)
    preview(excel_copy_string(header_row, card_data))
    assert_notice_message('Preparing preview completed.')
    select_tree_to_import(@tree.name)
    import_from_preview
    assert_import_complete_with(:rows => 2, :rows_created => 0, :rows_updated => 2, :errors => 0)
    navigate_to_tree_view_for(@project, @tree.name)
    assert_card_not_present_on_tree(@project, @r1)
    assert_cards_on_a_tree(@project, @r2, @i1, @stories[0], @stories[1], @tasks[0], @tasks[1])
  end

  def test_contrast_excel_data_with_existing_tree_structure_should_give_invalid_row_data_error
    get_planning_tree_generated_with_cards_on_tree
    header_row = ['Number', 'name', 'Type', 'planning tree', 'Planning tree - release', 'Planning tree - iteration', 'Planning tree - story', 'count of stories']
    card_data = [
      ['5', 'story 1', STORY, YES, '#2 release 2', '#3', BLANK, BLANK]
    ]
    navigate_to_card_list_for(@project)
    preview(excel_copy_string(header_row, card_data))
    assert_notice_message('Preparing preview completed.')
    select_tree_to_import(@tree.name)
    import_from_preview
    assert_error_message("Row 1: Validation failed: Suggested location on tree #{@tree.name} is invalid.")
  end

  def test_error_message_while_missing_relationship_properties_for_excel_import_for_tree_specified
    get_planning_tree_generated_with_cards_on_tree
    header_row = ['Number', 'name', 'Type', 'planning tree', 'Planning tree - release', 'Planning tree - iteration']
    card_data = [
      ['3', 'iteration 1', 'Iteration', YES, '#1 release 1', BLANK],
      ['1', 'Release 1', 'Release', NO, BLANK, BLANK],
    ]
    navigate_to_card_list_for(@project)
    preview(excel_copy_string(header_row, card_data))
    assert_warning_message_matches("Properties for tree '#{@tree.name}' will not be imported because column '#{RELATION_PLANNING_STORY}' was not included in the pasted data.")
  end

  def test_error_message_while_missing_relationship_properties_are_not_part_of_the_existing_tree
    get_planning_tree_generated_with_cards_on_tree
    header_row = ['Number', 'name', 'Type', 'planning tree', 'Planning tree123 - release', 'Planning tree123 - iteration', 'Planning tree123 - story']
    card_data = [
      ['3', 'iteration 1', 'Iteration', YES, '#1 release 1', BLANK, BLANK],
      ['1', 'Release 1', 'Release', NO, BLANK, BLANK, BLANK]
    ]
    navigate_to_card_list_for(@project)
    preview(excel_copy_string(header_row, card_data))
    assert_warning_message_matches("Properties for tree '#{@tree.name}' will not be imported because column '#{RELATION_PLANNING_RELEASE}', '#{RELATION_PLANNING_ITERATION}', '#{RELATION_PLANNING_STORY}' were not included in the pasted data.")
  end

  def test_excel_data_need_not_mention_about_aggregate_proeprties_columns
    header_row = ['Number', 'name', 'Type', 'planning tree', 'Planning tree - release', 'Planning tree - iteration', 'Planning tree - story']
    card_data = [
      ['2', 'Release 2', 'Release', YES, BLANK, BLANK, BLANK]
    ]
    navigate_to_card_list_for(@project)
    preview(excel_copy_string(header_row, card_data))
    assert_notice_message('Preparing preview completed.')
    select_tree_to_import(@tree.name)
    import_from_preview
    assert_import_complete_with(:rows => 1, :rows_created => 0, :rows_updated => 1, :errors => 0)
  end

  # bug 3393
  def test_cannot_set_value_for_existing_aggregate_property_via_excel_import
    # setup_formula_property_definition(SIZE_TIMES_TWO, "#{SIZE} * 2")
    header_row = ['Number', 'name', 'Type', 'planning tree', 'Planning tree - release', 'Planning tree - iteration', 'Planning tree - story', COUNT_OF_STORIES]
    card_data = [
      ['2', 'Release 2', 'Release', YES, BLANK, BLANK, BLANK, '3']
    ]

    navigate_to_card_list_for(@project)
    preview(excel_copy_string(header_row, card_data))
    assert_warning_message_matches("Cannot set value for aggregate property: #{COUNT_OF_STORIES}")
    assert_ignore_selected_for_property_column(COUNT_OF_STORIES)
    assert_ignore_only_available_mapping_for_property_column(COUNT_OF_STORIES)
  end

  def test_excel_import_for_more_than_one_tree_will_get_valid_one_on_drop_down
    @tree2 = setup_tree(@project, 'tasks tree', :types => [@type_release, @type_iteration, @type_task],
      :relationship_names => ['task release', 'task iteration'])
    header_row = ['Number', 'name', 'Type', @tree2.name, 'task release', 'task iteration']
    card_data = [
      ['2', 'Release 2', 'Release', YES, BLANK, BLANK]
    ]
    navigate_to_card_list_for(@project)
    preview(excel_copy_string(header_row, card_data))
    assert_tree_present_in_tree_select_drop_down(@tree2.name)
    assert_tree_name_not_present_in_tree_select_drop_down(@tree.name)
  end

  # bug 3425
  def test_can_ignore_card_whose_type_belongs_to_tree_but_card_does_not
    add_card_to_tree(@tree, @r1)
    header_row = ['Number', 'name', 'Type', @tree.name, RELATION_PLANNING_RELEASE, RELATION_PLANNING_ITERATION, RELATION_PLANNING_STORY]
    card_data = [
      [@i1.number, 'iteration not in tree', ITERATION_TYPE, NO, BLANK, BLANK, BLANK],
      [@i2.number, BLANK, ITERATION_TYPE, YES, card_number_and_name(@r1), BLANK, BLANK]
    ]
    navigate_to_card_list_for(@project)
    preview(excel_copy_string(header_row, card_data))
    select_tree_to_import(@tree.name)
    import_from_preview(:ignores => [1])
    assert_notice_message("Importing complete, 1 row, 1 updated, 0 created, 0 errors.")
    @browser.run_once_history_generation
    open_card(@project, @i1)
    assert_property_set_on_card_show(RELATION_PLANNING_RELEASE, NOTSET)
    assert_history_for(:card, @i1.number).version(2).not_present
    open_card(@project, @i2)
    assert_property_set_on_card_show(RELATION_PLANNING_RELEASE, @r1)
    assert_history_for(:card, @i2.number).version(2).shows(:set_properties => {RELATION_PLANNING_RELEASE => card_number_and_name(@r1)})
  end



  # bug 3426 & bug 3663
  def test_setting_no_for_tree_during_import_removes_card_that_is_already_in_tree
    story_one = @stories[1]
    add_card_to_tree(@tree, @r1)
    add_card_to_tree(@tree, @i1, @r1)
    add_card_to_tree(@tree, story_one, @i1)
    new_name_for_iteration_one = 'iteration one'
    header_row = ['Number', 'name', 'Type', @tree.name, RELATION_PLANNING_RELEASE, RELATION_PLANNING_ITERATION, RELATION_PLANNING_STORY]
    card_data = [
      [story_one.number, '', STORY, NO, card_number_and_name(@r1), card_number_and_name(@i1), BLANK],
      [@i1.number, new_name_for_iteration_one, ITERATION_TYPE, NO, card_number_and_name(@r1), BLANK, BLANK]
    ]
    navigate_to_card_list_for(@project)
    preview(excel_copy_string(header_row, card_data))
    select_tree_to_import(@tree.name)
    import_from_preview
    @browser.run_once_history_generation
    assert_notice_message("Importing complete, 2 rows, 2 updated, 0 created, 0 errors.")
    open_card(@project, @i1)
    assert_property_set_on_card_show(RELATION_PLANNING_RELEASE, NOTSET)
    assert_history_for(:card, @i1.number).version(3).shows(:changed => RELATION_PLANNING_RELEASE, :from => card_number_and_name(@r1), :to => NOTSET)
    open_card(@project, story_one)
    assert_property_set_on_card_show(RELATION_PLANNING_RELEASE, NOTSET)
    assert_property_set_on_card_show(RELATION_PLANNING_ITERATION, NOTSET)
    assert_history_for(:card, story_one.number).version(3).shows(:changed => RELATION_PLANNING_RELEASE, :from => card_number_and_name(@r1), :to => NOTSET)
    assert_history_for(:card, story_one.number).version(3).shows(:changed => RELATION_PLANNING_ITERATION, :from => "##{@i1.number} #{new_name_for_iteration_one}", :to => NOTSET)
  end

  # bug 3454
  def test_error_message_while_data_importing_without_parent_set_first
    get_planning_tree_generated_with_cards_on_tree
    header_row = ['Number', 'name', 'Type', 'planning tree', 'Planning tree - release', 'Planning tree - iteration', 'Planning tree - story']
    card_data = [
      ['3', 'iteration 1', 'Iteration', 'yes', '#1 release 1', '', ''],
      ['1', 'Release 1', 'Release', 'no', '', '', ''],
    ]
    navigate_to_card_list_for(@project)
    preview(excel_copy_string(header_row, card_data))
    select_tree_to_import(@tree.name)
    import_from_preview
    assert_error_message("Row 1: Validation failed: Suggested parent card isn't on tree #{@tree.name}")
  end

  # bug 3660
  def test_can_still_import_when_tree_is_present_but_relationship_property_names_do_not_match
    release_property_with_em_dashes = 'test – release'
    iteration_property_with_em_dashes = 'test – iteration'
    release_property = 'test - release'
    iteration_property = 'test - iteration'
    tree = setup_tree(@project, 'test tree', :types => [@type_release, @type_iteration, @type_story], :relationship_names => [release_property, iteration_property])
    header_row = ['Number', 'Name', 'Type', tree.name, 'test – release', 'test – iteration']
    card_data = [
      ['115', 'story 101', STORY, NO, card_number_and_name(@r1), card_number_and_name(@i1)],
      ['114', 'story 100', STORY, YES, @r2.number, @i1.number],
      [@i1.number, @i1.name, ITERATION_TYPE, NO, @i1.number, '-'],
      [@i2.number, @i2.name, ITERATION_TYPE, YES, @i2.number, '-']
    ]
    navigate_to_card_list_for(@project)
    preview(excel_copy_string(header_row, card_data))
    assert_warning_message("Properties for tree '#{tree.name}' will not be imported because column '#{release_property}', '#{iteration_property}' were not included in the pasted data.")
    assert_ignore_selected_for_property_column(tree.name)
    assert_drop_down_disabled_for_property_column(tree.name)
    import_from_preview
    assert_notice_message("Importing complete, 4 rows, 2 updated, 2 created, 0 errors.")
  end

  #bug 3394 
  def test_excel_import_does_not_throw_error_while_importing_two_trees_details_through_excel_import_while_aggregate_properties_on_one_of_the_tree
    tree_the_second = setup_tree(@project, 'Tree the second', :types => [@type_release, @type_iteration, @type_story], :relationship_names => ["RELEASE_PROPERTY", "ITERATION_PROPERTY"])

    add_card_to_tree(@tree, @r1)
    add_card_to_tree(@tree, @i1, @r1)
    add_card_to_tree(@tree, @stories, @i1)

    add_card_to_tree(tree_the_second, @r1)
    add_card_to_tree(tree_the_second, @i1, @r1)
    add_card_to_tree(tree_the_second, @stories, @i1)
    AggregateComputation.run_once
    navigate_to_card_list_for(@project)
    export_all_columns_to_excel_with_description
    excel_data= %{Number\tName\tDescription\tType\titeration\tpriority\tsize\tstatus\tZowner\tplanning tree\tPlanning tree - release\tPlanning tree - iteration\tPlanning tree - story\tcount of stories\tCreated by\tModified by
    11\tcard 2\t\tTask\t\t\t\t\t\tyes\t#1 release 1\t#3 iteration 1\t#6 card 2\t\tadmin\tadmin
    10\tcard 1\t\tTask\t\t\t\t\t\tyes\t#1 release 1\t#3 iteration 1\t#6 card 2\t\tadmin\tadmin
    9\tcard 5\t\tStory\t\t\t\t\t\tyes\t#1 release 1\t#3 iteration 1\t\t\tadmin\tadmin
    8\tcard 4\t\tStory\t\t\t\t\t\tyes\t#1 release 1\t#3 iteration 1\t\t\tadmin\tadmin
    7\tcard 3\t\tStory\t\t\t\t\t\tyes\t#1 release 1\t#3 iteration 1\t\t\tadmin\tadmin
    6\tcard 2\t\tStory\t\t\t\t\t\tyes\t#1 release 1\t#3 iteration 1\t\t\tadmin\tadmin
    5\tcard 1\t\tStory\t\t\t\t\t\tyes\t#1 release 1\t#3 iteration 1\t\t\tadmin\tadmin
    4\titeration 2\t\tIteration\t\t\t\t\t\tno\t\t\t\t\tadmin\tadmin
    3\titeration 1\t\tIteration\t\t\t\t\t\tyes\t#1 release 1\t\t\t\tadmin\tadmin
    2\trelease 2\t\tRelease\t\t\t\t\t\tno\t\t\t\t\tadmin\tadmin
    1\trelease 1\tWithout software, most organizations could not survive in the current marketplace see bug100\tRelease\t\t\t\t\t\tyes\t\t\t\t5.00\tadmin\tadmin}
    
    navigate_to_card_list_for(@project)
    click_import_from_excel
    type_in_tab_separated_import(excel_data)
    submit_to_preview 
    select_tree_to_import(@tree.name)
    import_from_preview
    assert_import_complete_with(:rows => 11, :rows_created => 0, :rows_updated => 11, :errors => 0)
  end

  def test_export_with_description_works_for_tree_selected_in_tree_and_hierarchy_view
    expected_with_description = %{Number,Name,Description,Type,iteration,priority,size,status,Zowner,planning tree,Planning tree - release,Planning tree - iteration,Planning tree - story,count of stories,Created by,Modified by,Incomplete Checklist Items,Completed Checklist Items\n1,release 1,\"Without software, most organizations could not survive in the current marketplace see bug100\",Release,,,,,,yes,,,,,admin,admin,"",""\n11,card 2,,Task,,,,,,yes,#1 release 1,#3 iteration 1,,,admin,admin,"",""\n6,card 2,,Story,,,,,,yes,#1 release 1,#3 iteration 1,,,admin,admin,"",""}
    expected_without_description = %{Number,Name,Type,iteration,priority,size,status,Zowner,planning tree,Planning tree - release,Planning tree - iteration,Planning tree - story,count of stories,Created by,Modified by,Incomplete Checklist Items,Completed Checklist Items\n1,release 1,Release,,,,,,yes,,,,,admin,admin,"",""\n3,iteration 1,Iteration,,,,,,yes,#1 release 1,,,,admin,admin,"",""\n11,card 2,Task,,,,,,yes,#1 release 1,#3 iteration 1,,,admin,admin,"",""\n6,card 2,Story,,,,,,yes,#1 release 1,#3 iteration 1,,,admin,admin,"",""\n4,iteration 2,Iteration,,,,,,yes,#1 release 1,,,,admin,admin,"",""}
    expected_with_description_hierarchy_view = %{Number,Name,Description,Type,iteration,priority,size,status,Zowner,planning tree,Planning tree - release,Planning tree - iteration,Planning tree - story,count of stories,Created by,Modified by,Incomplete Checklist Items,Completed Checklist Items\n1,release 1,\"Without software, most organizations could not survive in the current marketplace see bug100\",Release,,,,,,yes,,,,,admin,admin,"",""\n4,iteration 2,,Iteration,,,,,,yes,#1 release 1,,,,admin,admin,"",""\n3,iteration 1,,Iteration,,,,,,yes,#1 release 1,,,,admin,admin,"",""\n11,card 2,,Task,,,,,,yes,#1 release 1,#3 iteration 1,,,admin,admin,"",""\n6,card 2,,Story,,,,,,yes,#1 release 1,#3 iteration 1,,,admin,admin,"",""}
    expected_without_description_hierarchy_view=%{Number,Name,Type,iteration,priority,size,status,Zowner,planning tree,Planning tree - release,Planning tree - iteration,Planning tree - story,count of stories,Created by,Modified by,Incomplete Checklist Items,Completed Checklist Items\n1,release 1,Release,,,,,,yes,,,,,admin,admin,"",""\n4,iteration 2,Iteration,,,,,,yes,#1 release 1,,,,admin,admin,"",""\n3,iteration 1,Iteration,,,,,,yes,#1 release 1,,,,admin,admin,"",""\n11,card 2,Task,,,,,,yes,#1 release 1,#3 iteration 1,,,admin,admin,"",""\n6,card 2,Story,,,,,,yes,#1 release 1,#3 iteration 1,,,admin,admin,"",""}
    add_card_to_tree(@tree, @r1)
    add_card_to_tree(@tree, [@i1, @i2], @r1)
    add_card_to_tree(@tree, [@stories[1],@tasks[1]], @i1)

    navigate_to_tree_view_for(@project, @tree.name)
    click_exclude_card_type_checkbox(@type_iteration)
    export_all_columns_to_excel_with_description
    assert_equal_ignore_cr(expected_with_description, get_exported_data)
    click_back_link
    export_all_columns_to_excel_without_description
    assert_equal_ignore_cr(expected_without_description, get_exported_data)

    click_back_link
    switch_to_hierarchy_view
    export_all_columns_to_excel_with_description
    assert_equal_ignore_cr(expected_with_description_hierarchy_view, get_exported_data)

    click_back_link
    export_all_columns_to_excel_without_description
    assert_equal_ignore_cr(expected_without_description_hierarchy_view, get_exported_data)

  end

  private
  def get_planning_tree_generated_with_cards_on_tree
    add_card_to_tree(@tree, @r1)
    add_card_to_tree(@tree, @i1, @r1)
    add_card_to_tree(@tree, @stories, @i1)
    add_card_to_tree(@tree, @tasks, @stories[1])
    AggregateComputation.run_once
    navigate_to_tree_view_for(@project, @tree.name)

  end

end
