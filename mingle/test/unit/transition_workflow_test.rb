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

class TransitionWorkflowTest < ActiveSupport::TestCase

  def setup
    login_as_member
    @project = create_project
    @project.activate
    
    setup_property_definitions :status => ['fixed', 'new', 'open', 'closed', 'in progress'], 
                               :priority => ['low', 'medium', 'high'],
                               :'Property without values' => []
    @cp_numeric   = setup_numeric_property_definition('numeric', [1, 2, 3])
    @cp_status    = @project.find_property_definition('status')
    @cp_priority  = @project.find_property_definition('priority')
    @cp_no_values = @project.find_property_definition('property without values')
    @card_type = @project.card_types.first
    @card_type.property_definitions = [@cp_status, @cp_priority, @cp_no_values, @cp_numeric]
    @bogus_card_type = setup_card_type @project, 'Bogus', :properties => [@cp_status, @cp_priority, @cp_no_values, @cp_numeric]
  end

  def test_build_should_build_incremented_transition_names_when_name_already_exist
    create_transition(@project, "Move #{@card_type.name} to open", :set_properties => {:priority => 'low'})
    create_transition(@project, "Move #{@card_type.name} to OPEN 1", :set_properties => {:priority => 'low'})
    create_transition(@project, "Move #{@card_type.name} to in progress", :set_properties => {:priority => 'low'})
    expected_names = ['fixed', 'new', 'open 2', 'closed', 'in progress 1'].map { |property_value| "Move #{@card_type.name} to #{property_value}" }
    workflow = TransitionWorkflow.new(@project, :card_type_id => @card_type.id, :property_definition_id => @cp_status.id)
    workflow.build
    assert_equal expected_names, workflow.transitions.map(&:name)
  end

  def test_build_should_build_transitions_with_workflow_prerequisites
    workflow = TransitionWorkflow.new(@project, :card_type_id => @card_type.id, :property_definition_id => @cp_status.id)
    workflow.build
  
    assert_equal 5, workflow.transitions.size
    nil_to_fixed, fixed_to_new, new_to_open, open_to_closed, closed_to_in_progress = workflow.transitions.collect(&:prerequisites).flatten
  
    assert_nil   nil_to_fixed.value
    assert_equal @cp_status, nil_to_fixed.property_definition

    assert_equal 'fixed', fixed_to_new.value
    assert_equal @cp_status, fixed_to_new.property_definition
  
    assert_equal 'new', new_to_open.value
    assert_equal @cp_status, new_to_open.property_definition
  
    assert_equal 'open', open_to_closed.value
    assert_equal @cp_status, open_to_closed.property_definition
  
    assert_equal 'closed', closed_to_in_progress.value
    assert_equal @cp_status, closed_to_in_progress.property_definition
  end

  def test_build_should_build_transitions_with_workflow_actions
    assert_no_difference('Transition.count') do
      workflow = TransitionWorkflow.new(@project, :card_type_id => @card_type, :property_definition_id => @cp_status)
      workflow.build
    
      expected_action_values = ['fixed', 'new', 'open', 'closed', 'in progress']
      workflow.transitions.each_with_index do |transition, index|
        assert_equal 2, transition.actions.size
      
        change_action = transition.actions.detect { |action| action.property_definition == @cp_status }
        today_action  = transition.actions.detect { |action| action.property_definition != @cp_status }
      
        assert_equal expected_action_values[index], change_action.value
        assert_equal '(today)', today_action.value
      end
    end
  end

  def test_build_should_not_persist_property_type_mappings
    assert_no_difference "PropertyTypeMapping.count" do
      TransitionWorkflow.new(@project, :card_type_id => @card_type, :property_definition_id => @cp_status).build
    end
  end

  def test_create_can_handle_property_that_has_no_values
    assert_no_difference('Transition.count') do
      workflow = TransitionWorkflow.new(@project, :card_type_id => @card_type, :property_definition_id => @cp_no_values)
      workflow.create!
      assert_equal [], workflow.transitions
    end
  end

  def test_create_should_create_incremented_transition_names_when_name_already_exist
    create_transition(@project, "Move #{@card_type.name} to open", :set_properties => {:priority => 'low'})
    create_transition(@project, "Move #{@card_type.name} to OPEN 1", :set_properties => {:priority => 'low'})
    create_transition(@project, "Move #{@card_type.name} to in progress", :set_properties => {:priority => 'low'})
    
    assert_difference('Transition.count', 5) do
      workflow = TransitionWorkflow.new(@project, :card_type_id => @card_type, :property_definition_id => @cp_status)
      workflow.create!

      expected_names = ['fixed', 'new', 'open 2', 'closed', 'in progress 1'].map { |property_value| "Move #{@card_type.name} to #{property_value}" }
      assert_equal expected_names, workflow.transitions.map(&:name)
    end
  end

  def test_create_should_create_transitions_with_workflow_prerequisites
    assert_difference(%w(Transition.count TransitionPrerequisite.count), 5) do
      workflow = TransitionWorkflow.new(@project, :card_type_id => @card_type, :property_definition_id => @cp_status)
      workflow.create!
      nil_to_fixed, fixed_to_new, new_to_open, open_to_closed, closed_to_in_progress = workflow.transitions.collect(&:prerequisites).flatten
  
      assert_nil   nil_to_fixed.value
      assert_equal @cp_status, nil_to_fixed.property_definition

      assert_equal 'fixed', fixed_to_new.value
      assert_equal @cp_status, fixed_to_new.property_definition
  
      assert_equal 'new', new_to_open.value
      assert_equal @cp_status, new_to_open.property_definition
  
      assert_equal 'open', open_to_closed.value
      assert_equal @cp_status, open_to_closed.property_definition
  
      assert_equal 'closed', closed_to_in_progress.value
      assert_equal @cp_status, closed_to_in_progress.property_definition
    end
  end

  def test_create_does_not_generate_any_transitions_for_a_property_that_has_no_values
    cp_no_values = @project.find_property_definition('property without values')
    assert_no_difference('Transition.count') do
      workflow = TransitionWorkflow.new(@project, :card_type_id => @card_type, :property_definition_id => cp_no_values)
      workflow.create!
      assert_equal [], workflow.transitions
    end
  end
  
  def test_create_should_create_date_property_definitions_and_associate_them_with_card_type
    workflow = TransitionWorkflow.new(@project, :card_type_id => @card_type, :property_definition_id => @cp_status)
    workflow.create!
    expected_action_values = ['fixed', 'new', 'open', 'closed', 'in progress']
    
    workflow.transitions.each_with_index do |transition, index|
      change_action = transition.actions.detect { |action| action.property_definition == @cp_status }
      date_property = @project.reload.find_property_definition("Moved to #{expected_action_values[index]} on", :with_hidden => true)
      assert_equal 1, date_property.card_types.size
      assert_equal @card_type, date_property.card_types.first
      assert_equal "Reporting property set as part of #{transition.name} transition", date_property.description
      assert_include date_property.column_name, Card.column_names
    end
  end
  
  def test_create_should_create_incremented_date_property_names_when_name_already_exists
    @project.find_property_definition('Priority').update_attributes(:name => "Moved to open on")
    workflow = TransitionWorkflow.new(@project, :card_type_id => @card_type, :property_definition_id => @cp_status)
    workflow.create!
    assert !@project.reload.find_property_definition('Moved to open on 1', :with_hidden => true).nil?
  end
  
  def test_create_should_create_incremented_date_property_names_when_name_already_exists_in_a_different_case
    @project.find_property_definition('Priority').update_attributes(:name => "MOVED TO OPEN ON")
    workflow = TransitionWorkflow.new(@project, :card_type_id => @card_type, :property_definition_id => @cp_status)
    workflow.create!
    assert !@project.reload.find_property_definition('Moved to open on 1', :with_hidden => true).nil?
  end
  
  def test_create_returns_true_and_alter_card_table_for_successful_transition_creation
    workflow = TransitionWorkflow.new(@project, :card_type_id => @card_type, :property_definition_id => @cp_status)
    assert_difference "Card.column_names.size", 5 do
      workflow.create!
    end
  end
  
  def test_create_returns_false_and_not_alter_card_table_if_any_transition_creation_was_unsuccessful
    workflow = TransitionWorkflow.new(@project, :card_type_id => @card_type, :property_definition_id => @cp_status)
    cp_numeric = @cp_numeric
    def workflow.singleton_class
      class << self; self; end
    end
    
    workflow.singleton_class.instance_eval do
      define_method :add_prerequisites_to_transition do |transition, property_and_values|
        # for this one generated transition, make it invalid by adding a faulty prereq
        if transition.name == "Move Card to in progress"
          transition.add_value_prerequisite(cp_numeric, 'not a number')
        else
          super
        end
      end
    end
    assert_no_difference "Card.column_names.size" do
      assert_raise(ActiveRecord::RecordInvalid) { workflow.create! }
    end
  end
  
  def test_existing_transitions_count_returns_zero_if_no_transitions_used
    workflow = TransitionWorkflow.new(@project, :card_type_id => @card_type.id, :property_definition_id => @cp_status.id)
    assert_equal(0, workflow.existing_transitions_count)
  end

  def test_existing_transitions_count_returns_number_of_transitions_using_the_card_type_and_property
    create_transition(@project, "Excluded - Wrong Property", :card_type => @card_type, :set_properties => {:status => 'closed'})
    create_transition(@project, "Excluded - Wrong Card Type", :card_type => @bogus_card_type, :set_properties => {:priority => 'low'})
    create_transition(@project, "Excluded - Missing Card Type", :card_type => nil, :set_properties => {:priority => 'low'})
    create_transition(@project, "Included (1)", :card_type => @card_type, :set_properties => {:priority => 'low'})
    create_transition(@project, "Included (2)", :card_type => @card_type, :set_properties => {:priority => 'medium'})
    
    workflow = TransitionWorkflow.new(@project, :card_type_id => @card_type.id.to_s, :property_definition_id => @cp_priority.id.to_s)
    assert_equal(2, workflow.existing_transitions_count)
  end
  
  # bug 6336
  def test_created_transitions_and_property_definitions_should_have_names_with_valid_lengths
    @project.find_enumeration_value('status', 'fixed').update_attribute(:value, 'f'*255)
    workflow = TransitionWorkflow.new(@project, :card_type_id => @card_type.id, :property_definition_id => @cp_status.id)
    workflow.build
    
    generated_transitions = workflow.workflow_transitions.collect(&:transition)
    generated_date_property_definitions = workflow.workflow_transitions.collect(&:generated_date_property_definition)
    
    assert generated_transitions.any? { |transition| transition.name == "Move Card to #{'f'*239}..." }
    assert generated_date_property_definitions.any? { |pd| pd.name == "Moved to #{'f'*25}... on" }
    assert_nothing_raised do
      TransitionWorkflow.new(@project, :card_type_id => @card_type.id, :property_definition_id => @cp_status.id).create!
    end
  end
  
  # bug 6336 continued
  def test_created_transitions_should_have_names_with_valid_lengths_even_if_they_had_to_be_changed_to_avoid_duplication
    create_transition(@project, "Move Card to #{'f'*239}...", :card_type => @card_type, :set_properties => { :status => 'closed' })
    (1..9).each do |i|
      create_transition(@project, "Move Card to #{'f'*237}... #{i}", :card_type => @card_type, :set_properties => { :status => 'closed' })
    end
    create_transition(@project, "Move Card to #{'f'*236}... 10", :card_type => @card_type, :set_properties => { :status => 'closed' })
    
    @project.find_enumeration_value('status', 'fixed').update_attribute(:value, 'f'*255)
    workflow = TransitionWorkflow.new(@project, :card_type_id => @card_type.id, :property_definition_id => @cp_status.id)
    workflow.build
    generated_transitions = workflow.workflow_transitions.collect(&:transition)
    assert generated_transitions.any? { |transition| transition.name == "Move Card to #{'f'*236}... 11" }
  end
  
  # bug 7038
  def test_create_should_replace_funny_when_property_value_characters_with_underscore
    setup_property_definitions :funky_characters => ['BEGIN []&#= END']
    @cp_funky = @project.find_property_definition('funky_characters')
    workflow = TransitionWorkflow.new(@project, :card_type_id => @card_type, :property_definition_id => @cp_funky)
    workflow.create!    
    assert_equal ['Move Card to BEGIN []&#= END'], workflow.transitions.map(&:name)
    assert_not_nil @project.reload.find_property_definition('Moved to BEGIN _____ END on', :with_hidden => true)
  end

  # bug 7038
  def test_create_should_uniqify_generated_date_property_taking_into_consideration_of_replaced_underscores_from_to_be_created_date_property_names
    setup_property_definitions :nasty => ['&', '#']  # Both are invalid chars
    @cp_nasty = @project.find_property_definition('nasty')
    workflow = TransitionWorkflow.new(@project, :card_type_id => @card_type, :property_definition_id => @cp_nasty)
    workflow.create!
    assert_not_nil @project.reload.find_property_definition('Moved to _ on', :with_hidden => true)
    assert_not_nil @project.find_property_definition('Moved to _ on 1', :with_hidden => true)
  end
  
end
