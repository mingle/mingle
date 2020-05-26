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

class PropertyDataExporter < BaseDataExporter

  def name
    'Properties'
  end

  def export(sheet)
    index = 1
    sheet.add_headings(sheet_headings)
    Project.current.property_definitions_in_smart_order(true).each do |property_definition|
      data = @row_data.cells([
                          property_definition.name, property_definition.description,
                          property_definition_type(property_definition),
                          property_definition_value(property_definition),
                          boolean_property_definition(property_definition.hidden),
                          boolean_property_definition(property_definition.restricted),
                          boolean_property_definition(property_definition.transition_only)].flatten,
                      unique_property_definition_key(property_definition))
      sheet.insert_row(index, data)
      index = index.next
    end
    Rails.logger.info("Exported Properties to sheet")
  end

  def exportable?
    Project.current.property_definitions_with_hidden.count > 0
  end

  def external_file_data_possible?
    true
  end

  private

  def headings
    ['Name', 'Description', 'Type', 'Values', 'Hidden', 'Locked', 'Transition only']
  end

  def property_definition_type(property_definition)
    return 'Tree Relationship' if property_definition.is_a?(TreeRelationshipPropertyDefinition)
    return 'User' if property_definition.is_a?(UserPropertyDefinition)
    property_definition.describe_type
  end

  def property_definition_value(prop_def)
    return aggregate_property_value(prop_def) if prop_def.is_a?(AggregatePropertyDefinition)
    return formula_property_value(prop_def) if prop_def.is_a?(FormulaPropertyDefinition)
    prop_def.is_a?(EnumeratedPropertyDefinition) ? prop_def.label_values_for_charting.join("\n") : prop_def.property_values_description
  end

  def boolean_property_definition(prop_def_value)
    prop_def_value ? 'Yes' : 'No'
  end

  def aggregate_property_value(aggregate)
    ("#{aggregate.aggregate_type.display_name}").tap do |description|
      description << " of #{aggregate.target_property_definition.name}" unless aggregate.aggregate_type == AggregateType::COUNT
    end
  end

  def formula_property_value(prop_def)
    prop_def.formula.to_s
  end

  def unique_property_definition_key(property_definition)
    "property_definition_#{property_definition.name}"
  end
end
