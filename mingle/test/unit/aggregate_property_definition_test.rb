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

class AggregatePropertyDefinitionTest < ActiveSupport::TestCase  
  include TreeFixtures::PlanningTree

  def setup
    login_as_member
    @project = create_project
    @project.activate
    @tree_configuration = @project.tree_configurations.create!(:name => 'Release tree')
    
    @type_release, @type_iteration, @type_story = init_planning_tree_types
  end
  
  def test_aggregate_property_definition_should_be_numeric
    init_three_level_tree(@tree_configuration)
    aggregate_prop_def = @project.all_property_definitions.create_aggregate_property_definition(:name => 'I am aggregate prop def')
    assert aggregate_prop_def.numeric?
  end
  
  def test_aggregate_property_definitions_should_be_calculated
    init_three_level_tree(@tree_configuration)
    aggregate_prop_def = @project.all_property_definitions.create_aggregate_property_definition(:name => 'I am aggregate prop def')
    assert aggregate_prop_def.calculated?
  end
  
  def test_property_values_description_should_be_aggregate
    init_three_level_tree(@tree_configuration)
    aggregate_prop_def = @project.all_property_definitions.create_aggregate_property_definition(:name => 'I am aggregate prop def')
    assert_equal "Aggregate", aggregate_prop_def.property_values_description
  end
  
  def test_aggregate_scope_should_not_be_empty_and_must_from_standard_scopes
    init_three_level_tree(@tree_configuration)
    
    card_type_not_in_tree = @project.card_types.find_by_name('Card')
    aggregate_prop_def = create_aggregate_property_definition(default_options.merge(:aggregate_scope => card_type_not_in_tree))
    assert_equal ["Aggregate properties must have a valid scope"], aggregate_prop_def.errors.full_messages
    
    top_card_type = @type_release
    aggregate_prop_def = create_aggregate_property_definition(default_options.merge(:aggregate_scope => @type_release))
    assert_equal ["Aggregate properties must have a valid scope"], aggregate_prop_def.errors.full_messages
    
    aggregate_prop_def = create_aggregate_property_definition(default_options.merge(:aggregate_scope => AggregateScope::ALL_DESCENDANTS))
    assert aggregate_prop_def.valid?
  end
  
  def test_aggregate_type_should_not_be_empty_and_must_be_from_standard_types
    init_three_level_tree(@tree_configuration)
    numeric_property_definition = setup_numeric_text_property_definition('numeric text')
    
    aggregate_prop_def = create_aggregate_property_definition(default_options.merge(:aggregate_type => '', :aggregate_target_id => numeric_property_definition.id))
    assert_equal ["Aggregate type must be selected"], aggregate_prop_def.errors.full_messages
    
    aggregate_prop_def = create_aggregate_property_definition(default_options.merge(:aggregate_type => nil, :aggregate_target_id => numeric_property_definition.id))
    assert_equal ["Aggregate type must be selected"], aggregate_prop_def.errors.full_messages
    
    aggregate_prop_def = create_aggregate_property_definition(default_options.merge(:aggregate_type => 'XYZ', :aggregate_target_id => numeric_property_definition.id))
    assert_equal ["Aggregate type must be selected"], aggregate_prop_def.errors.full_messages
    
    assert !aggregate_prop_def.valid?
    aggregate_prop_def = create_aggregate_property_definition(default_options)
    assert aggregate_prop_def.valid?
  end
  
  def test_target_property_cannot_be_an_aggregate_property
    init_three_level_tree(@tree_configuration)
    aggregate_prop_def_1 = create_aggregate_property_definition(default_options)
    aggregate_prop_def_2 = create_aggregate_property_definition(default_options.merge(:name => "new name", :aggregate_target_id => aggregate_prop_def_1.id))
    assert_equal ["Aggregate properties cannot have another aggregate property (#{aggregate_prop_def_1.name.bold}) as a target"], aggregate_prop_def_2.errors.full_messages
  end

  def test_aggregate_property_definition_must_have_a_card_type_that_can_have_children_as_per_tree_configuration
    init_three_level_tree(@tree_configuration)
    aggregate_prop_def = create_aggregate_property_definition(default_options.merge(:aggregate_card_type_id => @type_story.id))
    assert_equal ["Aggregate properties cannot be defined since #{@type_story.name.bold} does not have any children"], aggregate_prop_def.errors.full_messages
  end
  
  def test_should_check_aggregate_card_type_is_configured_by_tree
    init_three_level_tree(@tree_configuration)
    @type_bug = @project.card_types.create(:name => 'bug')
    aggregate_prop_def = create_aggregate_property_definition(default_options.merge(:aggregate_card_type_id => @type_bug.id))
    assert_equal ["Aggregate properties cannot be defined since #{@type_bug.name.bold} is not on the tree"], aggregate_prop_def.errors.full_messages
  end

  def test_target_property_definition_must_be_numeric_or_nil
    setup_date_property_definition('somedate')
    
    init_three_level_tree(@tree_configuration)
    text_property_definition = setup_text_property_definition('text')
    aggregate_prop_def = create_aggregate_property_definition(default_options.merge(:aggregate_target_id => text_property_definition.id))
    assert_equal ["Aggregate property definition must be numeric"], aggregate_prop_def.errors.full_messages
    
    formula_property_definition = setup_formula_property_definition('formula', '1 + 2')
    
    aggregate_prop_def = create_aggregate_property_definition(default_options.merge(:name => 'new name 2', :aggregate_target_id => formula_property_definition.id))
    puts aggregate_prop_def.errors.full_messages
    assert_equal [], aggregate_prop_def.errors.full_messages
    
    formula_property_definition = setup_formula_property_definition('formula2', 'somedate + 2')
    aggregate_prop_def = create_aggregate_property_definition(default_options.merge(:aggregate_target_id => formula_property_definition.id))
    assert_equal ["Aggregate property definition must be numeric"], aggregate_prop_def.errors.full_messages
    
    numeric_property_definition = setup_numeric_text_property_definition('numeric text')
    aggregate_prop_def = create_aggregate_property_definition(default_options.merge(:aggregate_target_id => numeric_property_definition.id))
    assert aggregate_prop_def.valid?
    
    hidden_numeric = setup_numeric_text_property_definition('hidden numeric')
    hidden_numeric.hidden = true
    hidden_numeric.save!
    aggregate_prop_def = create_aggregate_property_definition(default_options.merge(:name => 'new name', :aggregate_type => AggregateType::SUM, :aggregate_target_id => hidden_numeric.id))
    assert aggregate_prop_def.valid?
  end
  
  def test_aggregate_property_definition_should_not_be_empty_when_the_type_is_not_count
    init_three_level_tree(@tree_configuration)
    aggregate_prop_def = create_aggregate_property_definition(default_options.merge(:aggregate_type => AggregateType::SUM, :aggregate_target_id => nil))
    assert !aggregate_prop_def.valid?
    
    aggregate_prop_def = create_aggregate_property_definition(default_options.merge(:aggregate_type => AggregateType::COUNT, :aggregate_target_id => nil))
    assert aggregate_prop_def.valid?
  end
  
  def test_aggregate_card_type_id_should_not_be_empty
    init_three_level_tree(@tree_configuration)
    aggregate_prop_def = create_aggregate_property_definition(default_options.merge(:aggregate_card_type_id => nil))
    assert !aggregate_prop_def.valid?    
    
    aggregate_prop_def = create_aggregate_property_definition(default_options.merge(:aggregate_card_type_id => @type_release.id))
    assert aggregate_prop_def.valid?
  end
  
  def test_tree_id_should_not_be_empty
    init_three_level_tree(@tree_configuration)
    aggregate_prop_def = create_aggregate_property_definition(default_options.merge(:tree_configuration_id => nil))
    assert !aggregate_prop_def.valid?    
    
    aggregate_prop_def = create_aggregate_property_definition(default_options.merge(:tree_configuration_id => @tree_configuration.id))
    assert aggregate_prop_def.valid?
  end
  
  def test_duplicate_names_should_not_be_allowed
    init_three_level_tree(@tree_configuration)
    aggregate_prop_def = create_aggregate_property_definition(default_options)
    assert aggregate_prop_def.valid?
    duplicated_name_prop_def = create_aggregate_property_definition(default_options)
    assert !duplicated_name_prop_def.valid?
    assert_equal ["Name has already been taken"], duplicated_name_prop_def.errors.full_messages
  end
  
  def test_should_only_show_one_current_user_related_error_if_aggregate_condition_makes_invalid_reference_to_current_user
    init_three_level_tree(@tree_configuration)
    cp_aggregate = create_aggregate_property_definition(default_options.merge(:aggregate_condition => "type = CURRENT USER"))
    assert_equal ["#{'CURRENT USER'.bold} is not supported in aggregate condition"], cp_aggregate.errors.full_messages    
  end
  
  def test_creation_of_property_results_in_addition_to_card_type
    init_three_level_tree(@tree_configuration)
    aggregate_prop_def = create_aggregate_property_definition(default_options)
    assert @type_release.reload.property_definitions.include?(aggregate_prop_def)
  end

  def test_update_or_destroy_by_should_update_cards_if_aggregate_scope_is_all_descendants_scope
    init_three_level_tree(@tree_configuration)
    aggregate_prop_def = create_aggregate_property_definition(default_options.merge(:aggregate_scope => AggregateScope::ALL_DESCENDANTS))
    publisher = MessagePublisherStub.new
    aggregate_prop_def.instance_variable_set(:@publisher, publisher)
    aggregate_prop_def.update_or_destroy_by(nil)
    publisher.assert_publish_card_messages_called
  end
  
  def test_update_or_destroy_should_destroy_aggregate_if_scope_is_the_card_type
    init_three_level_tree(@tree_configuration)
    iteration_type = @project.card_types.find_by_name('iteration')
    aggregate_prop_def = create_aggregate_property_definition(default_options.merge(:aggregate_scope => iteration_type, :name => 'for_test'))
    aggregate_prop_def.update_or_destroy_by(iteration_type)
    assert_nil @project.find_property_definition_or_nil('for_test')
  end

  def test_update_or_destroy_should_not_destroy_aggregate_if_scope_is_another_card_type
    init_three_level_tree(@tree_configuration)
    iteration_type = @project.card_types.find_by_name('iteration')
    story_type = @project.card_types.find_by_name('story')
    aggregate_prop_def = create_aggregate_property_definition(default_options.merge(:aggregate_scope => iteration_type, :name => 'for_test'))
    aggregate_prop_def.update_or_destroy_by(story_type)
    assert_not_nil @project.reload.find_property_definition_or_nil('for_test')
  end
  
  def test_can_compute_aggregate_using_mql_condition
    init_three_level_tree(@tree_configuration)
    release1 = @project.cards.find_by_name('release1')
    count_of_all_descendents_aggregate = create_aggregate_property_definition(default_options.merge(:aggregate_condition => "Type = Iteration"))
    assert_equal "2.00", count_of_all_descendents_aggregate.compute_card_aggregate_value(release1)
  end
  
  def test_associated_property_definitions_should_include_target_property_definition
    init_three_level_tree(@tree_configuration)
    release1 = @project.cards.find_by_name('release1')
    cp_size = setup_numeric_text_property_definition('size')
    cp_aggregate = create_aggregate_property_definition(default_options.merge(:aggregate_type => AggregateType::SUM, :aggregate_target_id => cp_size.id))
    assert_equal ['size'], cp_aggregate.associated_property_definitions.map(&:name)
  end
  
  def test_associated_property_definitions_should_include_properties_used_in_mql_condition
    init_three_level_tree(@tree_configuration)
    release1 = @project.cards.find_by_name('release1')
    cp_size = setup_numeric_text_property_definition('size')
    cp_aggregate = create_aggregate_property_definition(default_options.merge(:aggregate_condition => "size = 2"))
    assert_equal ['size'], cp_aggregate.associated_property_definitions.map(&:name)
  end
  
  def test_valid_mql_condition_should_pass_validation
    init_three_level_tree(@tree_configuration)
    setup_numeric_text_property_definition 'size'
    cp_aggregate = create_aggregate_property_definition(default_options.merge(:aggregate_condition => 'size = 2'))
    assert cp_aggregate.valid?
  end
  
  def test_aggregate_condition_must_be_valid_condition
    init_three_level_tree(@tree_configuration)
    cp_aggregate = create_aggregate_property_definition(default_options.merge(:aggregate_condition => "jimmy = 1"))
    assert_equal ["Aggregate condition is not valid. Card property '#{'jimmy'.bold}' does not exist!"], cp_aggregate.errors.full_messages
    assert !cp_aggregate.valid?
  end

  def test_when_defining_condition_for_aggregate_it_should_not_be_empty
    init_three_level_tree(@tree_configuration)
    cp_aggregate = create_aggregate_property_definition(default_options.merge(:aggregate_condition => "", :has_condition => true))
    assert_equal ["Aggregate condition cannot be blank"], cp_aggregate.errors.full_messages
    assert !cp_aggregate.valid?
  end
  
  def test_aggregate_condition_should_check_for_supported_mql_subset
    init_three_level_tree(@tree_configuration)
    setup_date_property_definition('start')
    cp_aggregate = create_aggregate_property_definition(default_options.merge(:aggregate_condition => "start = TODAY"))
    assert_equal [CardQuery::AggregateConditionValidations::TODAY_USED], cp_aggregate.errors.full_messages
    assert !cp_aggregate.valid?
  end
  
  def test_aggregate_condtion_must_be_an_executable_condition
    init_three_level_tree(@tree_configuration)
    cp_aggregate = create_aggregate_property_definition(default_options.merge(:aggregate_condition => "type is timmy"))
    assert cp_aggregate.errors.full_messages.first.include?("Aggregate condition is not valid. #{'timmy'.bold} is not a valid value for #{'Type'.bold}")
    assert !cp_aggregate.valid?
  end

  def test_renaming_a_card_type_renames_it_in_an_aggregate_condition
    init_three_level_tree(@tree_configuration)
    cp_aggregate = create_aggregate_property_definition(default_options.merge(:aggregate_condition => "type is Story"))
    @type_story.update_attribute(:name, "PeeWee")
    assert_equal "Type = PeeWee", cp_aggregate.reload.aggregate_condition 
  end
  
  def test_should_not_allow_circular_reference_in_condition
    with_new_project do |project|
      @project = project
      story_type, defect_type = %w{story defect}.collect { |card_type_name| Project.current.card_types.create :name => card_type_name }
      story_defect_configuration = project.tree_configurations.create!(:name => 'story_defect')
    
      story_defect_configuration.update_card_types({
        story_type  => { :position => 0, :relationship_name => 'story_defect story' },
        defect_type => { :position => 1 }
      })
      story_defect_configuration.create_tree
      story_defect_configuration.reload
      
      defect_story_configuration = project.tree_configurations.create!(:name => 'defect_story')
      defect_story_configuration.update_card_types({
        defect_type => { :position => 0, :relationship_name => 'defect_type defect' },
        story_type  => { :position => 1 }
      })
      defect_story_configuration.create_tree
      defect_story_configuration.reload
      
      count_of_defects = create_aggregate_property_definition(default_options.merge(:name => 'count_of_defects', :tree_configuration_id => story_defect_configuration.id, :aggregate_card_type_id => story_type.id))
      count_of_stories = create_aggregate_property_definition(default_options.merge(:name => 'count_of_stories', :tree_configuration_id => defect_story_configuration.id, :aggregate_card_type_id => defect_type.id, :aggregate_condition => "count_of_defects > 0"))
      count_of_defects.update_attribute :aggregate_condition, 'count_of_stories > 0'
      assert !count_of_defects.valid?
      assert count_of_defects.errors.full_messages.first.include?('circular reference')
    end
  end

  def test_should_not_allow_circular_reference_in_condition_many_levels_deep
    with_new_project do |project|
      @project = project
      story_type, defect_type, release_type = %w{story defect release}.collect { |card_type_name| Project.current.card_types.create :name => card_type_name }
      
      release_story_defect_configuration = three_level_tree(project, 'release_story_defect', [release_type, story_type, defect_type])
      defect_release_story_configuration = three_level_tree(project, 'defect_release_story', [defect_type, release_type, story_type])
      story_defect_release_configuration = three_level_tree(project, 'story_defect_release', [story_type, defect_type, release_type])
         
      # release_story_defect 
      #                         T - release A - count_of_defects   C - "count_of_stories > 0"   
      # defect_release_story 
      #                         T - defect  A - count_of_stories   C - "count_of_release > 0"        
      # story_defect_release 
      #                         T- story    A - count_of_releases  C - "count_of_defect > 0"
        
      count_of_defects = create_aggregate_property_definition(default_options.merge(
        :name => 'count_of_defects', 
        :tree_configuration_id => release_story_defect_configuration.id, 
        :aggregate_card_type_id => release_type.id))
          
      count_of_releases = create_aggregate_property_definition(default_options.merge(
        :name => 'count_of_releases', 
        :tree_configuration_id => story_defect_release_configuration.id, 
        :aggregate_card_type_id => story_type.id, 
        :aggregate_condition => "count_of_defects > 0"))
      
      count_of_stories = create_aggregate_property_definition(default_options.merge(
        :name => 'count_of_stories', 
        :tree_configuration_id => defect_release_story_configuration.id, 
        :aggregate_card_type_id => defect_type.id, 
        :aggregate_condition => "count_of_releases > 0"))
      
      count_of_defects.update_attribute :aggregate_condition, 'count_of_stories > 0'
      assert !count_of_defects.valid?, "should have failed validation"
      assert count_of_defects.errors.full_messages.first.include?('circular reference'), "error message should include words circular reference"
    end
  end
  
  def test_should_not_allow_circular_reference_involving_combination_of_formulas_and_aggregates
    with_new_project do |project|
      @project = project
      defect_type, task_type = %w{defect task}.collect { |card_type_name| Project.current.card_types.create :name => card_type_name }
      
      width = setup_numeric_text_property_definition("width")
      width.card_types = [task_type]
      width.save!
    
      defect_task_configuration = project.tree_configurations.create!(:name => 'defect_task')    
      defect_task_configuration.update_card_types({
        defect_type => { :position => 0, :relationship_name => 'defect_task_relationship' },
        task_type   => { :position => 1 }
      })
      defect_task_configuration.create_tree
      defect_task_configuration.reload

      task_defect_configuration = project.tree_configurations.create!(:name => 'task_defect')
      task_defect_configuration.update_card_types({
        task_type   => { :position => 0, :relationship_name => 'task_defect_relationship' },
        defect_type => { :position => 1 }
      })
      task_defect_configuration.create_tree
      task_defect_configuration.reload
  
      sum_of_width = create_aggregate_property_definition(default_options.merge(
        :name => 'sum_of_width', 
        :tree_configuration_id => defect_task_configuration.id, 
        :aggregate_card_type_id => defect_type.id,
        :aggregate_type => AggregateType::SUM, 
        :aggregate_target_id => width.id
      ))
      project.all_property_definitions.reload
          
      formula = setup_formula_property_definition("formula", "sum_of_width + 1")
      formula.card_types = [defect_type]
      formula.save!    
          
      sum_of_formula = create_aggregate_property_definition(default_options.merge(
        :name => 'sum_of_formula', 
        :tree_configuration_id => task_defect_configuration.id, 
        :aggregate_card_type_id => task_type.id,
        :aggregate_type => AggregateType::SUM, 
        :aggregate_target_id => formula.id
      ))
      
      sum_of_width.update_attribute :aggregate_condition, 'sum_of_formula > 0'
      sum_of_width.valid?
      assert !sum_of_width.valid?, "should have failed validation"
      assert sum_of_width.errors.full_messages.first.include?('circular reference'), "error message should include words circular reference"
    end  
  end
  
  def test_can_create_a_formula_when_an_aggregate_condition_references_a_nonexistent_property_definition
    with_new_project do |project|
      @project = project
      defect_type, task_type = %w{defect task}.collect { |card_type_name| project.card_types.create :name => card_type_name }
      
      width = setup_numeric_text_property_definition("width")
      width.card_types = [task_type]
      width.save!
      
      defect_task_configuration = project.tree_configurations.create!(:name => 'defect_task')    
      defect_task_configuration.update_card_types({
        defect_type => { :position => 0, :relationship_name => 'defect_task_relationship' },
        task_type   => { :position => 1 }
      })
      defect_task_configuration.create_tree
      defect_task_configuration.reload
      
      task_card = project.cards.create!(:name => 'task card', :card_type_name => 'task')
      defect_card = project.cards.create!(:name => 'defect card', :card_type_name => 'defect')
      
      defect_task_configuration.add_child(defect_card, :to => :root)
      defect_task_configuration.add_child(task_card, :to => defect_card)
      
      count_of_tasks = create_aggregate_property_definition(default_options.merge(
        :name => 'count_of_tasks',
        :tree_configuration_id => defect_task_configuration.id,
        :aggregate_card_type_id => defect_type.id,
        :aggregate_type => AggregateType::COUNT,
        :aggregate_target_id => width.id,
        :aggregate_condition => "width > 5"
      ))
      project.all_property_definitions.reload
      
      width.destroy
      assert_nil project.find_property_definition_or_nil('width')
      
      assert_nothing_raised do
        formula = project.create_formula_property_definition!(:name => "formula", :formula => "2 + 1")
        formula.card_types = [defect_type]
        formula.save!
        formula.update_all_cards
      end
    end
  end
  
  # bug 7998
  def test_should_return_descendant_card_types_that_have_hidden_property_definition
    init_three_level_tree(@tree_configuration)
    
    hidden_size = setup_managed_number_list_definition('hidden size', [1, 2, 3])
    hidden_size.hidden = true
    hidden_size.card_types = [@type_iteration]
    hidden_size.save!
    
    @project.reload
    
    agg = create_aggregate_property_definition(default_options.merge(:aggregate_type => AggregateType::SUM, :aggregate_target_id => hidden_size.id))
    assert_equal [@type_iteration], agg.descendants_that_have_property_definition(hidden_size)
  end
  
  def three_level_tree(project, name, types)
    configuration = project.tree_configurations.create!(:name => name)
    configuration.update_card_types({
      types[0]  => { :position => 0, :relationship_name => "#{name} top" },
      types[1]  => { :position => 1, :relationship_name => "#{name} middle" },
      types[2]  => { :position => 2 }
    })
    configuration.create_tree
    configuration.reload
  end
  
  def test_can_deserialize_dependant_formulas_after_using_the_base_class
    init_three_level_tree(@tree_configuration)
    
    # we think that by creating a pd using the base class forces the generation of the dependant_formulas method
    pd = PropertyDefinition.new(:name => 'hi', :project => @project, :type => 'EnumeratedPropertyDefinition')
    pd.save
    
    # so now when we deserialize on the subclass, it uses the base class's method
    agg = create_aggregate_property_definition(default_options.merge(:dependant_formulas => ['hi']))
    agg = PropertyDefinition.find_by_name('aggregate prop def')
    assert_equal(Array, agg.dependant_formulas.class)
  end
  
  private
  
  def default_options
    {:name => 'aggregate prop def', :aggregate_scope => AggregateScope::ALL_DESCENDANTS, :aggregate_type => AggregateType::COUNT, :aggregate_card_type_id => @type_release.id, :tree_configuration_id => @tree_configuration.id}
  end
  
  def create_aggregate_property_definition(options)
    aggregate_def = @project.property_definitions_with_hidden.create_aggregate_property_definition(options)
    @project.reload.update_card_schema
    aggregate_def
  end
  
  class MessagePublisherStub
    include Test::Unit::Assertions
    
    def publish_card_messages(card_ids)
      @publish_card_messages_called = true
    end
    
    def assert_publish_card_messages_called
      assert @publish_card_messages_called
    end
  end
end
