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

module CardTreesHelper
  
  CHOOSE_SCOPE = 'Choose a scope...'
  INVALID_NAME = '(invalid)'
  
  def type_droplist_options()
    @project.card_types.collect{|type|[type.name, type.name]}.unshift(['Select type...', ''])
  end
  
  def config_card_types(tree_configuration)
    ret = if params[:card_types]
      params[:card_types].inject([]) do |result, card_type_name_details_hash_pair|
        card_type_position = card_type_name_details_hash_pair.first 
        card_type_details = card_type_name_details_hash_pair.last
        result[card_type_position.to_i] = @project.card_types.find_by_name(card_type_details[:card_type_name]) unless card_type_details[:card_type_name].blank?
        result
      end
    else
      tree_configuration.all_card_types
    end
    (ret.size < 2) ? (ret + [nil, nil])[0..1] : ret.compact #always show atleast 2 card type containers
  end
  
  def tree_structure_desc(tree_configuration)
    tree_configuration.all_card_types.collect(&:name).join(" > ")
  end
  
  def cancel_link
    if params[:from_url].blank?
      {:action => 'list'}
    else
      params[:from_url]
    end
  end

  def options_for_children(child_type, selected = nil)
    valid_target_definitions = child_type.numeric_property_definitions(:with_hidden => true).reject { |prop_def| prop_def.aggregated? }
    properties_for_children = valid_target_definitions.collect { |prop_def| [prop_def.name, prop_def.id] }
    options_for_target_property(properties_for_children, selected)
  end
  
  def options_for_descendants(descendant_types, selected = nil)
    valid_target_definitions = descendant_types.collect { |type| type.numeric_property_definitions(:with_hidden => true) }.flatten.uniq.reject { |prop_def| prop_def.aggregated? }
    properties_for_descendants = valid_target_definitions.collect { |prop_def| [prop_def.name, prop_def.id] }
    options_for_target_property properties_for_descendants, selected
  end
  
  def options_for_aggregate_property(child_type, descendant_types)
     selected = @aggregate_property_definition.target_property_definition.nil? ? nil : @aggregate_property_definition.target_property_definition.id
     if (@aggregate_property_definition.all_descendants?)
       options_for_descendants(descendant_types, selected)
     else
       options_for_children(child_type, selected)
     end
  end
  
  def options_for_not_applicable_aggregate_property
    options_for_select([['Not applicable', nil]])
  end
  
  def type_id_to_child_options_map(descendant_types)
    the_map = descendant_types.inject({}) do |map, type|
      map[type.id] = options_for_children(type)
      map
    end
    the_map
  end
  
  def aggregate_scopes
    [[CHOOSE_SCOPE, CHOOSE_SCOPE]] + @aggregate_property_definition.scopes_with_values + [[AggregateScope::DEFINE_CONDITION, AggregateScope::DEFINE_CONDITION]]
  end
  
  def selected_aggregate_scope
    if params['aggregate_property_definition']
      card_type_id = params['aggregate_property_definition']['aggregate_scope_card_type_id']
      card_type_id = nil if card_type_id.blank?
      card_type_id.numeric? ? card_type_id.to_i : card_type_id
    elsif @aggregate_property_definition && !@aggregate_property_definition.new_record?
      @aggregate_property_definition.aggregate_condition.blank? ? @aggregate_property_definition.aggregate_scope_card_type_id : AggregateScope::DEFINE_CONDITION
    else
      CHOOSE_SCOPE
    end
  end
  
  def aggregate_types
    [['How you want to aggregate it...', nil]] + AggregateType::TYPES.collect {|type| [type.display_name, type.identifier]}
  end
  
  def existing_property_names
    "[" << @project.property_definitions_with_hidden.collect(&:name).collect(&:to_json).join(',') << "]"
  end  
  
  def init_tree_configuration_nodes(tree, cardTreeView)
    js_string = ""
    config_card_types = config_card_types(tree); 
    config_card_types.each_with_index do |card_type, index|
      js_string << create_card_node(tree, cardTreeView, config_card_types, card_type, index)
    end
    js_string
  end
  
  def create_card_node(tree, cardTreeView, config_card_types, card_type, index)
    previous_node = index==0 ? 'null' : "typeNode#{index - 1}"
    default_relationship_name = nil
    default_card_type_name = card_type ? card_type.name : nil
    if tree.errors.empty? && !@warnings
      default_relationship_name = tree.tree_relationship_name(config_card_types[index -1]) unless index == 0
    else
      unless index == 0
        default_relationship_name = params[:card_types][(index - 1).to_s]["relationship_name"]
      end
    end
    "var typeNode#{index} = #{cardTreeView}.createTypeNode(#{previous_node}, #{default_card_type_name.to_json}, #{default_relationship_name.to_json});"
  end
  
  def aggregate_description(aggregate)
    ("#{aggregate.name}: #{aggregate.aggregate_type.display_name}").tap do |description|
      description << " of #{aggregate.target_property_definition.name}" unless aggregate.aggregate_type == AggregateType::COUNT
    end
  end
  
  private  

  def options_for_target_property(options, selected = nil)
    options_for_select([['What you want to aggregate...', nil]] + options, selected)
  end  
end
