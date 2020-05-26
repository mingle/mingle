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

class Scenario143ConditionalAggregateUsageTest < ActiveSupport::TestCase

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

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @mingle_admin_user = users(:admin)
    @project_admin_user = users(:proj_admin)
    @non_admin_user = users(:longbob)
    @project = create_project(:prefix => 'scenario_143', :users => [@non_admin_user], :admins => [@project_admin_user, @mingle_admin_user])
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
  end
  
  def test_using_conditional_aggregate_for_all_kinds_of_properties_and_condition_clauses
    planning_tree = setup_tree(@project, 'Planning Tree', :types => [@type_release, @type_iteration, @type_task, @type_story], :relationship_names => [RELEASE_ITERATION, ITERATION_TASK, TASK_STORY])
    count_aggregation = create_aggregate_property_for(@project, 'count_aggregation', planning_tree, @type_release, :aggregation_type => COUNT, 
    :scope => DEFINE_CONDITION, :condition => "'#{MANAGED_NUMBER}' < 4 AND '#{FREE_NUMBER}' = 1")
    sum_aggregation = create_aggregate_property_for(@project, 'sum_aggregation',planning_tree, @type_release, :aggregation_type => SUM, 
    :scope => DEFINE_CONDITION, :condition => "'#{MANAGED_NUMBER}' <= 3 AND '#{FREE_TEXT}' != 'I am card task_1'", :property_to_aggregate => MANAGED_NUMBER)
    average_aggregation = create_aggregate_property_for(@project, 'average_aggregation', planning_tree, @type_release, :aggregation_type => AVERAGE, 
    :scope => DEFINE_CONDITION, :condition => "'#{FREE_NUMBER}' > 2 OR #{DATE} = '02 Jan 2001'", :property_to_aggregate => MANAGED_NUMBER)  
    minimum_aggregation = create_aggregate_property_for(@project, 'minimum_aggregation', planning_tree, @type_release, :aggregation_type => MINIMUM, 
     :scope => DEFINE_CONDITION, :condition => "'#{FREE_NUMBER}' >= 1 AND '#{USER}' = '#{@mingle_admin_user.login}'", :property_to_aggregate => MANAGED_NUMBER)
    maximum_aggregation = create_aggregate_property_for(@project, 'maximum_aggregation', planning_tree, @type_release, :aggregation_type => MAXIMUM, 
    :scope => DEFINE_CONDITION, :condition => "'#{MANAGED_NUMBER}' > 1 AND '#{MANAGED_TEXT}' IS NOT 'very high'", :property_to_aggregate => MANAGED_NUMBER)
    aggregation_1 = create_aggregate_property_for(@project, 'aggregation_1', planning_tree, @type_release, :aggregation_type => AVERAGE, 
    :scope => DEFINE_CONDITION, :condition => "'#{MANAGED_TEXT}' IN ('high', 'very high')", :property_to_aggregate => MANAGED_NUMBER)
    properties_comparision_aggregation = create_aggregate_property_for(@project, 'aggregation_2', planning_tree, @type_release, :aggregation_type => COUNT, 
    :scope => DEFINE_CONDITION, :condition => "'#{MANAGED_NUMBER}' > PROPERTY '#{FREE_NUMBER}'")
    string_comparision_aggregation = create_aggregate_property_for(@project, 'aggregation_3', planning_tree, @type_release, :aggregation_type => COUNT, 
    :scope => DEFINE_CONDITION, :condition => "'#{MANAGED_TEXT}' > 'high'")    
    release_1 = create_card!(:name => 'release 1', :card_type => @type_release)
    iteration_1 = create_card!(:name => 'iteration 1', :card_type => @type_iteration)
    task_1 = create_card!(:name => 'task 1', :card_type => @type_task, FREE_TEXT => "I am card task_1", FREE_NUMBER => 1, MANAGED_TEXT => 'low',  MANAGED_NUMBER => 1, DATE => '01 Jan 2001', USER => @mingle_admin_user.id)
    task_2 = create_card!(:name => 'task 2', :card_type => @type_task, FREE_TEXT => "I am card task_2", FREE_NUMBER => 1, MANAGED_TEXT => 'medium',  MANAGED_NUMBER => 2, DATE => '02 Jan 2001', USER => @non_admin_user.id)
    task_3 = create_card!(:name => 'task 3', :card_type => @type_task, FREE_TEXT => "I am card task_3", FREE_NUMBER => 3, MANAGED_TEXT => 'high', MANAGED_NUMBER => 3, DATE => '03 Jan 2001', USER => @project_admin_user.id)
    task_4 = create_card!(:name => 'task 4', :card_type => @type_task, FREE_TEXT => "I am card task_4", FREE_NUMBER => 1, MANAGED_TEXT => 'very high',    MANAGED_NUMBER => 4, DATE => '04 Jan 2001', USER => @mingle_admin_user.id)
    task_5 = create_card!(:name => 'task 5', :card_type => @type_task, FREE_TEXT => "I am card task_5", FREE_NUMBER => 2, MANAGED_TEXT => 'very high',    MANAGED_NUMBER => 5, DATE => '05 Jan 2001', USER => @non_admin_user.id)
    add_card_to_tree(planning_tree, release_1)
    add_card_to_tree(planning_tree, iteration_1, release_1)
    add_card_to_tree(planning_tree, [task_1, task_2, task_3, task_4, task_5], iteration_1)
    AggregateComputation.run_once
    open_card(@project, release_1)
    assert_property_set_on_card_show(count_aggregation.name, '2')
    assert_property_set_on_card_show(sum_aggregation.name, '5')
    assert_property_set_on_card_show(average_aggregation.name, '2.5')
    assert_property_set_on_card_show(minimum_aggregation.name, '1')
    assert_property_set_on_card_show(maximum_aggregation.name, '3')
    assert_property_set_on_card_show(aggregation_1, '4')
    assert_property_set_on_card_show(properties_comparision_aggregation.name, '3')
    assert_property_set_on_card_show(string_comparision_aggregation.name, '2')
  end
  
  def test_using_conditional_aggregate_for_all_decendants_or_specified_decendant
    planning_tree = setup_tree(@project, 'Planning Tree', :types => [@type_release, @type_iteration, @type_task, @type_story], :relationship_names => [RELEASE_ITERATION, ITERATION_TASK, TASK_STORY])
    story_level_aggregation = create_aggregate_property_for(@project, 'story_level_aggregation', planning_tree, @type_release, :aggregation_type => COUNT, 
    :scope => DEFINE_CONDITION, :condition => "TYPE = STORY AND '#{MANAGED_NUMBER}' < 4")
    all_levels_aggregation = create_aggregate_property_for(@project, 'all_levels_aggregation', planning_tree, @type_release, :aggregation_type => COUNT, 
    :scope => DEFINE_CONDITION, :condition => "'#{MANAGED_NUMBER}' = 2 ")
    release_1 = create_card!(:name => 'release 1', :card_type => @type_release)
    iteration_1 = create_card!(:name => 'iteration 1', :card_type => @type_iteration)
    task_1 = create_card!(:name => 'task 1', :card_type => @type_task, FREE_TEXT => "I am card task_1", FREE_NUMBER => 1, MANAGED_TEXT => 'low',  MANAGED_NUMBER => 1, DATE => '01 Jan 2001', USER => @mingle_admin_user.id)
    task_2 = create_card!(:name => 'task 2', :card_type => @type_task, FREE_TEXT => "I am card task_2", FREE_NUMBER => 1, MANAGED_TEXT => 'medium',  MANAGED_NUMBER => 2, DATE => '02 Jan 2001', USER => @non_admin_user.id)
    add_card_to_tree(planning_tree, release_1)
    add_card_to_tree(planning_tree, iteration_1, release_1)
    add_card_to_tree(planning_tree, [task_1, task_2], iteration_1)
    AggregateComputation.run_once
    open_card(@project, release_1)
    waitForAggregateValuesToBeComputed(@project, story_level_aggregation.name,release_1)
    assert_property_set_on_card_show(story_level_aggregation.name, '0')
    waitForAggregateValuesToBeComputed(@project, all_levels_aggregation,release_1)
    assert_property_set_on_card_show(all_levels_aggregation, '1')
    story1 = create_card!(:name => 'story1', :card_type => @type_story, FREE_TEXT => "I am card task_3", FREE_NUMBER => 3, MANAGED_TEXT => 'high', MANAGED_NUMBER => 2, DATE => '03 Jan 2001', USER => @project_admin_user.id)
    story2 = create_card!(:name => 'story2', :card_type => @type_story, FREE_TEXT => "I am card task_3", FREE_NUMBER => 3, MANAGED_TEXT => 'high', MANAGED_NUMBER => 2, DATE => '03 Jan 2001', USER => @project_admin_user.id)
    add_card_to_tree(planning_tree, [story1, story2], iteration_1)
    AggregateComputation.run_once
    open_card(@project, release_1)
    waitForAggregateValuesToBeComputed(@project, story_level_aggregation.name,release_1)
    assert_property_set_on_card_show(story_level_aggregation.name, '2')
     waitForAggregateValuesToBeComputed(@project, all_levels_aggregation,release_1)
    assert_property_set_on_card_show(all_levels_aggregation, '3')  
  end
  
  def test_using_conditional_aggregate_that_with_PLV_in_condition
    counter_plv = create_project_variable(@project, :name => 'counter_plv', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => 1502, :properties => [FREE_NUMBER])
    planning_tree = setup_tree(@project, 'Planning Tree', :types => [@type_release, @type_iteration, @type_task, @type_story], :relationship_names => [RELEASE_ITERATION, ITERATION_TASK, TASK_STORY])
    plv_aggregation = create_aggregate_property_for(@project, 'plv_aggregation', planning_tree, @type_release, :aggregation_type => COUNT, 
    :scope => DEFINE_CONDITION, :condition => "'#{FREE_NUMBER}' = (#{counter_plv.name})")
    release_1 = create_card!(:name => 'release 1', :card_type => @type_release)
    iteration_1 = create_card!(:name => 'iteration 1', :card_type => @type_iteration)
    task_1 = create_card!(:name => 'task 1', :card_type => @type_task, FREE_TEXT => "I am card task_1", FREE_NUMBER => 10, MANAGED_TEXT => 'low',  MANAGED_NUMBER => 1, DATE => '01 Jan 2001', USER => @mingle_admin_user.id)
    task_2 = create_card!(:name => 'task 2', :card_type => @type_task, FREE_TEXT => "I am card task_2", FREE_NUMBER => 10, MANAGED_TEXT => 'medium',  MANAGED_NUMBER => 2, DATE => '02 Jan 2001', USER => @non_admin_user.id)
    task_3 = create_card!(:name => 'task 3', :card_type => @type_task, FREE_TEXT => "I am card task_3", FREE_NUMBER => 1502, MANAGED_TEXT => 'high', MANAGED_NUMBER => 3, DATE => '03 Jan 2001', USER => @project_admin_user.id)
    add_card_to_tree(planning_tree, release_1)
    add_card_to_tree(planning_tree, iteration_1, release_1)
    add_card_to_tree(planning_tree, [task_1, task_2, task_3], iteration_1)
    AggregateComputation.run_once
    open_card(@project, release_1)
    waitForAggregateValuesToBeComputed(@project, plv_aggregation.name,release_1)
    assert_property_set_on_card_show(plv_aggregation.name, '1')
  end
  
  def test_using_conditional_aggregate_that_with_CARD_type_property_in_condition
    planning_tree = setup_tree(@project, 'Planning Tree', :types => [@type_release, @type_iteration, @type_task, @type_story], :relationship_names => [RELEASE_ITERATION, ITERATION_TASK, TASK_STORY])
    card_aggregation = create_aggregate_property_for(@project, 'card_aggregation', planning_tree, @type_release, :aggregation_type => COUNT, 
    :scope => DEFINE_CONDITION, :condition => "'#{RELATED_CARD}' NUMBER IN (1,2)")
    release_1 = create_card!(:name => 'release 1', :card_type => @type_release)
    iteration_1 = create_card!(:name => 'iteration 1', :card_type => @type_iteration)
    task_1 = create_card!(:name => 'task 1', :card_type => @type_task, FREE_TEXT => "I am card task_1", FREE_NUMBER => 10, MANAGED_TEXT => 'low',  MANAGED_NUMBER => 1, DATE => '01 Jan 2001', USER => @mingle_admin_user.id)
    task_2 = create_card!(:name => 'task 2', :card_type => @type_task, FREE_TEXT => "I am card task_2", FREE_NUMBER => 10, MANAGED_TEXT => 'medium',  MANAGED_NUMBER => 2, DATE => '02 Jan 2001', USER => @non_admin_user.id)
    task_3 = create_card!(:name => 'task 3', :card_type => @type_task, FREE_TEXT => "I am card task_3", FREE_NUMBER => 1502, MANAGED_TEXT => 'high', MANAGED_NUMBER => 3, DATE => '03 Jan 2001', USER => @project_admin_user.id)
    open_card(@project, task_1)
    set_relationship_properties_on_card_show(RELATED_CARD => release_1)
    open_card(@project, task_2)
    set_relationship_properties_on_card_show(RELATED_CARD => iteration_1)
    open_card(@project, task_3)
    set_relationship_properties_on_card_show(RELATED_CARD => task_1)
    add_card_to_tree(planning_tree, release_1)
    add_card_to_tree(planning_tree, iteration_1, release_1)
    add_card_to_tree(planning_tree, [task_1, task_2, task_3], iteration_1)
    AggregateComputation.run_once
    open_card(@project, release_1)
    waitForAggregateValuesToBeComputed(@project, card_aggregation.name,release_1)
    assert_property_set_on_card_show(card_aggregation.name, '2')
  end
  
  def test_using_conditional_aggregate_that_with_hidden_or_lock_or_transition_only_properties
    planning_tree = setup_tree(@project, 'Planning Tree', :types => [@type_release, @type_iteration, @type_task, @type_story], :relationship_names => [RELEASE_ITERATION, ITERATION_TASK, TASK_STORY])
    count_aggregation = create_aggregate_property_for(@project, 'count_aggregation', planning_tree, @type_release, :aggregation_type => COUNT, 
    :scope => DEFINE_CONDITION, :condition => "'#{MANAGED_NUMBER}' < 4 AND '#{FREE_NUMBER}' = 10")
    sum_aggregation = create_aggregate_property_for(@project, 'sum_aggregation',planning_tree, @type_release, :aggregation_type => SUM, 
    :scope => DEFINE_CONDITION, :condition => "'#{MANAGED_NUMBER}' <= 3 AND '#{FREE_TEXT}' != 'I am card task_1'", :property_to_aggregate => MANAGED_NUMBER)
    average_aggregation = create_aggregate_property_for(@project, 'average_aggregation', planning_tree, @type_release, :aggregation_type => AVERAGE, 
     :scope => DEFINE_CONDITION, :condition => "'#{FREE_NUMBER}' > 20 OR #{DATE} = '02 Jan 2001'", :property_to_aggregate => MANAGED_NUMBER)
    
    release_1 = create_card!(:name => 'release 1', :card_type => @type_release)
    iteration_1 = create_card!(:name => 'iteration 1', :card_type => @type_iteration)
    task_1 = create_card!(:name => 'task 1', :card_type => @type_task, FREE_TEXT => "I am card task_1", FREE_NUMBER => 10, MANAGED_TEXT => 'low',  MANAGED_NUMBER => 1, DATE => '01 Jan 2001', USER => @mingle_admin_user.id)
    task_2 = create_card!(:name => 'task 2', :card_type => @type_task, FREE_TEXT => "I am card task_2", FREE_NUMBER => 10, MANAGED_TEXT => 'medium',  MANAGED_NUMBER => 2, DATE => '02 Jan 2001', USER => @non_admin_user.id)
    task_3 = create_card!(:name => 'task 3', :card_type => @type_task, FREE_TEXT => "I am card task_3", FREE_NUMBER => 30, MANAGED_TEXT => 'high', MANAGED_NUMBER => 3, DATE => '03 Jan 2001', USER => @project_admin_user.id)
    task_4 = create_card!(:name => 'task 4', :card_type => @type_task, FREE_TEXT => "I am card task_4", FREE_NUMBER => 10, MANAGED_TEXT => 'very high',    MANAGED_NUMBER => 4, DATE => '04 Jan 2001', USER => @mingle_admin_user.id)
    task_5 = create_card!(:name => 'task 5', :card_type => @type_task, FREE_TEXT => "I am card task_5", FREE_NUMBER => 20, MANAGED_TEXT => 'very high',    MANAGED_NUMBER => 5, DATE => '05 Jan 2001', USER => @non_admin_user.id)
    
    add_card_to_tree(planning_tree, release_1)
    add_card_to_tree(planning_tree, iteration_1, release_1)
    add_card_to_tree(planning_tree, [task_1, task_2, task_3, task_4, task_5], iteration_1)
    
    make_property_transition_only_for(@project, FREE_NUMBER)
    lock_property(@project, MANAGED_NUMBER)
    hide_property(@project, FREE_TEXT)
    
    AggregateComputation.run_once
    open_card(@project, release_1)
    waitForAggregateValuesToBeComputed(@project, count_aggregation.name,release_1)
    assert_property_set_on_card_show(count_aggregation.name, '2')
    assert_property_set_on_card_show(sum_aggregation.name, '5')
    assert_property_set_on_card_show(average_aggregation.name, '2.5')
  end
  
  #Bug 7256
  def test_conditional_aggregate_recalculating_should_show_dirty_star_for_card_property   
    related_card_prop = create_property_definition_for(@project, 'my_related_card', :type => CARD_TYPE)
   
    planning_tree = setup_tree(@project, 'Planning Tree', :types => [@type_release, @type_iteration], :relationship_names => [RELEASE_ITERATION])
    story_1 = create_card!(:name => 'story 1', :card_type => @type_story)
    release_1 = create_card!(:name => 'release 1', :card_type => @type_release)
    iteration_1 = create_card!(:name => 'iteration 1', :card_type => @type_iteration)
        
    count_aggregation = create_aggregate_property_for(@project, 'count related card', planning_tree, @type_release, :aggregation_type => COUNT, :scope => DEFINE_CONDITION, :condition => "my_related_card NUMBER in (#{@project.cards.collect(&:number).join(',')})")
    add_card_to_tree(planning_tree, release_1)
    add_card_to_tree(planning_tree, iteration_1, release_1)
    open_card(@project, iteration_1)
    set_relationship_properties_on_card_show({'my_related_card' => story_1})
    AggregateComputation.run_once
    
    open_card(@project, iteration_1)
    set_relationship_properties_on_card_show({'my_related_card' => '(not set)'})
    open_card(@project, release_1)
    assert_stale_value('count related card', '1')
  end
end
