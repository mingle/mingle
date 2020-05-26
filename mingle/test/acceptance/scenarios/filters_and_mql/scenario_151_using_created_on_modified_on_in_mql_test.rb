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

#Tags: mql, properties

class Scenario151UsingCreatedOnModifiedOnInMqlTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  RELEASE = "Release"
  ITERATION = "Iteration"
  STORY = "Story"
  PLANNING_TREE= "Planning tree"

  COUNT = 'Count'
  DEFINE_CONDITION = AggregateScope::DEFINE_CONDITION

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin_user = users(:proj_admin)

    @project = create_project(:prefix => 'scenario_151', :admins => [@project_admin_user])
    login_as_proj_admin_user
  end

  def test_using_created_on_and_modified_on_in_mql_filter
    fake_now(2007, 2, 2)
    card = create_card!(:name => 'cardomatic')
    navigate_to_card_list_for(@project)
    set_mql_filter_for("'created on' = today")
    assert_card_present_in_list(card)
    set_mql_filter_for("'created on' = '10 Sep 2001'")
    assert_info_message("There are no cards that match the current filter - Reset filter")
    set_mql_filter_for("'modified on' = today")
    assert_card_present_in_list(card)
    set_mql_filter_for("'modified on' = '10 Sep 2001'")
    assert_info_message("There are no cards that match the current filter - Reset filter")
  ensure
    @browser.reset_fake
  end

  def test_using_created_on_in_conditional_aggregate
    fake_now(2013, 2, 12, 0)
    get_a_R_I_S_tree_ready(@project)
    aggregate_1 = create_aggregate_property_for(@project, 'created on 10 sep 2001', @tree, @release_type, :aggregation_type => COUNT,
    :scope => DEFINE_CONDITION, :condition => "'created on' = '10 Sep 2001'")
    aggregate_2 = create_aggregate_property_for(@project, 'created on today', @tree, @release_type, :aggregation_type => COUNT,
    :scope => DEFINE_CONDITION, :condition => "'created on' = '12 Feb 2013'")
    AggregateComputation.run_once
    open_card(@project, @release_card)
    waitForAggregateValuesToBeComputed(@project,aggregate_1.name,@release_card)
    assert_property_set_on_card_show(aggregate_1.name, "0")
    waitForAggregateValuesToBeComputed(@project,aggregate_2.name,@release_card)
    assert_property_set_on_card_show(aggregate_2.name, "2")
  ensure
    @browser.reset_fake
  end

  private
  def get_a_R_I_S_tree_ready(project)
    @release_type = setup_card_type(project, RELEASE)
    @iteration_type = setup_card_type(project, ITERATION)
    @story_type = setup_card_type(project, STORY)
    project.reload.activate
    @tree = setup_tree(project, PLANNING_TREE, :types => [@release_type, @iteration_type, @story_type], :relationship_names => ["Release", "Iteration"])
    @iteration_card = create_card!(:card_type => @iteration_type, :name => 'iteration' )
    @release_card = create_card!(:card_type => @release_type, :name => 'release' )
    @story_card = create_card!(:card_type => @story_type, :name => 'story')
    add_card_to_tree(@tree, @release_card)
    add_card_to_tree(@tree, @iteration_card, @release_card)
    add_card_to_tree(@tree, @story_card, @iteration_card)
  end

end
