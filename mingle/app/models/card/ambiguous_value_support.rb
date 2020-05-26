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

module AmbiguousValueSupport

  def choose(property_values, property_definition, default_value)
    method = property_definition.is_a?(DatePropertyDefinition) ? :choose_value_for_date_property_filters : :choose_value_for_enumerated_property_filters
    send(method, property_values, property_definition, default_value)
  end

  private
  
  def choose_value_for_enumerated_property_filters(property_values_by_operator, property_definition, default_value)
    minimum, maximum, accepts, rejects = filter_conditions(property_values_by_operator)
    candidates = property_definition.property_values.select do |value|
      next false if rejects.include?(value)
      next false if maximum && value.sort_position >= maximum.sort_position
      next false if minimum && value.sort_position <= minimum.sort_position
      true
    end
    default = to_property_value(default_value)
    property_value = accepts.first || (candidates.include?(default) ? default : candidates.first)
    property_value && property_value.url_identifier
  end

  def choose_value_for_date_property_filters(property_values_by_operator, property_definition, default_value)
    minimum, maximum, accepts, rejects = filter_conditions(property_values_by_operator, :value)
    default = to_property_value(default_value).try(:value) || Clock.today
    minimum ||= [default, maximum].compact.min.advance(:days => -2)
    maximum ||= [default, minimum].compact.max.advance(:days => 2)
    candidates = ((minimum.to_date...maximum.to_date).to_a.tap { |array| array.shift })
    candidates.reject! { |candidate| rejects.include?(candidate) }
    accepts.first || (candidates.include?(default) ? default : candidates.first)
  end
  
  def to_property_value(property_value)
    property_value.is_a?(VariableBinding) ? property_value.property_value : property_value
  end
  
  def filter_conditions(property_values_by_operator, symbol = nil)
    minimum, maximum = extract_property_values(property_values_by_operator, ">", "<") do |property_value_groups|
      property_value_groups.map do |group|
        value = group.sort_by(&:sort_position).last
        symbol ? value.try(symbol) : value
      end
    end
    accepts, rejects = extract_property_values(property_values_by_operator, "=", "<>") do |property_value_groups|
      symbol ? property_value_groups.map { |group| group.map(&symbol) } : property_value_groups
    end
    [minimum, maximum, accepts, rejects]
  end
  
  def extract_property_values(property_values_by_operator, *operators)
    property_value_groups = operators.map do |operator|
      (property_values_by_operator[operator]).map { |property_value| to_property_value(property_value) }
    end
    yield(property_value_groups)
  end
end
