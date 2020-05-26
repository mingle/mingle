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

# Tags: mql, pivot_table, macro
class Scenario98MqlPivotTableTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  SIZE = 'size'
  SIZE2 = 'size2'
  SIZE3 = 'size3'

  OWNER = 'owner'

  ISSUE = 'Issue'
  STORY = 'Story'
  STORY0 = 'Story0'
  STORY1 = 'Story1'
  DEFECT = 'Defect'
  CARD = 'Card'
  STATUS = 'Status'
  OPEN = 'Open'
  CLOSED = 'Closed'
  IN_PROGRESS = 'In Progress'
  TAG = 'tag'
  UNMANAGED_STATUS = 'unmanaged_status'
  UNMANAGED_OPEN = 'Unmanaged_OPEN'
  UNMANAGED_CLOSED = 'Unmanaged_CLOSED'
  BLANK = ''
  NOTSET = '(not set)'
  TOTALS = 'Totals'

  PIVOT_TABLE = 'pivot-table'
  INSERT_PIVOT_TABLE = 'Insert Pivot Table'
  PIVOT_TABLE_ALL_PARAMETERS = ['columns', 'rows','conditions','aggregation','project','totals','empty-columns','empty-rows','links']
  PIVOT_TABLE_DEFAULT_PARAMETERS = ['columns', 'rows','conditions','aggregation','totals','empty-columns','empty-rows']
  PIVOT_TABLE_NON_DEFAULT_PARAMETERS = ['project', 'links']
  PIVOT_TABLE_REQUIRED_PARAMETERS = ['columns', 'rows']
  PIVOT_TABLE_NOT_REQUIRED_PARAMETERS = ['conditions','aggregation','project','totals','empty-columns','empty-rows','links']
  PIVOT_TABLE_DEFAULT_BUT_NOT_REQUIRED_PARAMETERS = ['conditions','aggregation','totals','empty-columns','empty-rows']
  PIVOT_TABLE_DEFAULT_CONTENT = %{{{
  pivot-table
    columns:
    rows:
    conditions: type = card_type
    aggregation: COUNT(*)
    totals: false
    empty-columns: true
    empty-rows: true
}}}
  PIVOT_TABLE_WITH_PARAMETER_PRESET = %{{{
  pivot-table
    columns:
    rows:
    conditions: type = card_type
    aggregation: COUNT(*)
    totals: false
    empty-columns: true
    empty-rows: true
    links: true
}}}

  CONDITION_EXAMPLE = "Example: type = card_type"
  AGGREGATE_EXAMPLE = "Example: COUNT(*)"


  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_admin_user = users(:longbob)
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_98', :users => [@non_admin_user], :admins => [@project_admin_user, users(:admin)])
    @size = setup_numeric_property_definition(SIZE, [1, 2, 3, 4])
    @size2 = setup_numeric_property_definition(SIZE2, [1, 2, 3, 4])
    @status = setup_property_definitions(STATUS => [OPEN, CLOSED])
    @type_story = setup_card_type(@project, STORY, :properties => [SIZE, SIZE2, STATUS])
    @type_defect = setup_card_type(@project, DEFECT)
    @unmanaged_status = setup_text_property_definition(UNMANAGED_STATUS)
    login_as_admin_user
    @card_1 = create_card!(:number => 88, :name => 'sample card_1', :card_type => STORY, SIZE => '2')
    @card_2 = create_card!(:number => 89, :name => 'sample card_2', :card_type => STORY, SIZE => '1')
    navigate_to_project_overview_page(@project)
  end

  # bug 6942
  def test_pivot_table_should_give_correct_value
    login_as_admin_user
    open_project(@project)
    setup_managed_number_list_definition('size_2', ['2', '20'])
    setup_property_definitions('status_2' => [])
    create_card!(:name => 'card', 'size_2'  => '20')
    edit_overview_page
    table_one = add_pivot_table_query_and_save_for("status_2", "size_2", :aggregation => "SUM(size_2)", :empty_rows => 'true', :empty_columns => 'true', :totals => 'true')
    assert_table_cell(0, 1, 1, '')
    assert_table_cell(0, 1, 2, '20')
    assert_table_cell(0, 2, 1, '')
    assert_table_cell(0, 2, 2, '20')
  end

  # macro-editor related tests
  def test_what_user_should_get_as_default_when_open_pivot_table_macro_edit
    open_wiki_page_in_edit_mode
    select_macro_editor(INSERT_PIVOT_TABLE)
    assert_should_see_macro_editor_lightbox
    assert_macro_parameters_field_exist(PIVOT_TABLE, PIVOT_TABLE_ALL_PARAMETERS)
    assert_macro_parameters_visible(PIVOT_TABLE, PIVOT_TABLE_DEFAULT_PARAMETERS)
    assert_macro_parameters_not_visible(PIVOT_TABLE, PIVOT_TABLE_NON_DEFAULT_PARAMETERS)
    assert_text_present(CONDITION_EXAMPLE)
    assert_text_present(AGGREGATE_EXAMPLE)
  end

  # bug 12596
  def test_macro_editor_preview_should_work_during_creating_new_card
    click_all_tab
    add_card_with_detail_via_quick_add('new card for bug 12596')
    select_macro_editor(INSERT_PIVOT_TABLE)
    valid_pivot_table_paras = {:columns => SIZE, :rows => STATUS, :conditions => "type is #{STORY}" , :aggregation => 'count (*)', :totals => 'false', :empty_columns => 'true', :empty_rows => 'true'}
    type_macro_parameters(PIVOT_TABLE, valid_pivot_table_paras)
    preview_macro
    preview_content_should_include(OPEN, CLOSED, NOTSET, "1", "2", "3", "4")
  end

  def test_user_should_be_able_to_add_parameters_if_there_is_more
    open_wiki_page_in_edit_mode
    select_macro_editor(INSERT_PIVOT_TABLE)
    @browser.wait_for_element_present('macro_editor_pivot-table_columns')
    assert_add_macro_parameter_icon_present(PIVOT_TABLE)
    add_macro_parameters_for(PIVOT_TABLE, PIVOT_TABLE_NON_DEFAULT_PARAMETERS)
    assert_add_macro_parameter_icon_not_present(PIVOT_TABLE)
  end

  def test_non_required_parameter_should_be_removable_once_they_are_added
    open_wiki_page_in_edit_mode
    select_macro_editor(INSERT_PIVOT_TABLE)
    @browser.wait_for_element_present('macro_editor_pivot-table_columns')
    assert_remove_macro_parameter_icons_not_present_for(PIVOT_TABLE, PIVOT_TABLE_REQUIRED_PARAMETERS+PIVOT_TABLE_NON_DEFAULT_PARAMETERS)
    add_macro_parameters_for(PIVOT_TABLE, PIVOT_TABLE_NON_DEFAULT_PARAMETERS)
    assert_remove_macro_parameter_icons_present_for(PIVOT_TABLE, PIVOT_TABLE_NON_DEFAULT_PARAMETERS)
    assert_remove_macro_parameter_icons_not_present_for(PIVOT_TABLE, PIVOT_TABLE_REQUIRED_PARAMETERS)
  end

  def test_add_and_remove_parameters_on_macro_editor
    open_wiki_page_in_edit_mode
    select_macro_editor(INSERT_PIVOT_TABLE)
    @browser.wait_for_element_present('macro_editor_pivot-table_columns')
    remove_macro_parameters_for(PIVOT_TABLE, PIVOT_TABLE_DEFAULT_BUT_NOT_REQUIRED_PARAMETERS)
    parameters = PIVOT_TABLE_NOT_REQUIRED_PARAMETERS
    parameters.each do |para|
      assert_macro_parameters_not_visible(PIVOT_TABLE, [para])
      with_open_and_close_macro_parameter_droplist(PIVOT_TABLE) { assert_parameter_present_on_drop_list_for_adding(PIVOT_TABLE, para) }

      assert_macro_parameters_not_visible(PIVOT_TABLE, [para])
      with_open_and_close_macro_parameter_droplist(PIVOT_TABLE) { assert_parameter_present_on_drop_list_for_adding(PIVOT_TABLE, para) }

      add_macro_parameter_for(PIVOT_TABLE, para)
      assert_macro_parameters_visible(PIVOT_TABLE, [para])
      with_open_and_close_macro_parameter_droplist(PIVOT_TABLE) { assert_parameter_not_present_on_drop_list_for_adding(PIVOT_TABLE, para) }
    end
  end

  def test_initial_value_for_parameters_with_static_content_in_macro_edit
    open_wiki_page_in_edit_mode
    select_macro_editor(INSERT_PIVOT_TABLE)

    add_macro_parameters_for(PIVOT_TABLE, ['links'])
    assert_macro_parmeters_have_initial_value(PIVOT_TABLE,['empty-columns','empty-rows','links','totals'])
  end

  def test_macro_editor_preview_for_pivot_macro_on_card_edit
    error_message_of_empty_input = "Error in pivot-table macro: Parameters columns, rows are required. Please check the syntax of this macro. The macro markup has to be valid YAML syntax."
    open_macro_editor_without_param_input(INSERT_PIVOT_TABLE)
    preview_macro
    preview_content_should_include(error_message_of_empty_input)

    invalid_pivot_table_paras = {:columns => 'cookie', :rows => 'waffle'}
    type_macro_parameters(PIVOT_TABLE, invalid_pivot_table_paras)
    preview_macro
    preview_content_should_include("Error in pivot-table macro: No such property: waffle")

    valid_pivot_table_paras = {:columns => SIZE, :rows => STATUS, :conditions => "type is #{STORY}" , :aggregation => 'count (*)', :totals => 'false', :empty_columns => 'true', :empty_rows => 'true'}
    type_macro_parameters(PIVOT_TABLE, valid_pivot_table_paras)
    preview_macro
    preview_content_should_include(OPEN, CLOSED, NOTSET, "1", "2", "3", "4")
    submit_macro_editor

    wait_for_wysiwyg_editor_ready
    expected_macro_content = <<-MACRO
pivot-table
    columns: size
    rows: Status
    conditions: type is Story
    aggregation: count (*)
    totals: false
    empty-columns: true
    empty-rows: true
MACRO
    edit_macro('pivot-table')
    assert_equal_ignore_cr(expected_macro_content.strip, @browser.get_value(class_locator('cke_dialog_ui_input_textarea', 1)))
  end


  #bug 7714
  def test_should_provide_better_error_message_when_using_project_as_row_or_column
    open_macro_editor_without_param_input(INSERT_PIVOT_TABLE)
    pivot_table_paras_1 = {:columns => SIZE, :rows => "project", :conditions => "type is #{STORY}" , :aggregation => 'count (*)', :totals => 'false', :empty_columns => 'true', :empty_rows => 'true'}
    error_message_1 = "Error in pivot-table macro: Cannot use project as the rows parameter."
    pivot_table_paras_2 = {:columns => "project", :rows => SIZE, :conditions => "type is #{STORY}" , :aggregation => 'count (*)', :totals => 'false', :empty_columns => 'true', :empty_rows => 'true'}
    error_message_2 = "Error in pivot-table macro: Cannot use project as the columns parameter."

    type_macro_parameters(PIVOT_TABLE, pivot_table_paras_1)
    preview_macro
    preview_content_should_include(error_message_1)
    type_macro_parameters(PIVOT_TABLE, pivot_table_paras_2)
    preview_macro
    preview_content_should_include(error_message_2)
  end

  def test_link_is_clickable_on_macro_editor_preview_for_pivot_macro_on_card_edit
    new_card = create_card!(:name => 'new card', :card_type => STORY, STATUS => CLOSED)
    open_macro_editor_without_param_input(INSERT_PIVOT_TABLE)
    pivot_table_paras = {:columns => SIZE, :rows => STATUS, :conditions => "type is #{STORY}" , :aggregation => 'count (*)', :totals => 'false', :empty_columns => 'true', :empty_rows => 'true', :links => 'true'}
    type_macro_parameters(PIVOT_TABLE, pivot_table_paras)
    preview_macro
    click_link(CLOSED)
    assert_mql_filter("Type = #{STORY} AND #{STATUS} = #{CLOSED}")
    assert_card_present_in_list(new_card)
  end

  def test_using_keyword_NUMBER_in_pivot_table
    other_card = create_property_definition_for(@project, 'other_card', :type => 'card', :types => [STORY])
    story_new_1 = create_card!(:name => 'story_new_1', :card_type => STORY, SIZE => '1', STATUS => OPEN)
    story_new_2 = create_card!(:name => 'story_new_2', :card_type => STORY, SIZE => '2', STATUS => CLOSED)
    story_new_3 = create_card!(:name => 'story_new_3', :card_type => STORY, SIZE => '3', STATUS => CLOSED)
    story_new_4 = create_card!(:name => 'story_new_4', :card_type => STORY, SIZE => '4', STATUS => CLOSED)
    open_card(@project, story_new_1)
    set_relationship_properties_on_card_show('other_card' => story_new_2)
    open_card(@project, story_new_2)
    set_relationship_properties_on_card_show('other_card' => story_new_3)
    open_card(@project, story_new_3)
    set_relationship_properties_on_card_show('other_card' => story_new_4)
    open_card(@project, story_new_4)
    set_relationship_properties_on_card_show('other_card' => story_new_1)
    navigate_to_project_overview_page(@project)
    edit_overview_page

    table1 = add_pivot_table_query_and_save_for(@status[0].name, @size.name, :conditions => "Type = #{STORY} AND other_card >= NUMBER #{story_new_2.number}")
    assert_table_column_headers_and_order(table1,'1','2','3','4',NOTSET)
    assert_table_row_headers_and_order(table1, OPEN, CLOSED, NOTSET)
    click_link(CLOSED)
    assert_mql_filter("Type = #{STORY} AND other_card >= NUMBER #{story_new_2.number} AND #{STATUS} = #{CLOSED}")
    assert_card_present_in_list(story_new_3)
    assert_card_present_in_list(story_new_2)
    navigate_to_project_overview_page(@project)
    click_link(OPEN)
    assert_mql_filter("Type = #{STORY} AND other_card >= NUMBER #{story_new_2.number} AND #{STATUS} = #{OPEN}")
    assert_card_present_in_list(story_new_1)

    navigate_to_project_overview_page(@project)
    edit_overview_page
    table1 = add_pivot_table_query_and_save_for(@status[0].name, @size.name, :conditions => "Type = #{STORY} AND other_card NUMBERS IN (#{story_new_1.number}, #{story_new_2.number})")
    click_link(CLOSED)
    assert_mql_filter("Type = #{STORY} AND other_card NUMBER IN (#{story_new_1.number}, #{story_new_2.number}) AND #{STATUS} = #{CLOSED}")
    assert_card_present_in_list(story_new_4)
    navigate_to_project_overview_page(@project)
    click_link(OPEN)
    assert_mql_filter("Type = #{STORY} AND other_card NUMBER IN (#{story_new_1.number}, #{story_new_2.number}) AND #{STATUS} = #{OPEN}")
    assert_card_present_in_list(story_new_1)
  end

  def test_condition_type_OR_property_A_OR_property_B_should_work
    card_3 = create_card!(:number => 90, :name => 'sample card_3', :card_type => STORY, SIZE2 => '2',STATUS => OPEN)
    edit_overview_page
    table1 = add_pivot_table_query_and_save_for(@status[0].name, @size.name, :conditions => "Type = '#{DEFECT}' OR '#{@size.name}' = 2 OR '#{@status[0].name}' = #{OPEN}")
    assert_table_column_headers_and_order(table1,'1','2','3','4',NOTSET)
    assert_table_row_headers_and_order(table1, OPEN, CLOSED, NOTSET)
    click_link(OPEN)
    assert_mql_filter("((((Type = #{DEFECT}) OR (#{@size.name} = 2))) OR (#{STATUS} = Open)) AND #{STATUS} = #{OPEN}")
    assert_card_present_in_list(card_3)
    assert_cards_not_present_in_list(@card_1, @card_2)
    assert_column_present_for(@status[0].name, @size.name)
  end

  def test_condition_type_OR_propertyA_AND_propertyB_should_work
    card_3 = create_card!(:number => 90, :name => 'sample card_3', :card_type => STORY, SIZE => '2',STATUS => OPEN)
    edit_overview_page
    table1 = add_pivot_table_query_and_save_for(@status[0].name, @size.name, :conditions => "Type = '#{DEFECT}' OR '#{@size.name}' = 2 AND '#{@status[0].name}' = #{OPEN}")
    assert_table_column_headers_and_order(table1,'1','2','3','4','(not set)')
    assert_table_row_headers_and_order(table1, OPEN, CLOSED, NOTSET)
    click_link(OPEN)
    assert_mql_filter("((Type = #{DEFECT}) OR (#{@size.name} = 2 AND #{STATUS} = #{OPEN})) AND #{STATUS} = #{OPEN}")
    assert_card_present_in_list(card_3)
    assert_column_present_for(@status[0].name, @size.name)
  end

  def test_condition_tagged_with_type_should_work
    card_3 = create_card!(:number => 90, :name => 'sample card_3', :card_type => STORY, SIZE => '2',STATUS => OPEN, :tags => [TAG])
    edit_overview_page
    table1 = add_pivot_table_query_and_save_for(@status[0].name, @size.name, :conditions => "tagged with #{TAG} OR '#{@size.name}' = 2 AND '#{@status[0].name}' = #{OPEN}")
    assert_table_column_headers_and_order(table1,'1','2','3','4',NOTSET)
    click_link(OPEN)
    assert_mql_filter("((TAGGED WITH tag) OR (#{@size.name} = 2 AND #{STATUS} = #{OPEN})) AND #{STATUS} = #{OPEN}")
    assert_card_present_in_list(card_3)
    assert_column_present_for(@status[0].name, @size.name)
  end

  def test_condition_without_type_but_with_universal_property_should_work
    card_3 = create_card!(:number => 90, :name => 'sample card_3', :card_type => STORY, STATUS => OPEN)
    edit_overview_page
    table1 = add_pivot_table_query_and_save_for(@status[0].name, @size.name, :conditions => "'#{@size.name}' = 2 OR '#{@status[0].name}' = #{OPEN}")
    assert_table_column_headers_and_order(table1,'1','2','3','4',NOTSET)
    assert_table_row_headers_and_order(table1, OPEN, CLOSED, NOTSET)
    click_link(OPEN)
    assert_mql_filter("((#{@size.name} = 2) OR (#{STATUS} = #{OPEN})) AND #{STATUS} = #{OPEN}")
    assert_card_present_in_list(card_3)
    assert_cards_not_present_in_list(@card_1)
    assert_column_present_for(@status[0].name, @size.name)
  end

  def test_condition_property_IN_set_should_work
    card_3 = create_card!(:number => 90, :name => 'sample card_3', :card_type => STORY, SIZE2 => '2',STATUS => OPEN)
    edit_overview_page
    table1 = add_pivot_table_query_and_save_for(@status[0].name, @size.name, :conditions => "Type IN ('#{CARD}',#{STORY}) OR '#{@size.name}' IN (1,2,3,4) OR '#{@status[0].name}' IN (#{OPEN},#{CLOSED})")
    assert_table_column_headers_and_order(table1,'1','2','3','4',NOTSET)
    assert_table_row_headers_and_order(table1, OPEN, CLOSED, NOTSET)
    assert_table_row_data_for(table1, :row_number => 1, :cell_values => [BLANK, BLANK, BLANK, BLANK, '1'])
    assert_table_row_data_for(table1, :row_number => 3, :cell_values => ['1', '1', BLANK, BLANK, BLANK])
    click_link(OPEN)
    assert_mql_filter("((((Type IN (#{CARD}, #{STORY})) OR (#{@size.name} IN (1, 2, 3, 4)))) OR (#{STATUS} IN (#{OPEN}, #{CLOSED}))) AND #{STATUS} = #{OPEN}")
    assert_card_present_in_list(card_3)
    assert_column_present_for(@status[0].name, @size.name)
  end

  def test_condition_with_operators_MORE_THAN_LESS_THAN_NOT_EQUAL_TO_should_work
    card_3 = create_card!(:number => 90, :name => 'sample card_3', :card_type => STORY, SIZE => '2',STATUS => OPEN)
    card_4 = create_card!(:number => 91, :name => 'sample card_4', :card_type => STORY, SIZE => '3',STATUS => CLOSED)

    edit_overview_page
    table1 = add_pivot_table_query_and_save_for(@status[0].name, @size.name, :conditions => "type = #{STORY} AND #{@size.name} >= 2 AND #{@size.name} <= 3 AND #{@status[0].name} != #{CLOSED}")
    assert_table_column_headers_and_order(table1,'1','2','3','4',NOTSET)
    assert_table_row_headers_and_order(table1, OPEN, CLOSED, NOTSET)
    assert_table_row_data_for(table1, :row_number => 1, :cell_values => [BLANK, 1, BLANK, BLANK, BLANK])
    assert_table_row_data_for(table1, :row_number => 2, :cell_values => [BLANK, BLANK, BLANK, BLANK, BLANK])
    assert_table_row_data_for(table1, :row_number => 3, :cell_values => [BLANK, 1, BLANK, BLANK, BLANK])

    click_link(OPEN)
    assert_mql_filter("Type = #{STORY} AND #{@size.name} >= 2 AND #{@size.name} <= 3 AND #{STATUS} != #{CLOSED} AND #{STATUS} = #{OPEN}")
    assert_card_present_in_list(card_3)
    assert_column_present_for(@status[0].name, @size.name)
  end

  def test_condition_allows_NULL_or_NOT_NULL
    card_3 = create_card!(:number => 90, :name => 'sample card_3', :card_type => STORY, SIZE2 => '2',STATUS => OPEN)
    edit_overview_page
    table1 = add_pivot_table_query_and_save_for(@status[0].name, @size.name, :conditions => "'#{@size2.name}' IS NULL OR '#{@status[0].name}' IS NOT NULL")
    assert_table_column_headers_and_order(table1,'1','2','3','4',NOTSET)
    assert_table_row_headers_and_order(table1, OPEN, CLOSED, NOTSET)
    assert_table_row_data_for(table1, :row_number => 1, :cell_values => [BLANK, BLANK, BLANK, BLANK, 1])
    assert_table_row_data_for(table1, :row_number => 3, :cell_values => [1, 1, BLANK, BLANK, BLANK])
    click_link(OPEN)
    assert_mql_filter("((#{@size2.name} IS NULL) OR (#{STATUS} IS NOT NULL)) AND #{STATUS} = #{OPEN}")
    assert_card_present_in_list(card_3)
    assert_column_present_for(@status[0].name, @size.name)
  end

  def test_mql_filter_card_list_should_able_to_saved_as_favorite
    card_3 = create_card!(:number => 90, :name => 'sample card_3', :card_type => STORY, STATUS => OPEN)
    card_4 = create_card!(:number => 91, :name => 'sample card_3', :card_type => DEFECT)
    edit_overview_page
    table1 = add_pivot_table_query_and_save_for(@status[0].name, @size.name, :conditions => "Type = '#{DEFECT}' OR '#{@size.name}' = 2 OR '#{@status[0].name}' = #{OPEN}")
    assert_table_column_headers_and_order(table1, '1', '2', '3', '4', NOTSET)
    assert_table_row_headers_and_order(table1, OPEN, CLOSED, NOTSET)
    assert_table_row_data_for(table1, :row_number => 1, :cell_values => [BLANK, BLANK, BLANK, BLANK, 1])
    assert_table_row_data_for(table1, :row_number => 3, :cell_values => [BLANK, 1, BLANK, BLANK, 1])
    click_link(NOTSET)
    assert_mql_filter("((((Type = #{DEFECT}) OR (#{SIZE} = 2))) OR (#{STATUS} = #{OPEN})) AND #{SIZE} IS NULL")
    assert_card_present_in_list(card_3)
    assert_card_present_in_list(card_4)

    assert_column_present_for(@status[0].name, @size.name)
    create_card_list_view_for(@project, 'ORORVIEW')
    remove_column_for(@project, [@size.name])
    switch_to_grid_view
    open_saved_view('ORORVIEW')
    assert_mql_filter("((((Type = #{DEFECT}) OR (#{SIZE} = 2))) OR (#{STATUS} = #{OPEN})) AND #{SIZE} IS NULL")
    assert_card_present_in_list(card_3)
    assert_card_present_in_list(card_4)

    assert_column_present_for(@status[0].name, @size.name)
    @browser.assert_element_present("link=Manage team favorites and tabs")
  end

  def test_PLV_can_be_used_in_condition_of_pivot_table
    plv = create_project_variable(@project, :name => 'new_plv', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'i am plv', :properties => [STATUS])
    card_3 = create_card!(:number => 90, :name => 'sample card_3', :card_type => STORY, SIZE2 => '2',STATUS => "#{plv.value}")
    navigate_to_project_overview_page(@project)
    edit_overview_page
    table1 = add_pivot_table_query_and_save_for(@status[0].name, @size.name, :conditions => "Type = '#{DEFECT}' OR '#{@status[0].name}' = (#{plv.name})")
    click_link(plv.value)
    assert_mql_filter("((Type = #{DEFECT}) OR (#{STATUS} = (#{plv.name}))) AND #{STATUS} = 'i am plv'")
    assert_card_present_in_list(card_3)
    assert_column_present_for(@status[0].name, @size.name)
  end

  def test_relationship_can_be_used_in_pivot_table_as_condition_or_rows
    tree = setup_tree(@project, 'tree1', :types => [@type_story, @type_defect], :relationship_names => ['relation - story'])
    story_card = create_card!(:name => 'story 1', :type => STORY)
    defect_card = create_card!(:name => 'defect 1', :type => DEFECT)
    defect_card2 = create_card!(:name => 'defect 2', :type => DEFECT)
    add_card_to_tree(tree, story_card)
    add_card_to_tree(tree, defect_card, story_card)
    edit_overview_page
    table1 = add_pivot_table_query_and_save_for('relation - story', @size.name, :conditions => "Type = '#{DEFECT}' OR 'relation - story' = '#{story_card.name}'")
    assert_table_row_headers_and_order(table1,'#1 story 1', '#88 sample card_1', '#89 sample card_2', NOTSET)
    click_link("#1 story 1")
    assert_mql_filter("((Type = #{DEFECT}) OR ('relation - story' = '#{story_card.name}')) AND 'relation - story' = NUMBER #{story_card.number}")
    assert_card_present_in_list(defect_card)
    assert_column_present_for('relation - story')
  end


 #bug4828
 def test_set_empty_columns_or_empty_rows_to_false
   type_new_defect = setup_card_type(@project, 'NEW_DEFECT', :properties => [SIZE])
   tree = setup_tree(@project, 'new_tree', :types => [@type_story, type_new_defect], :relationship_names => ['relation'])
   story_card = create_card!(:name => 'story1', :card_type => STORY, SIZE => '1')
   defect_card = create_card!(:name  => 'defect', :type => 'NEW_DEFECT', SIZE => '1')
   add_card_to_tree(tree, story_card)
   add_card_to_tree(tree, defect_card, story_card)
   edit_overview_page
   table1 = add_pivot_table_query_and_save_for('relation', @size.name, :conditions => "Type = NEW_DEFECT and relation = NUMBER 1", :empty_columns => 'false', :empty_rows => 'false')
   assert_table_row_headers_and_order(table1, '#1 story1')
   assert_table_column_headers_and_order(table1, '1')
 end


 #bug 4460
  def test_pivot_tables_macros_should_render_properly_in_overview_page
    edit_overview_page
    @card_3 = create_card!(:number => 90, :name => 'sample card_3', :card_type => STORY, SIZE => '3')
    @card_4 = create_card!(:number => 91, :name => 'sample card_4', :card_type => STORY, SIZE => '4')
    @card_5 = create_card!(:number => 92, :name => 'sample card_5', :card_type => STORY, SIZE => '5')
    query1 = generate_pivot_table_query(@status[0].name, @size.name, :totals => true, :conditions => "Type = '#{STORY}'")
    table1 = "pivot-table-#{STATUS}-#{SIZE}"
    query2 = generate_pivot_table_query(@status[0].name, @size.name, :conditions => "'#{@size2.name}' IS NULL OR '#{@status[0].name}' IS NOT NULL")
    query3 = generate_pivot_table_query(@status[0].name, @size.name, :totals => true, :conditions => "Type = '#{STORY}' AND #{SIZE} = '1' OR #{STATUS} = OPEN")
    query4 = generate_pivot_table_query(@status[0].name, @size.name, :totals => true, :conditions => "Type = '#{STORY}' AND #{SIZE} = '2' OR #{STATUS} = OPEN")
    query5 = generate_pivot_table_query(@status[0].name, @size.name, :totals => true, :conditions => "Type = '#{STORY}' AND #{SIZE} = '3' OR #{STATUS} = OPEN")
    query6 = generate_pivot_table_query(@status[0].name, @size.name, :totals => true, :conditions => "Type = '#{STORY}' AND #{SIZE} = '4' OR #{STATUS} = CLOSED")
    query7 = generate_pivot_table_query(@status[0].name, @size.name, :totals => true, :conditions => "Type = '#{STORY}' AND #{SIZE} = '1' OR #{STATUS} = CLOSED")
    create_free_hand_macro(query1)
    create_free_hand_macro(query2)
    create_free_hand_macro(query3)
    create_free_hand_macro(query4)
    create_free_hand_macro(query5)
    create_free_hand_macro(query6)
    paste_query_and_save(query7)
    assert_table_column_headers_and_order(table1, '1', '2', '3', '4', '5', NOTSET)
  end


 #bug 4689
  def test_pivot_table_should_display_actual_cards_when_number_property_value_is_0
    size3 = setup_numeric_property_definition(SIZE3, [0,1,2,3])
    type_story0 = setup_card_type(@project, STORY0, :properties => [SIZE, SIZE2, SIZE3, STATUS])
    card_3 = create_card!(:number => 90, :name => 'sample card_3', :card_type => STORY0, SIZE3 => '0',STATUS => OPEN)
    card_4 = create_card!(:number => 91, :name => 'sample card_4', :card_type => STORY0, SIZE3 => '1',STATUS => CLOSED)
    card_5 = create_card!(:number => 92, :name => 'sample card_5', :card_type => STORY0, SIZE3 => '2')
    card_6 = create_card!(:number => 93, :name => 'sample card_5', :card_type => STORY0, SIZE3 => '3')
    card_7 = create_card!(:number => 94, :name => 'sample card_7', :card_type => STORY0, STATUS => CLOSED)
    edit_overview_page
    table1 = add_pivot_table_query_and_save_for(@status[0].name, size3.name, :totals => true, :conditions => "Type = '#{STORY0}'")
    assert_table_column_headers_and_order(table1, '0', '1', '2', '3', NOTSET)
    assert_table_row_headers_and_order(table1, OPEN, CLOSED, NOTSET, TOTALS)
    assert_table_row_data_for(table1, :row_number => 1, :cell_values => [1, BLANK, BLANK, BLANK, BLANK])
    assert_table_row_data_for(table1, :row_number => 2, :cell_values => [BLANK, 1, BLANK, BLANK, 1])
    assert_table_row_data_for(table1, :row_number => 3, :cell_values => [BLANK, BLANK, 1, 1, BLANK])
    assert_table_row_data_for(table1, :row_number => 4, :cell_values => [1, 1, 1, 1, 1])
    click_link("Open")
    assert_card_present_in_list(card_3)
    assert_mql_filter("Type = #{STORY0} AND #{STATUS} = Open")
  end

 # bug 4699, 7057
  def test_formula_property_name_can_be_used_as_columns
   card_3 = create_card!(:number => 90, :name => 'sample card_3', :card_type => STORY)
   formula_property_name = 'story_size_times_2'
   formula = "#{@size.name} * 2"
   create_property_definition_for(@project, formula_property_name, :type => 'formula', :formula => formula, :types => [STORY])
   navigate_to_project_overview_page(@project)
   edit_overview_page
   table1 = add_pivot_table_query_and_save_for(@size.name,formula_property_name, :totals  => true,:conditions => "Type = '#{STORY}' OR '#{@size.name}' = 2 OR '#{@status[0].name}' = #{OPEN}")
   assert_table_row_headers_and_order(table1, '1', '2', '3','4',NOTSET,TOTALS)
   assert_table_row_data_for(table1, :row_number => 6, :cell_values => [1, 1, 1])

   edit_overview_page
   table_with_link_parameter_set_to_false = add_pivot_table_query_and_save_for(@size.name,formula_property_name, :totals  => true,:conditions => "Type = '#{STORY}' OR '#{@size.name}' = 2 OR '#{@status[0].name}' = #{OPEN}", :links => 'false')
   assert_table_row_headers_and_order(table1, '1', '2', '3','4',NOTSET,TOTALS)
   assert_table_row_data_for(table1, :row_number => 6, :cell_values => [1, 1, 1])
  end

  # bug 3718
  def test_two_pivot_tables_that_use_same_user_property_will_not_create_two_not_set_columns
    edit_overview_page
    owner_property = setup_user_definition('owner')

    create_card!(:name => 'one', :card_type => CARD, :size => '1', :owner => @non_admin_user.id)
    create_card!(:name => 'two', :card_type => CARD, :size => '2', :owner => @project_admin_user.id)
    create_free_hand_macro(generate_pivot_table_query(owner_property.name, @size.name, :totals => true, :conditions => "Type = #{CARD}", :id => 'table1'))
    paste_query_and_save(generate_pivot_table_query(owner_property.name, @size.name, :totals => true, :conditions => "Type = #{CARD}", :id => 'table2'))

    assert_table_row_headers_and_order('table1', 'admin@email.com (admin)', 'longbob@email.com (longbob)', 'proj_admin@email.com (proj_admin)', '(not set)', 'Totals')
    assert_table_row_headers_and_order('table2', 'admin@email.com (admin)', 'longbob@email.com (longbob)', 'proj_admin@email.com (proj_admin)', '(not set)', 'Totals')
  end

  # bug 3334
  def test_pivot_table_headers_show_card_number_and_name_for_relationship_property_values
    @project.cards.select {|card| card.card_type_name == STORY}.each(&:destroy)

    some_story = create_card!(:name => 'some story', :card_type => STORY)
    some_defect = create_card!(:name => 'some defect', :card_type => DEFECT)
    tree = setup_tree(@project, 'some tree', :types => [@type_story, @type_defect], :relationship_names => ['some tree - story'])
    add_card_to_tree(tree, some_story)
    add_card_to_tree(tree, some_defect, some_story)

    story_property = @project.find_property_definition('some tree - story')

    edit_overview_page
    pivot_table = add_pivot_table_query_and_save_for(story_property.name, story_property.name, :conditions => "Type = '#{DEFECT}'",
      :empty_columns => false, :empty_rows => false)

    assert_table_row_headers_and_order(pivot_table, "##{some_story.number} some story", '(not set)')
    assert_table_column_headers_and_order(pivot_table, "##{some_story.number} some story", '(not set)')
  end

  # bug 2860
  def test_pivot_table_with_invalid_aggregation_will_result_in_pretty_error
    invalid_aggregation = "SUM(*)"
    edit_overview_page
    pivot_table = add_pivot_table_query_and_save_for(SIZE, SIZE2, :conditions => "Type = '#{STORY}'", :aggregation => invalid_aggregation)
    assert_mql_error_messages("* can only be used with the count aggregate function.")
  end

  #bug 4700
  def test_unmanaged_text_or_number_can_be_used_as_columns_or_rows
    type_new_story = setup_card_type(@project, STORY1, :properties => [SIZE, SIZE2, UNMANAGED_STATUS])
    card_3 = create_card!(:number => 90, :name => 'sample card_3', :card_type => STORY1, SIZE => '1',UNMANAGED_STATUS => UNMANAGED_OPEN)
    card_4 = create_card!(:number => 91, :name => 'sample card_4', :card_type => STORY1, SIZE => '2',UNMANAGED_STATUS => UNMANAGED_CLOSED)
    edit_overview_page
    table1 = add_pivot_table_query_and_save_for(@unmanaged_status.name, @size.name, :empty_columns => true, :empty_rows => true, :totals => true, :conditions => "Type = #{STORY1}")
    assert_table_column_headers_and_order(table1, '1', '2', '3', '4', NOTSET)
    assert_table_row_headers_and_order(table1, UNMANAGED_CLOSED, UNMANAGED_OPEN, NOTSET, TOTALS)
    assert_table_row_data_for(table1, :row_number => 1, :cell_values => [BLANK, 1, BLANK, BLANK, BLANK])
    assert_table_row_data_for(table1, :row_number => 2, :cell_values => [1, BLANK, BLANK, BLANK, BLANK])
    assert_table_row_data_for(table1, :row_number => 3, :cell_values => [BLANK, BLANK, BLANK, BLANK, BLANK])
    assert_table_row_data_for(table1, :row_number => 4, :cell_values => [1, 1, BLANK, BLANK, BLANK])
  end

  # bug 4703
  def test_pivot_table_links_should_work_for_conditions_having_IN_clause
    create_enumeration_value_for(@project, STATUS, IN_PROGRESS)
    card_1 = create_card!(:number => 90, :name => 'sample card_1', :card_type => STORY, STATUS => IN_PROGRESS, SIZE => '2')
    edit_overview_page
    table1 = add_pivot_table_query_and_save_for(STATUS, SIZE, :conditions => "#{STATUS} IN ('#{IN_PROGRESS}')", :empty_columns => true, :empty_rows => true, :totals => true)
    click_link(IN_PROGRESS)
    assert_card_present_in_list(card_1)
    assert_mql_filter("#{STATUS} IN ('#{IN_PROGRESS}') AND #{STATUS} = '#{IN_PROGRESS}'")
  end

  # Bug 6918
  def test_should_be_able_link_to_conditions_with_card_types_which_begin_with_IS
    setup_card_type(@project, ISSUE, :properties => [SIZE, STATUS])
    open_card = create_card!(:name => 'open card', :card_type => ISSUE, SIZE => '1', STATUS => OPEN)
    closed_card = create_card!(:name => 'closed card', :card_type => ISSUE, SIZE => '1', STATUS => CLOSED)
    edit_overview_page
    add_pivot_table_query_and_save_for STATUS, SIZE, :conditions => "type = '#{ISSUE}'"
    click_link OPEN
    assert_card_present open_card
    assert_card_not_present closed_card
  end

  #Story 7890 - Using THIS CARD.property in macro.
  def test_can_use_this_card_property_value_for_the_parameters_used_in_pivot_table_macro
    columns = setup_managed_text_definition("columns", [SIZE])
    rows = setup_managed_text_definition("rows", [STATUS])
    conditions = setup_managed_text_definition("conditions", ["type is #{STORY}"])
    aggregation = setup_managed_text_definition("aggregation", ["count (*)"])
    add_properties_for_card_type(@type_story,[columns, rows, conditions, aggregation])
    story_1 = create_card!(:name => 'story_1', :card_type => STORY, SIZE => '2', STATUS => "#{OPEN}", "columns" => "#{SIZE}", "rows" => "#{STATUS}", "conditions" => "type is #{STORY}", "aggregation" => "count (*)")
    story_2 = create_card!(:name => 'story_2', :card_type => STORY, SIZE => '1', STATUS => "#{CLOSED}")
    open_card(@project, story_1.number)
    click_edit_link_on_card
    select_macro_editor(INSERT_PIVOT_TABLE)
    type_macro_parameters(PIVOT_TABLE, :columns =>"THIS CARD.columns", :rows => "THIS CARD.rows", :conditions => "THIS CARD.conditions", :aggregation => "THIS CARD.aggregation")
    preview_macro
    preview_content_should_include(OPEN, CLOSED, NOTSET, "1", "2", "3", "4")
    expected_macro_content = <<-MACRO
{{
  pivot-table
    columns: THIS CARD.columns
    rows: THIS CARD.rows
    conditions: THIS CARD.conditions
    aggregation: THIS CARD.aggregation
    totals: false
    empty-columns: true
    empty-rows: true
}}
    MACRO
    submit_macro_editor
    save_card
    assert_table_cell_on_preview(0, 1, "1")
    assert_table_cell_on_preview(0, 2, "2")
    assert_table_cell_on_preview(0, 3, "3")
    assert_table_cell_on_preview(0, 4, "4")
    assert_table_cell_on_preview(0, 5, "#{NOTSET}")
    assert_table_cell_on_preview(1, 0, "#{OPEN}")
    assert_table_cell_on_preview(2, 0, "#{CLOSED}")
    assert_table_cell_on_preview(3, 0, "#{NOTSET}")
  end

  def test_pivot_should_show_and_sort_display_name_and_login_name
    logins_and_display_names = [
      {:login => 'a_admin', :name => "admin"},
      {:login => 'b_admin', :name => "admin"},
      {:login => 'cap',     :name => "B admin"},
      {:login => 'uncap',   :name =>  "b admin"},
      {:login => 'c_admin', :name => "c admin"},
    ]
    users_used_in_pivot_table = create_new_users(logins_and_display_names)
    property_used_in_table_query = setup_user_definition(OWNER).update_attributes(:card_types => [@project.card_types.find_by_name("Card")])
    users_used_in_pivot_table.each do |user|
      @project.add_member(user)
      card_used_in_pivot_table = create_card!(:name => 'cookie', :card_type => 'Card', 'owner' =>  user.id)
    end
    expected_result = users_used_in_pivot_table.collect(&:name_and_login) + ["(not set)"]


    open_card_for_edit(@project, 1)
    table_using_user_as_row = add_pivot_table_query_and_save_for(OWNER,'number', :empty_rows => 'false', :empty_columns => 'false')
    assert_table_row_headers_and_order(table_using_user_as_row, *expected_result)

    click_edit_link_on_card
    table_using_user_as_column = add_pivot_table_query_and_save_for('number', OWNER , :empty_rows => 'false', :empty_columns => 'false')
    assert_table_column_headers_and_order(table_using_user_as_column, *expected_result)

    destroy_users_by_logins(users_used_in_pivot_table.collect(&:login))

  end
end
