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

class Aggregate
  include SqlHelper
  
  attr_reader :aggregate_type, :property_definition
  
  class << self
    def value(project, params, column_or_row, cards)
      from_params(project, params, column_or_row).result(cards).to_s
    end

    def to_output_format(project, value)
      project.to_num(value)
    end

    def row_from_params(project, params)
      from_params(project, params, :row)
    end

    def column_from_params(project, params)
      from_params(project, params, :column)
    end

    def from_params(project, params, column_or_row)
      type, property_name = extract_type_and_property(params, column_or_row)
      property = project.find_property_definition_or_nil(property_name)
      (property && type) ? build_aggregate_of_property(project, type, property) : Aggregate.new(project, AggregateType::COUNT)
    end
    
    def column_valid?(project, params)
      valid?(project, *extract_type_and_property(params, :column))
    end
    
    def row_valid?(project, params)
      valid?(project, *extract_type_and_property(params, :row))
    end

    private

    def extract_type_and_property(params, target)
      type = (params[:aggregate_type] || {})[target]
      property = (params[:aggregate_property] || {})[target]
      [type, property]
    end

    def valid?(project, type, property)
      return true if type.nil? && property.nil?
      
      if property.blank?
        return type.upcase == "COUNT"
      end
      
      aggregate_type = AggregateType.find_by_identifier(type)
      return false if aggregate_type.nil?
      
      property_definition = project.find_property_definition_or_nil(property)
      return false if property_definition.nil? || !property_definition.numeric?
      true
    end

    def build_aggregate_of_property(project, type_identifier, property)
      aggregate_type = AggregateType.find_by_identifier(type_identifier)
      Aggregate.new(project, aggregate_type, property)
    end
  end
  
  def initialize(project, aggregate_type, property_definition = nil)
    @project = project
    @aggregate_type = aggregate_type
    @property_definition = property_definition
  end
  
  def result(cards)
    values = is_count ? cards : cards.collect do |card| 
      value = @property_definition.value(card)
      value.blank? ? nil : BigDecimal.new(value.to_s)
    end.compact
    @project.to_num(@aggregate_type.result(values))
  end
  
  def result_by_sql(conditions)
    if no_cards_match?(conditions)
      return "0" if is_count
      return
    end
    result = select_value(conditions)
    result = '0' if result && is_count && result == 0
    
    result ? @project.format_num(result) : nil
  end
  
  def is_count
    @aggregate_type == AggregateType::COUNT
  end
  
  private
  
  def no_cards_match?(conditions)
    sql = %{
    SELECT COUNT(*)
    FROM #{Card.quoted_table_name}
    WHERE #{conditions}
    }
    
    sql << %{ AND #{@property_definition.quoted_column_name} IS NOT NULL } unless is_count
    
    ActiveRecord::Base.connection.select_one(sql).values.first.to_i == 0
  end
  
  def select_value(conditions)
    aggregate_column = is_count ? "*" : as_number("#{Card.quoted_table_name}.#{@property_definition.column_name}")
    
    sql = %{
    SELECT #{as_number("#{@aggregate_type.identifier}(#{aggregate_column})", @project.precision)}
    FROM #{Card.quoted_table_name}
    WHERE #{conditions}
    }
    ActiveRecord::Base.connection.select_one(sql).values.first
  end
  
  
end
