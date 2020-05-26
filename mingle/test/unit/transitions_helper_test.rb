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

class TransitionsHelperTest < ActiveSupport::TestCase
  include TransitionsHelper, TreeFixtures::PlanningTree
  
  def setup
    @project = three_level_tree_project
    @project.activate
  end
  
  def test_all_prop_defs_include_hidden_ones
      @project = first_project
      not_hidden = @project.find_property_definition('Release')
      hidden = @project.find_property_definition('Priority')
      hidden.hidden = true
      hidden.save!
    
      assert all_prop_defs.include?("enumeratedpropertydefinition_#{hidden.id}_sets_span")
      assert all_prop_defs.include?("enumeratedpropertydefinition_#{hidden.id}_requires_span")
      assert all_prop_defs.include?("enumeratedpropertydefinition_#{not_hidden.id}_sets_span")
      assert all_prop_defs.include?("enumeratedpropertydefinition_#{not_hidden.id}_requires_span")
  end
  
  def test_transition_properties_should_include_tree_property_definitions
    assert transition_properties.collect(&:name).include?('three level tree')
  end
  
  def test_all_prop_defs_returns_only_set_ids_for_tree_belonging_properties
    tree = @project.tree_configurations.first
    assert all_prop_defs.include?("tree_belonging_property_definition_#{tree.id}_sets_span")
    assert !all_prop_defs.include?("tree_belonging_property_definition_#{tree.id}_requires_span")
  end
  
  def test_card_type_map_should_never_include_tree_in_requires_map
    tree = @project.tree_configurations.first
    tree_requires_property_definition = "tree_belonging_property_definition_#{tree.id}_requires_span"
    
    map = card_type_map
    assert !map['cp'].include?(tree_requires_property_definition)
    assert !map['cpCard'].include?(tree_requires_property_definition)
    assert !map['cprelease'].include?(tree_requires_property_definition)
    assert !map['cpiteration'].include?(tree_requires_property_definition)
    assert !map['cpstory'].include?(tree_requires_property_definition)
  end
  
  def test_card_type_map_should_only_map_trees_to_types_in_tree_with_set
    tree = @project.tree_configurations.first
    tree_set_property_definition = "tree_belonging_property_definition_#{tree.id}_sets_span"
    
    map = card_type_map
    assert !map['cp'].include?(tree_set_property_definition)
    assert !map['cpCard'].include?(tree_set_property_definition)
    assert map['cprelease'].include?(tree_set_property_definition)
    assert map['cpiteration'].include?(tree_set_property_definition)
    assert map['cpstory'].include?(tree_set_property_definition)
  end
  
  def test_order_of_map_properties_groups_trees_at_bottom
    with_new_project do |project|
      @project = project
      release_type, iteration_type, story_type = init_planning_tree_types
      a_tree, b_tree = ['a', 'b'].collect { |tree_name| create_ris_tree(tree_name) }
      status = setup_numeric_property_definition('status', [1, 2, 3])
      story_type.add_property_definition(status)
      story_type.save
      
      story_card_type_property_ids = card_type_map["cpstory"].select { |id| id =~ /_sets_span/ }
      
      a_tree_belonging_sets_id = tree_belonging_property_sets_id(a_tree)
      a_tree_release_sets_id = relationship_property_sets_id("a release")
      a_tree_iteration_sets_id = relationship_property_sets_id("a iteration")
      
      b_tree_belonging_sets_id = tree_belonging_property_sets_id(b_tree)
      b_tree_release_sets_id = relationship_property_sets_id("b release")
      b_tree_iteration_sets_id = relationship_property_sets_id("b iteration")
      
      status_sets_id = "enumeratedpropertydefinition_#{status.id}_sets_span"
      
      expected_properties = [status_sets_id, a_tree_belonging_sets_id, a_tree_release_sets_id, a_tree_iteration_sets_id, b_tree_belonging_sets_id, b_tree_release_sets_id, b_tree_iteration_sets_id]
      assert_equal expected_properties, story_card_type_property_ids
    end
  end
  
  def test_disabled_message_map_returns_the_correct_stuff_where_correct_in_this_case_is_determined_by_the_test_content
    with_three_level_tree_project do |project|
      @project = project
      tree_configuration = project.tree_configurations.first
      
      planning_release = project.find_property_definition('Planning release')
      planning_iteration = project.find_property_definition('Planning iteration')
      
      expected_map = {}
      expected_map["treerelationshippropertydefinition_#{planning_release.id}_sets"] = {:childMessage => "(no change)", :parentMessage => "(determined by tree)"}
      expected_map["treerelationshippropertydefinition_#{planning_iteration.id}_sets"] = {:childMessage => "(no change)", :parentMessage => "(determined by tree)"}
      expected_map["tree_belonging_property_definition_#{tree_configuration.id}_sets"] = {:childMessage => "(not set)", :parentMessage => "(determined by relationships)"}
      
      assert_equal expected_map, disabled_message_map
    end
  end
  
  def test_last_card_type_in_tree_map
    with_new_project do |project|
      @project = project
      release_type, iteration_type, story_type = init_planning_tree_types
      ris1_tree, ris2_tree = ['ris1', 'ris2'].collect { |tree_name| create_ris_tree(tree_name) }
      sir_tree = create_sir_tree('sir')
      
      assert_equal ["tree_belonging_property_definition_#{sir_tree.id}_sets"], last_card_type_in_tree_map['release']
      assert_equal [], last_card_type_in_tree_map['iteration']
      assert_equal ["tree_belonging_property_definition_#{ris1_tree.id}_sets", "tree_belonging_property_definition_#{ris2_tree.id}_sets"].sort, last_card_type_in_tree_map['story'].sort
      assert_equal [], last_card_type_in_tree_map['Card']
    end
  end
  
  def test_card_type_properties_mapping_should_include_all
    mapping = card_type_properties_mapping
    card_type = @project.card_types.first
    expected_properties = card_type.property_definitions.collect{|p| [p.name, p.id]}.unshift(["All properties", ''])
    assert_equal expected_properties, mapping[card_type.id]
  end  
  
  def test_card_type_properties_mapping_should_not_include_aggregate_property_definitions
    card_type = @project.card_types.find_by_name("iteration")
    sum = card_type.property_definitions.select{|prop| prop.name == "Sum of size"}.first
    
    mapping = card_type_properties_mapping
    assert_not_include [sum.name, sum.name], mapping[card_type.id]
    assert_not_include nil, mapping[card_type.id]
  end
  
  def test_card_type_properties_mapping_should_not_include_formula_property_definitions
    with_project_without_cards do |project|
      @project = project
      formaula_property = project.find_property_definition 'day after start date'
      card_type = project.card_types.first
    
      mapping = card_type_properties_mapping
      assert_not_include [formaula_property.name, formaula_property.name], mapping[card_type.id]
      assert_not_include nil, mapping[card_type.id]
    end
  end
  
  # Bug 7237
  def test_card_type_properties_mapping_should_include_hidden_properties
    login_as_admin
    hidden = @project.create_text_definition(:name => 'lucky_text', :hidden => true)
    type_story = @project.card_types.find_by_name("story")
    type_story.add_property_definition(hidden)
    
    story_mapping = card_type_properties_mapping[type_story.id]
    hidden_expected_mapping_element = [hidden.name, hidden.id]
    assert story_mapping.any? { |mapping_element| mapping_element == hidden_expected_mapping_element }, 
           "Missing hidden mappings. #{hidden_expected_mapping_element.inspect} was not found in #{story_mapping.inspect}"
  end
  
  private
  def create_ris_tree(name)
    release_type, iteration_type, story_type = find_planning_tree_types
    configuration = Project.current.tree_configurations.create!(:name => name)
    configuration.update_card_types({
      release_type => {:position => 0, :relationship_name => "#{name} release"}, 
      iteration_type => {:position => 1, :relationship_name => "#{name} iteration"}, 
      story_type => {:position => 2}
    })
    configuration
  end
  
  def create_sir_tree(name)
    release_type, iteration_type, story_type = find_planning_tree_types
    configuration = Project.current.tree_configurations.create!(:name => name)
    configuration.update_card_types({
      story_type => {:position => 0, :relationship_name => "#{name} story"},
      iteration_type => {:position => 1, :relationship_name => "#{name} iteration"}, 
      release_type => {:position => 2}
    })
    configuration
  end
  
  def relationship_property_sets_id(property_name)
    property = @project.find_property_definition(property_name)
    "treerelationshippropertydefinition_#{property.id}_sets_span"
  end
  
  def tree_belonging_property_sets_id(tree)
    "tree_belonging_property_definition_#{tree.id}_sets_span"
  end
end
