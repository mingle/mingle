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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')
class TreeConfigurationDeleteTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  
  def setup
    @project = create_project
    login_as_admin
    @configuration = @project.tree_configurations.create!(:name => 'Planning')
    @type_release, @type_iteration, @type_story = init_planning_tree_types
    init_three_level_tree(@configuration)
  end
  
  def test_should_destroy_relationship_properties_and_aggregate_properties
    @project.all_property_definitions.create_aggregate_property_definition({
        :name => 'aggregate prop def', 
        :aggregate_scope => AggregateScope::ALL_DESCENDANTS, 
        :aggregate_type => AggregateType::COUNT, 
        :aggregate_card_type_id => @type_release.id, :tree_configuration_id => @configuration.id})
    @project.reload.update_card_schema
    @configuration.reload
    @configuration.destroy
    assert @project.property_definitions.select{|pd| pd.tree_configuration_id == @configuration.id}.empty?
  end
  
  def test_should_destroy_tree_belongs
    @configuration.destroy
    assert TreeBelonging.find_all_by_tree_configuration_id(@configuration.id).empty?
  end
  
  def test_should_delete_related_transitions
    release1 = @project.cards.find_by_name('release1')
    delay = create_transition @project, 'delay', :required_properties => {'Planning release' => release1.id}, :set_properties => {'Planning release' => nil}
    @project.reload
    assert_include delay.name, @configuration.related_transitions
    @configuration.destroy
    assert_nil @project.transitions.find_by_name(delay.name)
  end
  
  def test_should_delete_all_card_list_view_with_tree_name
    view = CardListView.find_or_construct(@project, :name => 'tree view', :style => 'hierarchy', :tree_name => @configuration.name)
    view.save!
    @configuration.destroy
    assert_nil @project.card_list_views.find_by_name('tree view')
  end
  
  def test_should_delete_all_card_list_view_using_tree_properties
    view = CardListView.find_or_construct(@project, :name => 'tree view', :filters => ["[#{@configuration.relationships.first.name}][is][iteration1]"])
    view.save!
    @project.reload
    @configuration.destroy
    assert_nil @project.card_list_views.find_by_name('tree view')
  end
  
  #bug3273 cannot delete tree from mingle07, casued by miss use method filtered_by? on Filters
  def test_should_delete_all_card_list_view_using_tree_aggregate_properties
    release_type = @project.card_types.find_by_name('release')
    @project.create_aggregate_property_definition!({:name => 'card count', 
        :aggregate_scope => AggregateScope::ALL_DESCENDANTS, 
        :aggregate_type => AggregateType::COUNT, 
        :aggregate_card_type_id => release_type.id, 
        :tree_configuration_id => @configuration.id })
    @project.reload.update_card_schema
    view = CardListView.find_or_construct(@project, :name => 'tree view', :filters => ["[card count][>][2]"])
    view.save!
    @project.reload
    @configuration.reload
    @configuration.destroy
    assert_nil @project.card_list_views.find_by_name('tree view') 
  end
  
  def test_should_delete_transition_when_tree_is_deleted_and_transition_action_removes_card_from_tree
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      release_type = project.card_types.find_by_name('release')
      create_transition(project, 'hi there', :card_type => release_type, :remove_from_trees => [configuration])
      assert !project.transitions.find_by_name('hi there').nil?
      configuration.destroy
      assert project.transitions.find_by_name('hi there').nil?
    end
  end
  
  def test_should_include_removes_card_from_tree_transitions_as_related_transitions
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      release_type = project.card_types.find_by_name('release')
      transition = create_transition(project, 'hi there', :card_type => release_type, :remove_from_trees => [configuration])
      project.transitions.reload
      assert_equal ['hi there'], configuration.related_transitions
    end
  end
  
  def test_should_delete_the_favorite_when_delete_the_tree_which_is_been_used_it_as_from_tree_in_the_mql_filter
    view = CardListView.find_or_construct(@project, {:style => 'list', :filters => {:mql => %{ FROM TREE 'planning'} }} )
    view.name="from tree view"
    view.save!
    @project.reload
    @configuration.reload
    @configuration.destroy
    assert_nil @project.card_list_views.find_by_name("from tree view")
  end
end
