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

class Scenario142ConditionalAggregateCrudTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  MANAGED_TEXT_TYPE = "Managed text list"
  FREE_TEXT_TYPE = "Allow any text"
  MANAGED_NUMBER_TYPE = "Managed number list"
  FREE_NUMBER_TYPE = "Allow any number"
  USER_TYPE = "team"
  DATE_TYPE = "date"
  CARD_TYPE = "card"
  
  MANAGED_TEXT = 'managed text'
  FREE_TEXT = 'free_text'
  MANAGED_NUMBER = 'managed number'
  FREE_NUMBER = 'free_number'
  USER = 'user'
  DATE = 'date'
  RELATED_CARD = 'related_card'
  
  
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
  
  RELEASE_ITERATION = 'release-iteration'
  ITERATION_TASK = 'iteration-task'
  TASK_STORY = 'task-story'
  
  SUM = 'Sum'
  COUNT = 'Count'
  AVERAGE = 'Average'
  MINIMUM = 'Minimum'
  MAXIMUM = 'Maximum'
  
  ALL_DESCENANTS = 'All descendants'
  DEFINE_CONDITION = AggregateScope::DEFINE_CONDITION
  
  TAG_COOKIE = 'tag_cookie'
  TAG_WAFFLE = 'tag_waffle'
  #STORY_PROPERTY = 'PT story'
  # 
  # TYPE = 'Type'
  # NEW = 'new'
  # OPEN = 'open'
  # LOW = 'low'
  # 

  # 
  # PLANNING_TREE = 'planning tree'
  # 
  # CALCULATED = '(calculated)'
  # NOT_SET = '(not set)'
  # DIRTY_NOT_SET = '* (not set)'
  # FORMULA_USING_DATE = "'#{END_DATE}' - '#{START_DATE}'"
  # FORMULA_USING_NUMERIC = "'#{SIZE}' * 2"
  # FORMULA_RESULTING_DATE = "'#{END_DATE}' + 2"
  # BLANK = ''
  # 
  # ALL_DESCENANTS = 'All descendants'
  # TREE_STORY = 'tree_story'
  # TREE_DEFECT = 'tree_defect'
  # TREE_RELEASE = 'tree_release'
  # TREE_ITERATION = 'tree_iteration'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @mingle_admin_user = users(:admin)
    @project_admin_user = users(:proj_admin)
    @non_admin_user = users(:longbob)
    @project = create_project(:prefix => 'scenario_142', :users => [@non_admin_user], :admins => [@project_admin_user, @mingle_admin_user])
    login_as_admin_user

    create_property_for_card(MANAGED_TEXT_TYPE, MANAGED_TEXT)
    create_property_for_card(FREE_TEXT_TYPE, FREE_TEXT)
    create_property_for_card(MANAGED_NUMBER_TYPE, MANAGED_NUMBER)
    create_property_for_card(FREE_NUMBER_TYPE, FREE_NUMBER)
    create_property_for_card(USER_TYPE, USER)
    create_property_for_card(DATE_TYPE, DATE)
    create_property_for_card(CARD_TYPE, RELATED_CARD)
    
    @type_release = setup_card_type(@project, RELEASE)
    @type_iteration = setup_card_type(@project, ITERATION_TYPE)
    @type_task = setup_card_type(@project, TASK, :properties => [MANAGED_NUMBER, MANAGED_TEXT, FREE_NUMBER, FREE_TEXT, DATE, RELATED_CARD, USER])
    @type_story = setup_card_type(@project, STORY, :properties => [MANAGED_NUMBER, MANAGED_TEXT, FREE_NUMBER, FREE_TEXT, DATE, RELATED_CARD, USER])
    @planning_tree = setup_tree(@project, 'Planning Tree', :types => [@type_release, @type_iteration, @type_task, @type_story], :relationship_names => [RELEASE_ITERATION, ITERATION_TASK, TASK_STORY])
  end
  
  
  def test_give_error_messages_when_the_mql_is_invalid_during_creation
    invalid_condition_of_none_existing_property = "non_exisiting_size < 4"
    invalid_condition_of_parameter_SELECT_WHERE = "SELECT '#{MANAGED_NUMBER}' WHERE NUMBER IS 1"
    invalid_condition_of_parameter_TODAY = "#{DATE} = TODAY"
    invalid_condition_of_parameter_CURRENT_USER = "#{USER} = CURRENT USER"
    invalid_condition_of_parameter_THIS_CARD = "#{RELATED_CARD} = THIS CARD"
    invalid_condition_of_parameter_FROM_TREE = "FROM TREE 'Planning TREE'"
    
    error_message_should_display = "Aggregate condition is not valid. Card property 'non_exisiting_size' does not exist!"
    error_message_for_invalid_SELECT_WHERE_para = "Aggregate condition is not valid. SELECT and ORDER BY are not required to filter by MQL. Enter MQL conditions only."
    error_message_for_invalid_TODAY_para = "TODAY is not supported in aggregate condition"
    error_message_for_invalid_CURRENT_USER_para = "CURRENT USER is not supported in aggregate condition"
    error_message_for_invalid_THIS_CARD_para = "THIS CARD is not supported in aggregate condition"
    error_message_for_invalid_FROM_TREE_para = "FROM TREE is not supported in aggregate condition"
    
    invalid_count_aggregation = create_aggregate_property_for(@project, 'invalid_count_aggregation', @planning_tree, @type_release, :aggregation_type => COUNT, 
     :scope => DEFINE_CONDITION, :condition => invalid_condition_of_none_existing_property)
    assert_error_message(error_message_should_display)
    
    type_aggreage_property_condition(invalid_condition_of_parameter_SELECT_WHERE)
    click_on_add_or_update_aggregate_property
    assert_error_message(error_message_for_invalid_SELECT_WHERE_para)
    
    type_aggreage_property_condition(invalid_condition_of_parameter_TODAY)
    click_on_add_or_update_aggregate_property
    assert_error_message(error_message_for_invalid_TODAY_para)
    
    type_aggreage_property_condition(invalid_condition_of_parameter_CURRENT_USER)
    click_on_add_or_update_aggregate_property
    assert_error_message(error_message_for_invalid_CURRENT_USER_para)
    
    type_aggreage_property_condition(invalid_condition_of_parameter_THIS_CARD)
    click_on_add_or_update_aggregate_property
    assert_error_message(error_message_for_invalid_THIS_CARD_para)
    
    type_aggreage_property_condition(invalid_condition_of_parameter_FROM_TREE)
    click_on_add_or_update_aggregate_property
    assert_error_message(error_message_for_invalid_FROM_TREE_para)
  end
  
  def test_conditional_aggregate_should_be_editable_after_saved
    count_aggregation = create_aggregate_property_for(@project, 'count_aggregation', @planning_tree, @type_release, :aggregation_type => COUNT, 
    :scope => DEFINE_CONDITION, :condition => "'#{MANAGED_NUMBER}' < 4 AND '#{FREE_NUMBER}' = 1")
    assert_text_present("Aggregate property count_aggregation was successfully created")
    # click_on_edit_aggregate_link_on_a_node_for(@type_release)s
    click_edit_aggregate_property_for(count_aggregation)
    
    new_aggregate_name = "new aggregate"
    type_aggreage_property_name("new aggregate")
    select_aggregation_type(COUNT)
    type_aggreage_property_condition("'#{MANAGED_NUMBER}' <= 3 AND '#{FREE_TEXT}' != 'I am card task_1'")
    click_on_add_or_update_aggregate_property
    assert_text_present("Aggregate property #{new_aggregate_name} updated successfully")    
  end

  def test_conditional_aggregate_should_be_deletable
    aggregation_name = "count_aggregation"
    count_aggregation = create_aggregate_property_for(@project, aggregation_name, @planning_tree, @type_release, :aggregation_type => COUNT, 
    :scope => DEFINE_CONDITION, :condition => "'#{MANAGED_NUMBER}' < 4 AND '#{FREE_NUMBER}' = 1")
    assert_text_present("Aggregate property count_aggregation was successfully created")
    click_delete_aggregate_property_for(count_aggregation)
    assert_text_present("Aggregate property #{aggregation_name} deleted successfully.")
  end
  
  #These are all general messages even there are no assotiations between conditiona aggregation and card_type, plv, tree, and property. So will add all this warning message in other tests.
   
  # def test_provide_warning_message_when_deleting_a_property_which_is_used_in_an_conditional_aggregate
  #   count_aggregation = create_aggregate_property_for(@project, 'count_aggregation', @planning_tree, @type_release, :aggregation_type => COUNT, 
  #   :scope => DEFINE_CONDITION, :condition => "'#{MANAGED_NUMBER}' < 4 AND '#{FREE_NUMBER}' = 1")
  #   navigate_to_property_management_page_for(@project)
  #   delete_property_for(@project, MANAGED_NUMBER)
  #   assert_text_present("Any MQL (Advanced filters, some Macros or aggregates using MQL conditions) that uses this property will no longer return any results.")
  # end
  # 
  # def test_provide_warning_message_when_deleting_a_PLV_which_is_used_in_an_conditional_aggregate
  #   counter_plv = create_project_variable(@project, :name => 'counter_plv', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => 1502, :properties => [FREE_NUMBER])
  #   plv_aggregation = create_aggregate_property_for(@project, 'plv_aggregation', @planning_tree, @type_release, :aggregation_type => COUNT, 
  #   :scope => DEFINE_CONDITION, :condition => "'#{FREE_NUMBER}' = (#{counter_plv.name})")
  #   delete_project_variable(@project, counter_plv.name)
  #   assert_text_present("Any MQL (Advanced filters, some Macros or aggregates using MQL conditions) that uses this property will no longer return any results.")
  # end
  # 
  # def test_provide_warning_message_when_deleting_a_card_type_which_is_used_in_an_conditional_aggregate
  #   story_level_aggregation = create_aggregate_property_for(@project, 'story_level_aggregation', @planning_tree, @type_release, :aggregation_type => COUNT, 
  #   :scope => DEFINE_CONDITION, :condition => "TYPE = STORY AND '#{MANAGED_NUMBER}' < 4")
  #   get_the_delete_confirm_message_for_card_type(@project, STORY)
  #   assert_text_present("Any MQL (Advanced filters, some Macros or aggregates using MQL conditions) that uses this property will no longer return any results.")
  # end  
end
