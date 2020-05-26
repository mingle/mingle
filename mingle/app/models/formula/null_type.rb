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
  class NullType

    def to_addition_sql(operands, table_name = Card.table_name, property_overrides = {})
      "NULL"
    end

    alias_method :to_subtraction_sql,    :to_addition_sql
    alias_method :to_multiplication_sql, :to_addition_sql
    alias_method :to_division_sql,       :to_addition_sql
    alias_method :to_negation_sql,       :to_addition_sql

    def select_card_values(column_name)
      []
    end

    def to_expression_sql(operand, cast_to_integer = false, property_overrides = {})
      "NULL"
    end

    def to_output_sql(result)
      result
    end

    def to_output_format(value)
      nil
    end

    def describe
      'undefined'
    end

    def numeric?
      false
    end

    def date?
      false
    end

    def null?
      true
    end

    def ==(another)
      another.null?
    end

    def valid_operations_against_numbers
      [Formula::Addition, Formula::Subtraction, Formula::Multiplication, Formula::Division]
    end

    def valid_operations_against_dates
      [Formula::Addition, Formula::Subtraction, Formula::Multiplication, Formula::Division]
    end
  end
end
