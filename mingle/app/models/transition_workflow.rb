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

class TransitionWorkflow
  
  attr_reader :workflow_transitions
  
  def initialize(project, workflow_params)
    @project, @workflow_params = project, workflow_params
    @workflow_transitions = []
  end
  
  def build
    action_values = selected_property_definition.values.collect(&:value)
    prerequisite_values = [nil] + action_values.dup
    from_to_pairs = prerequisite_values.zip(action_values)
    from_to_pairs.pop
    names = Names.new(@project)
    from_to_pairs.each do |(from_value, to_value)|
      transition = Transition.new(:project => @project, :card_type => selected_card_type, :name => names.next_unique_transition_name(selected_card_type.name, to_value))
      
      moved_on_date_property = build_date_property_definition(names, transition.name, to_value)
      mapping = transition.card_type.property_type_mappings.build :property_definition => moved_on_date_property
      
      add_prerequisites_to_transition(transition, selected_property_definition => from_value)
      add_actions_to_transition(transition, selected_property_definition => to_value, moved_on_date_property => PropertyType::DateType::TODAY)
      
      @workflow_transitions << PreviewTransition.new(transition, moved_on_date_property, mapping)
    end
  end
  
  def create!
    build
    @workflow_transitions.each(&:save)
    @project.reload.update_card_schema
  end
  
  def transitions
    @workflow_transitions.collect(&:transition)
  end
  
  def existing_transitions_count
    target_property_definition = @project.all_property_definitions.find(@workflow_params[:property_definition_id])
    @project.transitions.select { |transition| transition.card_type_id == @workflow_params[:card_type_id].to_i && transition.uses_property_definition?(target_property_definition) }.size
  end
  
  def selected_property_definition
    @selected_property_definition ||= @project.all_property_definitions.find(@workflow_params[:property_definition_id])
  end
  
  def selected_card_type
    @selected_card_type ||= @project.card_types.find(@workflow_params[:card_type_id])
  end
  
  private
  
  def build_date_property_definition(names, transition_name, to_value)
    property_name = names.next_unique_property_name(to_value)
    DatePropertyDefinition.new(:name => property_name, :hidden => true, :project => @project, :description => "Reporting property set as part of #{transition_name} transition")
  end
  
  def add_prerequisites_to_transition(transition, property_and_values)
    transition.add_value_prerequisites(property_and_values)
  end
  
  def add_actions_to_transition(transition, property_and_values)
    transition.add_set_value_actions(property_and_values)
  end
  
  class Names
    def initialize(project)
      @project = project
      @to_be_generated_transition_names = []
      @to_be_generated_property_names = []
    end
    
    def next_unique_transition_name(card_type_name, to_value)
      appendage = next_unique_appendage(construct_transition_name(card_type_name, to_value)) do |appendage|
        Transition.exists?(["LOWER(transitions.name) = ? AND project_id = ?", construct_transition_name(card_type_name, to_value, appendage).downcase, @project.id])
      end
      construct_transition_name(card_type_name, to_value, appendage).tap do |new_name|
        @to_be_generated_transition_names << new_name
      end
    end
    
    def next_unique_property_name(to_value)
      appendage = next_unique_appendage(construct_property_name(to_value)) do |appendage|
        @to_be_generated_property_names.include?(construct_property_name(to_value, appendage)) || @project.all_property_definitions.exists?(["LOWER(property_definitions.name) = ?", construct_property_name(to_value, appendage).downcase])
      end
      construct_property_name(to_value, appendage).tap do |new_name|
        @to_be_generated_property_names << new_name
      end
    end
    
    private
    
    def construct_transition_name(card_type_name, to_value, appendage = nil)
      max_length_of_to_value = 255 - "Move #{card_type_name} to #{appendage}".size
      to_value = "#{to_value[0..max_length_of_to_value-4]}..." if to_value.size > max_length_of_to_value
      "Move #{card_type_name} to #{to_value}#{appendage}"
    end
    
    def construct_property_name(to_value, appendage = nil)
      to_value = to_value.gsub(Regexp.new("[#{PropertyDefinition::INVALID_NAME_CHARS}]"), '_')
      max_length_of_to_value = 40 - "Moved to  on#{appendage}".size
      to_value = "#{to_value[0..max_length_of_to_value-4]}..." if to_value.size > max_length_of_to_value
      "Moved to #{to_value} on#{appendage}"
    end
    
    def next_unique_appendage(original_name)
      append, number = '', 0
      while yield(append)
        number = number.succ
        append = " #{number.to_s}"
      end
      append
    end
  end
end

class PreviewTransition
  attr_reader :transition, :generated_date_property_definition
  
  delegate :new_record?, :name, :card_type, :required_properties, :require_comment, :require_user_to_enter?, :has_optional_input?, :used_by, :display_required_properties, :describe_usability, :to => :transition
  
  def initialize(transition, generated_date_property_definition, property_type_mapping)
    @transition, @generated_date_property_definition, @property_type_mapping = transition, generated_date_property_definition, property_type_mapping
  end

  def save
    @generated_date_property_definition.save!
    @transition.actions = @transition.actions.reject { |action| action.property_definition.nil? }
    @transition.add_set_value_action(@generated_date_property_definition, PropertyType::DateType::TODAY)
    Project.current.all_property_definitions.reload
    @transition.save!
    @property_type_mapping.save!
  end
  
  def preview_actions
    @transition.actions.map do |action|
      TransitionActionPreviewDisplayAdapter.new(action, action.property_definition || @generated_date_property_definition)
    end
  end
end
