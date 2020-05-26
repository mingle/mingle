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

#Tags: tree-usage, card_show

class Scenario100AddRemoveCardsToTreeOnCardShowTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  PRIORITY = 'priority'
  STATUS = 'status'
  SIZE = 'size'
  ITERATION = 'iteration'
  OWNER = 'Zowner'

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
  HIGH = 'high'

  PLANNING = 'Planning'
  NONE = 'None'
  
  RELATION_PLANNING_RELEASE = 'Planning tree - release'
  RELATION_PLANNING_ITERATION = 'Planning tree - iteration'
  RELATION_PLANNING_STORY = 'Planning tree - story'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_admin_user = users(:longbob)
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_100', :users => [@non_admin_user], :admins => [@project_admin_user, users(:admin)])
    setup_property_definitions(PRIORITY => [HIGH, LOW], SIZE => [1, 2, 4], STATUS => [NEW,  'close', OPEN], ITERATION => [1,2,3,4], OWNER  => ['a', 'b', 'c'])
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
    navigate_to_card_list_for(@project)
    @aggregate_count_on_release = setup_aggregate_property_definition('count for release', AggregateType::COUNT, nil, @tree.id, @type_release.id, AggregateScope::ALL_DESCENDANTS)
    @aggregate_count_on_iteration = setup_aggregate_property_definition('count for iteration', AggregateType::COUNT, nil, @tree.id, @type_iteration.id, AggregateScope::ALL_DESCENDANTS)
  end
  
  def test_aggregate_property_set_to_notset_when_card_removed_from_tree_on_card_show_acceptace_criteria_40
    add_card_to_tree(@tree, @r1)
    add_card_to_tree(@tree, @i1, @r1)
    add_card_to_tree(@tree, [@stories[0], @stories[1]], @i1)
    AggregateComputation.run_once
    open_card(@project, @i1)
    waitForAggregateValuesToBeComputed(@project,@aggregate_count_on_iteration.name,@i1)
    assert_property_set_on_card_show(@aggregate_count_on_iteration.name, '2')
    click_remove_from_tree(@tree)
    click_remove_just_this_card
    assert_property_set_on_card_show(@aggregate_count_on_iteration.name, NOTSET)
    AggregateComputation.run_once
    open_card(@project, @r1)
    waitForAggregateValuesToBeComputed(@project,@aggregate_count_on_release.name,@r1)
    assert_property_set_on_card_show(@aggregate_count_on_release.name, '2')
  end
  
  #12585
  def test_aggregate_property_gets_recalculated_when_update_relationship_on_card_show
    add_card_to_tree(@tree, @r1)
    add_card_to_tree(@tree, @r2)
    add_card_to_tree(@tree, @i1, @r1)
    add_card_to_tree(@tree, @i2, @r2)
    add_card_to_tree(@tree, [@stories[0], @stories[1]], @i1)
    add_card_to_tree(@tree, [@stories[0], @stories[1]], @i1)
    AggregateComputation.run_once
    open_card(@project, @r1)
    waitForAggregateValuesToBeComputed(@project,@aggregate_count_on_release.name,@r1)
    assert_property_set_on_card_show(@aggregate_count_on_release.name, '3')
    open_card(@project, @r2)
    waitForAggregateValuesToBeComputed(@project,@aggregate_count_on_release.name,@r2)
    assert_property_set_on_card_show(@aggregate_count_on_release.name, '1')
    open_card(@project, @stories[0])
    set_relationship_properties_on_card_show(RELATION_PLANNING_RELEASE => @r2)
    AggregateComputation.run_once
    open_card(@project, @r1)
    waitForAggregateValuesToBeComputed(@project,@aggregate_count_on_release.name,@r1)
    assert_property_set_on_card_show(@aggregate_count_on_release.name, '2')
    open_card(@project, @r2)
    waitForAggregateValuesToBeComputed(@project,@aggregate_count_on_release.name,@r2)
    assert_property_set_on_card_show(@aggregate_count_on_release.name, '2')
  end
  
  def test_aggregate_property_set_to_notset_when_card_and_its_children_removed_from_tree_on_card_show_acceptace_criteria_41
    add_card_to_tree(@tree, @r1)
    add_card_to_tree(@tree, @i1, @r1)
    add_card_to_tree(@tree, [@stories[0], @stories[1]], @i1)
    AggregateComputation.run_once
    open_card(@project, @i1)
    waitForAggregateValuesToBeComputed(@project, @aggregate_count_on_iteration.name,@i1)
    assert_property_set_on_card_show(@aggregate_count_on_iteration.name, '2')
    click_remove_from_tree(@tree)
    click_remove_this_card_and_its_children
    assert_property_set_on_card_show(@aggregate_count_on_iteration.name, NOTSET)
    AggregateComputation.run_once
    open_card(@project, @r1)
    waitForAggregateValuesToBeComputed(@project, @aggregate_count_on_release.name,@r1)
    assert_property_set_on_card_show(@aggregate_count_on_release.name, '0')
  end
  
  def test_card_in_tree_can_be_deleted_from_project
    add_card_to_tree(@tree, @r1)
    add_card_to_tree(@tree, @i1, @r1)
    open_card(@project, @i1)
    delete_card_from_card_show
    assert_notice_message("Card ##{@i1.number} deleted successfully.")
  end
  
  def test_card_remove_from_root_node_does_not_create_any_history
    add_card_to_tree(@tree, @r1)
    open_card(@project, @r1)
    assert_version_info_on_card_show("\\(v1 - Latest version")
    click_remove_from_tree_and_wait_for_card_to_be_removed(@tree)
    assert_history_for(:card, @r1.number).version(2).not_present
    assert_version_info_on_card_show("\\(v1 - Latest version")
  end
  
  def test_message_this_card_belongs_to_this_tree_updates_to_this_card_available_to_this_tree_on_card_show
    add_card_to_tree(@tree, @r1)
    open_card(@project, @r1)
    assert_card_belongs_to_tree_on_card_show_for(@tree)
    click_remove_from_tree_and_wait_for_card_to_be_removed(@tree)
    assert_card_is_available_to_tree_on_card_show_for(@tree)
  end
    
  #bug 4617
  def test_should_be_able_to_remove_cards_from_tree
    tree2 = setup_tree(@project, 'non planning tree', :types => [@type_release, @type_iteration, @type_story], :relationship_names => ['RELEASE_PROPERTY', 'ITERATION_PROPERTY'])
    add_card_to_tree(@tree, @r1)
    add_card_to_tree(@tree, @i1, @r1)
    add_card_to_tree(@tree, @stories[0], @i1)
    add_card_to_tree(tree2, @r1)
    add_card_to_tree(tree2, @i1, @r1)
    add_card_to_tree(tree2, @stories[0], @i1)
    
    navigate_to_tree_view_for(@project, tree2.name)
    remove_card_without_its_children_from_tree_for(@project, tree2.name, @i1)
    select_tree(@tree.name)
    remove_card_without_its_children_from_tree_for(@project, @tree.name, @i1)

    location = @browser.get_location
    @browser.open(location)
    assert_card_not_present_on_tree(@project, @i1)
  end
  
  #bug 4278
  def test_history_tab_gets_latest_version_when_created_by_removing_card_from_tree_on_card_show
    add_card_to_tree(@tree, @r1)
    add_card_to_tree(@tree, @i1, @r1)
    open_card(@project, @i1)
    assert_version_info_on_card_show("(v2 - Latest version, last modified today at)")
    click_remove_from_tree_and_wait_for_card_to_be_removed(@tree)
    assert_history_for(:card, @i1.number).version(3).present
  end

end
