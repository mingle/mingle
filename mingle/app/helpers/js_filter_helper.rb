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

module JsFilterHelper
  def to_js_filters(filters)
    filters.inject([]) do |result, filter|
      next result unless filter.respond_to?(:property_definition) && filter.property_definition
      result << filter.to_hash.merge(:valueValue => filter.value_value)
    end.to_json
  end

  def to_js_card_type(card_type, options={})
    property_definitions = property_definitions_for_card_type(card_type, options)
    "new CardType(#{card_type.name.to_json}, #{to_js_property_definition_structure(property_definitions.compact).to_json})"
  end

  def to_js_card_type_without_plv(card_type, options={})
    property_definitions = property_definitions_for_card_type(card_type, options)
    "new CardType(#{card_type.name.to_json}, #{to_js_property_definition_structure(property_definitions.compact, false).to_json})"
  end

  def property_definitions_for_card_type(card_type, options={})
    property_definitions = card_type.filterable_property_definitions_in_smart_order
    if tree = options[:tree]
      property_definitions = ([tree.find_relationship(card_type)] + property_definitions.reject { |property_definition| property_definition.kind_of? TreeRelationshipPropertyDefinition }).compact
    end
    property_definitions
  end

  def to_js_property_definition_structure(property_definitions, include_plv=true)
    property_definitions.inject([]) do |result, property_definition|
      js_property_definition = {}
      js_property_definition[:name] = property_definition.name
      js_property_definition[:tooltip] = property_definition_tooltip(property_definition)
      js_property_definition[:operators] = property_definition.operator_options
      js_property_definition[:nameValuePairs] = include_plv ? options_for_droplist_for_cards_filter(property_definition) : options_for_droplist_for_cards_filter_without_plv(property_definition)
      js_property_definition[:appendedActions] = droplist_appended_actions(:filter, property_definition)
      js_property_definition[:options] = {
        :isDatePropertyDefinition => property_definition.class == DatePropertyDefinition,
        :dateFormat => @project.date_format,
        :isUserPropertyDefinition => property_definition.is_a?(UserPropertyDefinition)
      }
      result << js_property_definition
    end
  end

end
