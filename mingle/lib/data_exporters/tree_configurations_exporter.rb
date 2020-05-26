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

class TreeConfigurationsExporter < BaseDataExporter

  def name
    'Trees'
  end

  def export(sheet)
    index = 1
    sheet.add_headings(sheet_headings)
    project.tree_configurations.each do |tree_configuration|
      all_card_types = tree_configuration.all_card_types
      all_card_types.each_with_index do |card_type, i|
        relationship_name = tree_configuration.tree_relationship_name(card_type)
        aggregate_properties = AggregatePropertyDefinition.aggregate_properties(project, tree_configuration, card_type)
        if relationship_name
          if aggregate_properties.any?
            aggregate_properties.each do |aggregate_property|
              sheet.insert_row(index, [tree_configuration.name, tree_configuration.description, card_type.name, all_card_types[i + 1].name, relationship_name, aggregate_property.name, aggregate_property_value(aggregate_property), aggregate_scope(aggregate_property)])
              index = index.next
            end
          else
            sheet.insert_row(index, [tree_configuration.name, tree_configuration.description, card_type.name, all_card_types[i + 1].name, relationship_name, '', '', ''])
            index = index.next
          end
        end
      end
    end
    Rails.logger.info("Exported Properties to sheet")
  end

  def exportable?
    project.tree_configurations.count > 0
  end

  private

  def headings
    ['Tree name', 'Tree Description', 'Parent Node', 'Child Node', 'Linking Property', 'Aggregate property', 'Aggregate formula', 'Aggregate Scope']
  end

  def project
    Project.current
  end

  def aggregate_property_value(aggregate)
    ("#{aggregate.aggregate_type.display_name}").tap do |description|
      description << " of #{aggregate.target_property_definition.name}" unless aggregate.aggregate_type == AggregateType::COUNT
    end
  end

  def aggregate_scope(aggregate)
    scope_card_type = aggregate.aggregate_scope_card_type_id
    aggregate_condition = aggregate.aggregate_condition
    return aggregate_condition unless aggregate_condition.nil? || aggregate_condition.empty?
    scope_card_type.nil? ? 'All' : CardType.find_by_id(scope_card_type).name
  end
end
