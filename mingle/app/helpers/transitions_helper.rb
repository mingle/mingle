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

module TransitionsHelper
  
  def card_type_map
    map = @project.card_types.inject({}) do |result, card_type| 
      card_type_property_definitions = card_type.property_definitions_with_hidden
      card_type_property_definitions = card_type_property_definitions.select { |pd| transition_properties.include?(pd) }
      
      regular_properties = card_type_property_definitions.reject { |property_definition| property_definition.is_a?(TreeRelationshipPropertyDefinition) }
      regular_property_ids = regular_properties.collect { |prop_def| require_and_set_span(prop_def) }
      
      tree_property_ids = @project.tree_configurations.smart_sort_by(&:name).inject([]) do |accumultor, tree_configuration|
        if tree_configuration.include_card_type?(card_type)
          accumultor << set_span(TreeBelongingPropertyDefinition.new(tree_configuration, PropertyType::TreeBelongingType.new))
          tree_configuration.card_types_before(card_type).each { |ct| accumultor << require_and_set_span(tree_configuration.find_relationship(ct)) }
        end
        accumultor
      end
      
      result['cp' + card_type.name] = (regular_property_ids + tree_property_ids).flatten
      result
    end
    global_prop_defs = transition_properties.select { |pd| pd.global? }.smart_sort_by(&:name)
    map['cp'] = global_prop_defs.collect{|prop_def| require_and_set_span(prop_def)}.flatten
    map
  end
  
  def all_prop_defs
    properties = transition_properties
    sets_span = properties.collect { |prop_def| "#{prop_def.html_id}_sets_span" }
    properties.reject! { |property| property.is_a?(TreeBelongingPropertyDefinition) }
    requires_span = properties.collect { |prop_def| "#{prop_def.html_id}_requires_span" }
    (sets_span + requires_span).compact.flatten.to_json
  end
  
  def require_and_set_span(prop_def)
    ["#{prop_def.html_id}_requires_span"] + set_span(prop_def)
  end
  
  def set_span(prop_def)
    ["#{prop_def.html_id}_sets_span"]
  end
  
  def transition_properties
    reject_calculated_properties(@project.property_definitions_in_smart_order(true)) + tree_belonging_properties
  end
  
  def none_tree_belonging_properties
    reject_calculated_properties(@project.property_definitions_without_relationship)
  end
  
  def disabled_message_map
    html_id_prefix = ''
    html_id_postfix = '_sets'
    map = {}
    @project.tree_configurations.each do |tree_configuration|
      relationship = TreeBelongingPropertyDefinition.new(tree_configuration)
      key = "#{html_id_prefix}#{relationship.html_id}#{html_id_postfix}"
      map[key] = {:childMessage => PropertyValue::NOT_SET, :parentMessage => '(determined by relationships)'}
    end
    
    @project.relationship_property_definitions.each do |relationship|
      key = "#{html_id_prefix}#{relationship.html_id}#{html_id_postfix}"
      map[key] = {:childMessage => PropertyValue::NO_CHANGE, :parentMessage => '(determined by tree)' }
    end
    map
  end
  
  def last_card_type_in_tree_map
    card_type_map = @project.card_types.inject({}) { |map, card_type| map[card_type.name] = []; map }
    @project.tree_configurations.each do |tree_configuration|
      card_type_map[tree_configuration.all_card_types.last.name] << tree_dropdown_id(tree_configuration)
    end
    card_type_map
  end
  
  def transition_cannot_be_activated_using_bulk_message(transition)
    require_user_to_enter = transition.require_user_to_enter?
    optional_user_input = transition.has_optional_input?
    
    if require_user_to_enter
      if optional_user_input
        "This transition cannot be activated using the bulk transitions panel because properties are set to #{Transition::USER_INPUT_REQUIRED} and #{Transition::USER_INPUT_OPTIONAL}."
      else
        "This transition cannot be activated using the bulk transitions panel because at least one property is set to #{Transition::USER_INPUT_REQUIRED}."
      end
    elsif optional_user_input
      "This transition cannot be activated using the bulk transitions panel because at least one property is set to #{Transition::USER_INPUT_OPTIONAL}."
    end
  end
  
  def card_type_properties_mapping
    excluded_card_types = [AggregatePropertyDefinition, FormulaPropertyDefinition]
    all_properties_mapping = ['All properties', '']
    
    @project.card_types.inject({}) do |mapping, card_type|
      mapping[card_type.id] = card_type.property_definitions_with_hidden.map do |prop_def|
        [prop_def.name, prop_def.id] unless excluded_card_types.include?(prop_def.class)
      end.compact.unshift(all_properties_mapping)
      mapping
    end.merge({'' => [all_properties_mapping]})
  end
  
  private
  
  def reject_calculated_properties(property_definitions)
    property_definitions.reject { |prop_def| prop_def.calculated? }
  end
  
  def tree_belonging_properties
    @project.tree_configurations.smart_sort_by(&:name).collect do |tree_configuration|
      TreeBelongingPropertyDefinition.new(tree_configuration, PropertyType::TreeBelongingType.new)
    end
  end
  
  def tree_dropdown_id(tree_configuration)
    "tree_belonging_property_definition_#{tree_configuration.id}_sets"
  end
end
