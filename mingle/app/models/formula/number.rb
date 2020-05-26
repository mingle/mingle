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

class Formula
  class Number
    include SqlHelper

    def hash
      self.class.hash
    end

    def eql?(another)
      another.numeric?
    end

    def to_expression_sql(operand, cast_to_integer = false, property_overrides = {})
      cast_to_integer ? as_integer(operand) : connection.as_padded_number(operand, Project.current.precision)
    end

    def to_output_sql(result)
      result
    end

    def to_addition_sql(operands, table_name = Card.table_name, property_overrides = {})
      "#{operands.first.to_sql(table_name, false, property_overrides)} + #{operands.second.to_sql(table_name, false, property_overrides)}"
    end

    def to_subtraction_sql(operands, table_name = Card.table_name, property_overrides = {})
      if operands.map(&:output_type).all?(&:date?)
        ActiveRecord::Base.connection.date_minus_date(operands.first.to_sql(table_name, false, property_overrides), operands.second.to_sql(table_name, false, property_overrides))
      else
        "#{operands.first.to_sql(table_name, false, property_overrides)} - #{operands.second.to_sql(table_name, false, property_overrides)}"
      end
    end

    def to_multiplication_sql(operands, table_name = Card.table_name, property_overrides = {})
      "#{operands.first.to_sql(table_name, false, property_overrides)} * #{operands.second.to_sql(table_name, false, property_overrides)}"
    end

    def to_division_sql(operands, table_name = Card.table_name, property_overrides = {})
      "(CASE WHEN (#{operands.second.to_sql(table_name, false, property_overrides)} = 0) THEN NULL ELSE (#{operands.first.to_sql(table_name, false, property_overrides)} / #{operands.second.to_sql(table_name, false, property_overrides)}) END)"
    end

    def to_negation_sql(operands, table_name = Card.table_name, property_overrides = {})
      "-#{operands.first.to_sql(table_name, false, property_overrides)}"
    end

    def select_card_values(column_name)
      Project.connection.select_values("SELECT #{column_name}, #{Project.connection.as_number(column_name)} AS order_by_column FROM #{Card.quoted_table_name} WHERE #{column_name} IS NOT NULL GROUP BY #{column_name} ORDER BY order_by_column ASC")
    end

    def to_output_format(value)
      Project.current.to_num(value)
    end

    def numeric?
      true
    end

    def date?
      false
    end

    def null?
      false
    end

    def describe
      'number'
    end

    def ==(another)
      another.numeric?
    end

    def describe_operations(right_side_type)
      right_side_type.valid_operations_against_numbers.map(&:name)
    end

    def valid_operations_against_numbers
      [Formula::Addition, Formula::Subtraction, Formula::Multiplication, Formula::Division]
    end

    def valid_operations_against_dates
      [Formula::Addition, Formula::Subtraction]
    end
  end
end
