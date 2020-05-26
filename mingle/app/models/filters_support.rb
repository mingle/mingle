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

module FiltersSupport
  
  def rename_tree(old_name, new_name)
    # Do nothing.
  end
  
  def properties_for_aggregate_by
    return project.all_numeric_property_definitions if card_type_names.empty?
    project.all_numeric_property_definitions.select { |pd| pd.has_one_of_card_types?(card_type_names) }
  end
  
  def properties_for_colour_by
    properties_for_group_by.select(&:colorable?)
  end
  
  def collect_valid_properties_from_card_type_names
    all_available_column_properties = card_type_names.collect do |card_type_name|
      project.property_definitions_for_columns(card_type_name)
    end
    valid = all_available_column_properties.inject { |result, column_properties| result = result & column_properties if result} 
    return valid.nil? ? [] : valid
  end
  
  def column_properties(options={})
    utility_properties = [project.find_property_definition('created_by'), project.find_property_definition('modified_by')]
    if no_card_type_filters?
      property_definitions = options[:without_smart_order] ? project.property_definitions : project.property_definitions.smart_sort_by(&:name)
      return [project.card_type_definition] + property_definitions + utility_properties
    end
    
    card_types = card_type_names.collect { |ct_name| project.card_types.detect { |ct| ct.name.downcase == ct_name.downcase } }.compact
    available_column_properties = options[:without_smart_order] ? card_types.collect(&:property_definitions).flatten.uniq : card_types.collect(&:property_definitions).flatten.uniq.smart_sort_by(&:name)
    [project.card_type_definition] + available_column_properties + utility_properties
  end
  
  def description
    description_header + ": " + (description_without_header || '')
  end  
  
  def properties_for_group_by
    properties_mutual_for_all_card_types.select(&:groupable?)
  end
  
  def properties_for_grid_sort_by
    [project.find_property_definition("Number")] + properties_for_group_by
  end
  
  def properties_mutual_for_all_card_types
    no_card_type_filters? ? project.property_definitions_for_columns : collect_valid_properties_from_card_type_names
  end
  
end
