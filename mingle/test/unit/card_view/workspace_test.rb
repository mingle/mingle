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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class WorkspaceTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  def setup
    @project = create_project
    login_as_member
    setup_property_definitions :status => ['new', 'close'], :size => [1, 2, 3], :language => ['english', 'chinese']
    @status_pd = @project.property_definitions.detect{|pd|pd.name == 'status'}
    @size_pd = @project.property_definitions.detect{|pd|pd.name == 'size'}
    @language_pd = @project.property_definitions.detect{|pd|pd.name == 'language'}
  end
  
  def test_column_properties_should_be_super_set_of_all_card_types_properties
    type_release, type_iteration, type_story = init_planning_tree_types
    type_release.add_property_definition(@status_pd)
    type_story.add_property_definition(@status_pd)
    type_story.add_property_definition(@size_pd)
    tree = create_planning_tree_with_multi_types_in_levels
    workspace = CardListView.find_or_construct(@project, {:tree_name => tree.name, :style => 'hierarchy'}).workspace
    assert_equal ["Type", "Planning iteration", "Planning release", "size", "status", "Created by", "Modified by"], workspace.column_properties.collect(&:name)
  end
  
  def test_column_properties_should_be_not_include_hidden_properties
    type_release, type_iteration, type_story = init_planning_tree_types
    type_release.add_property_definition(@status_pd)
    type_story.add_property_definition(@status_pd)
    type_story.add_property_definition(@size_pd)
    @size_pd.update_attribute(:hidden, true)
    @project.reload
    tree = create_planning_tree_with_multi_types_in_levels
    workspace = CardListView.find_or_construct(@project, {:tree_name => tree.name, :style => 'hierarchy'}).workspace
    assert_equal ["Type", "Planning iteration", "Planning release", "status", "Created by", "Modified by"], workspace.column_properties.collect(&:name)
  end
  
  def test_column_properties_should_be_decide_by_filtered_card_type_when_tree_not_selected
    type_release, type_iteration, type_story = init_planning_tree_types
    type_release.add_property_definition(@status_pd)
    type_release.save!
    
    type_story.add_property_definition(@status_pd)
    type_story.add_property_definition(@size_pd)
    type_story.save!
    
    type_iteration.add_property_definition(@language_pd)
    type_iteration.save!
    
    workspace = CardListView.find_or_construct(@project, {:filters => ['[type][is][story]', '[type][is][release]'], :style => 'list'}).workspace
    assert_equal ["Type", "size", "status", "Created by", "Modified by"], workspace.column_properties.collect(&:name)
  end
  
  def test_type_color_values_should_scoped_in_the_tree
    init_planning_tree_types
    tree = create_planning_tree_with_multi_types_in_levels
    @project.card_types.create!(:name => 'epic')
    workspace = CardListView.find_or_construct(@project, {:style => 'grid', :color_by => 'Type'}).workspace
    assert_equal ['Card', "release", "iteration", "story", "epic"].sort, workspace.color_values.collect(&:name).sort
    workspace = CardListView.find_or_construct(@project, {:style => 'grid', :color_by => 'Type', :tree_name => tree.name}).workspace    
    assert_equal ["release", "iteration", "story"].sort, workspace.color_values.collect(&:name).sort
  end
  
  def test_should_get_mql_filter_when_params_has_mql_filter_key
    workspace = CardListView.find_or_construct(@project, {}).workspace
    assert_equal MqlFilters, workspace.parse_filter_params({:style => 'list', :filters => {:mql => "type=story"}}).class
    assert_equal MqlFilters, workspace.parse_filter_params({:style => 'list', :filters => {:mql => nil}}).class
  end
  
  
  def test_column_properties_should_include_aggregate_properties
    configuration = @project.tree_configurations.create!(:name => 'Planning')
    type_release, type_iteration, type_story = init_planning_tree_types
    init_three_level_tree(configuration)
    
    iteration_count = setup_aggregate_property_definition('child count',
                                                          AggregateType::COUNT,
                                                          nil,
                                                          configuration.id,
                                                          type_release.id,
                                                          AggregateScope::ALL_DESCENDANTS)
    
    view = CardListView.find_or_construct(@project, {:tree_name => configuration.name, :style => 'hierarchy'})
    assert_equal ['Type', 'child count', 'Planning iteration', 'Planning release','Created by', 'Modified by'], view.workspace.column_properties.collect(&:name)
  end
  
end
