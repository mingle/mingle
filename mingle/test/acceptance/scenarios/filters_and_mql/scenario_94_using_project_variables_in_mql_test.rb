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

# Tags: project_variable, mql, macro
class Scenario94UsingProjectVariablesInMqlTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  STATUS = 'status'
  SIZE = 'Size'
  NEW = 'new'
  OPEN = 'open'
  BLANK = ''
  NOT_SET = '(not set)'

  PLANNING_TREE = 'Planning Tree'
  RELEASE_PROPERTY = 'Planning Tree release'
  ITERATION_PROPERTY = 'Planning Tree iteration'
  RELEASE = 'Release'
  ITERATION = 'Iteration'
  STORY = 'Story'
  BEGINS_ON = 'begins on'
  OWNER = 'Owner'

  ITERATION_1 = 'iteration 1'
  STORY_1 = 'story 1'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin = users(:proj_admin)
    @project_member = users(:project_member)
    @project = create_project(:prefix => 'scenario_82', :admins => [@project_admin], :users => [@project_member])
    setup_property_definitions(STATUS => [NEW, OPEN])
    @type_size = setup_numeric_property_definition(SIZE, ['1', '3', '5'] )
    setup_date_property_definition(BEGINS_ON)
    @type_story = setup_card_type(@project, STORY, :properties => [STATUS, SIZE])
    @type_iteration = setup_card_type(@project, ITERATION, :properties => [STATUS])
    @type_release = setup_card_type(@project, RELEASE)
    login_as_admin_user
    @release1 = create_card!(:name => 'release 1', :description => "super plan", :card_type => RELEASE)
    @release2 = create_card!(:name => 'release 2', :card_type => RELEASE)
    @iteration1 = create_card!(:name => ITERATION_1, :card_type => ITERATION)
    @iteration2 = create_card!(:name => 'iteration 2', :card_type => ITERATION)
    @story1 = create_card!(:name => STORY_1, :card_type => STORY)
    @planning_tree = setup_tree(@project, PLANNING_TREE, :types => [@type_release, @type_iteration, @type_story], :relationship_names => [RELEASE_PROPERTY, ITERATION_PROPERTY])
    add_card_to_tree(@planning_tree, @release1)
    navigate_to_project_overview_page(@project)
  end

  def test_plv_can_be_used_in_as_value_in_table
    story2 = create_card!(:name => 'story 2', :card_type => STORY, SIZE => '3')
    project_variable = setup_project_variable(@project, :name => 'nominal size', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value =>  '3', :properties => [SIZE])
    edit_overview_page
    table1 = add_table_query_and_save_on(['Name', "'#{SIZE}'"], ["'#{SIZE}' = (#{project_variable.name})"])
    assert_table_row_data_for(table1, :row_number => 1, :cell_values => [story2.name, project_variable.value])
  end

  def test_plv_can_only_used_as_value_not_property
    story2 = create_card!(:name => 'story 2', :card_type => STORY, SIZE => '3')
    project_variable = setup_project_variable(@project, :name => 'nominal size', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value =>  '3', :properties => [SIZE])
    edit_overview_page
    table1 = add_table_query_and_save_on(['Name', "'#{SIZE}'"], ["'(#{project_variable.name})' = 3"])
    assert_mql_error_messages("Error in table macro using #{@project.name} project: Card property '(#{project_variable.name})' does not exist!")
  end

  def test_proeprty_with_parenthesis_allowed_in_mql_proeprty_part_of_where_clause
    nominal_size = '(nominal size)'
    type_nominal_size = setup_numeric_property_definition(nominal_size, ['2', '4', '6'] )
    edit_card_type_for_project(@project, STORY, :properties => [type_nominal_size.name])
    story2 = create_card!(:name => 'story 2', :card_type => STORY, nominal_size => '4')
    project_variable = setup_project_variable(@project, :name => 'nominal size', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value =>  '4', :properties => [nominal_size])
    edit_overview_page
    table1 = add_table_query_and_save_on(['Name', "'#{nominal_size}'"], ["'#{nominal_size}' = (#{project_variable.name})"])
    assert_table_row_data_for(table1, :row_number => 1, :cell_values => [story2.name, project_variable.value])
  end

  def test_plv_is_restricted_to_specific_property_it_cannot_be_associated_with_other_proeprty_not_related
    nominal_size = '(nominal size)'
    type_nominal_size = setup_numeric_property_definition(nominal_size, ['2', '4', '6'] )
    edit_card_type_for_project(@project, STORY, :properties => [type_nominal_size.name, SIZE])
    story2 = create_card!(:name => 'story 2', :card_type => STORY, nominal_size => '3')
    story3 = create_card!(:name => 'story 3', :card_type => STORY, SIZE => '3')
    project_variable = setup_project_variable(@project, :name => 'nominal size', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value =>  '3', :properties => [nominal_size])

    edit_overview_page
    table1 = add_table_query_and_save_on(['Name', "'#{SIZE}'"], ["'#{SIZE}' = (#{project_variable.name})"])
    assert_mql_error_messages("Error in table macro using #{@project.name} project: Comparing between property '#{SIZE}' and project variable #{nominal_size} is invalid as they are not associated with each other.")
  end

  def test_deleting_plv_used_in_mql_will_display_proper_error_message
    story2 = create_card!(:name => 'story 2', :card_type => STORY, SIZE => '3')
    project_variable = setup_project_variable(@project, :name => 'nominal size', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value =>  '3', :properties => [SIZE])
    edit_overview_page
    table1 = add_table_query_and_save_on(['Name', "'#{SIZE}'"], ["'#{SIZE}' = (#{project_variable.name})"])
    assert_table_row_data_for(table1, :row_number => 1, :cell_values => [story2.name, project_variable.value])
    navigate_to_project_variable_management_page_for(@project)
    delete_project_variable(@project, project_variable.name)
    click_continue_to_delete
    click_overview_tab
    assert_text_present("Error in table macro using #{@project.name} project: The project variable (#{project_variable.name}) does not exist")
  end

  #bug 4759
  def test_user_can_rename_PLV_when_its_used_in_MQL_filter_whether_MQL_Filter_is_valid_or_invalid
    story2 = create_card!(:name => 'story2', :card_type => STORY, SIZE => '3')
    project_variable = setup_project_variable(@project, :name => 'set high size', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value =>  '3', :properties => [SIZE])
    navigate_to_card_list_for(@project)
    condition = "size = (set high size)"
    set_mql_filter_for(condition)
    navigate_to_card_list_for(@project)
    assert_card_present_in_list(story2)
    edit_project_variable(@project, project_variable, :new_name => 'set high size 000')
    @browser.assert_text_not_present("We're sorry")
    navigate_to_card_list_for(@project)
    assert_card_present_in_list(story2)
    set_mql_filter_for(condition)
    @browser.assert_text_present("Filter is invalid. The project variable (set high size) does not exist")
    edit_project_variable(@project, project_variable, :name => 'set high size 111')
    @browser.assert_text_not_present("We're sorry")
  end

  def test_pivot_table_provide_link_valid_for_filter_type_which_use_plv_and_valid_filter_conditions_set
    story2 = create_card!(:name => 'story 2', :card_type => STORY, SIZE => '3', STATUS => 'open')
    project_variable = setup_project_variable(@project, :name => 'nominal size', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value =>  '3', :properties => [SIZE])
    edit_overview_page
    pivot_table = add_pivot_table_query_and_save_for(STATUS, STATUS, :conditions => "Type = STORY AND SIZE = (#{project_variable.name})", :empty_rows => 'true', :empty_columns => 'true', :totals => 'true')
    @browser.click_and_wait('link=1')
    assert_mql_filter("Type = STORY AND Size = (nominal size) AND status = open AND status = open")
  end

  def test_today_can_be_used_as_current_date_in_mqls
    fake_now(2001, 01, 19)
    today_date = '19 Jan 2001'
    story2 = create_card!(:name => "my card today", BEGINS_ON => today_date)
    navigate_to_card_list_for(@project)
    edit_overview_page
    table1 = add_table_query_and_save_on(['Name', "'#{BEGINS_ON}'"], ["'#{BEGINS_ON}' IS TODAY"])
    assert_table_row_data_for(table1, :row_number => 1, :cell_values => [story2.name, today_date])
  ensure
    @browser.reset_fake
  end

  def test_current_user_can_be_used_in_mql
    login_as(@project_admin.login)
    owner = setup_user_definition(OWNER)
    edit_card_type_for_project(@project, STORY, :properties => [owner, SIZE])
    card1 = create_card!(:name => 'plain card', owner.name => @project_admin.id)
    edit_overview_page
    table1 = add_table_query_and_save_on(['Name', "'#{OWNER}'"], ["'#{OWNER}' IS CURRENT USER"])
    assert_table_row_data_for(table1, :row_number => 1, :cell_values => [card1.name, @project_admin.name_and_login])
  end

  # Bug #3506.
  def test_should_be_able_to_use_plv_in_where_clause_of_query_for_relationship_properties
    project_variable_name = 'current release'
    project_variable = setup_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_release, :value => @release1, :properties => [RELEASE_PROPERTY])
    add_card_to_tree(@planning_tree, @iteration1, @release1)
    add_card_to_tree(@planning_tree, @story1, @iteration1)
    add_card_to_tree(@planning_tree, @release2)
    add_card_to_tree(@planning_tree, @iteration2, @release2)

    edit_overview_page
    table_name = add_table_query_and_save_on(['Name', "'#{RELEASE_PROPERTY}'"], ["'#{RELEASE_PROPERTY}' = (current release)"], :order_by => ['Number'])
    assert_table_row_data_for(table_name, :row_number => 1, :cell_values => [ITERATION_1, @release1.number_and_name])
    assert_table_row_data_for(table_name, :row_number => 2, :cell_values => [STORY_1, @release1.number_and_name])
  end

  # Bug 3238.
  def test_should_be_able_to_use_plv_starting_with_today_in_where_clause_of_query_for_date_properties
    project_variable_name = 'today date'
    project_variable_value = '11 Apr 2008'
    project_variable = setup_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::DATE_DATA_TYPE, :value => project_variable_value, :properties => [BEGINS_ON])
    card_name = 'target card'
    create_card!(:name => card_name, BEGINS_ON => project_variable_value)

    edit_overview_page
    table_name = add_table_query_and_save_on(['Name', "'#{BEGINS_ON}'"], ["'#{BEGINS_ON}' = (#{project_variable_name})"])
    assert_table_row_data_for(table_name, :row_number => 1, :cell_values => [card_name, project_variable_value])
  end

  #bug 5131
  def test_should_throw_valid_error_when_mql_keyword_being_used_in_plv_name
    project_variable_name = 'tree plv'
    project_variable = setup_project_variable(@project, :name => project_variable_name, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_release, :value => @release1, :properties => [RELEASE_PROPERTY])
    edit_overview_page
    table_name = add_table_query_and_save_on(['Name', "'#{RELEASE_PROPERTY}'"], ["'#{RELEASE_PROPERTY}' = (#{project_variable_name})"])
    assert_mql_error_messages("Error in table macro: \nparse error on value \"tree\" (TREE). You may have a project variable, property, or tag with a name shared by a MQL keyword.  If this is the case, you will need to surround the variable, property, or tags with quotes.")
  end

end
