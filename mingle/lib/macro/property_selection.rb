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

class PropertySelection
  attr_reader :property, :aggregate
  def initialize(property, aggregate)
    @property = property
    @aggregate = aggregate
  end


  def self.from(card_query, supported_aggregates=AggregateType::TYPES)
    raise InvalidPropertySelectionException.new('Incorrect number of selected properties, must be only one property and aggregate') if card_query.columns.size != 2
    raise InvalidPropertySelectionException.new('AS OF not supported') if card_query.as_of

    property = property_definition(card_query.columns[0])
    self.new(property, aggregate(card_query, supported_aggregates))
  end

  def self.aggregate(card_query, supported_aggregates)
    raise InvalidPropertySelectionException.new('second column must be an aggregate') unless card_query.columns[1].is_a? CardQuery::AggregateFunction
    aggregate_type = AggregateType.find_by_identifier(card_query.columns[1].function)
    property_definition = card_query.columns[1].property_definition

    raise InvalidPropertySelectionException.new("unsupported aggregate: #{aggregate_type.identifier}") unless supported_aggregates.include?(aggregate_type)
    Aggregate.new(Project.current, aggregate_type , property_definition)
  end

  private
  def self.property_definition(column)
    raise InvalidPropertySelectionException.new("property #{column.property_definition.name} is not supported") if PredefinedPropertyDefinitions::TYPES.keys.include?(column.property_definition.name.downcase)
    column.property_definition
  end
end

class InvalidPropertySelectionException < Exception
end
