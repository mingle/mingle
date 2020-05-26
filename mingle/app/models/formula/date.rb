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
  class Date
    def hash
      self.class.hash
    end

    def eql?(another)
      another.date?
    end

    def to_expression_sql(operand, cast_to_integer=false, property_overrides = {})
      "(#{operand})"
    end

    def to_output_sql(result)
      "(#{Project.connection.select_date_sql(result)})"
    end

    def to_addition_sql(operands, table_name = Card.table_name, property_overrides = {})
      to_date_operation_sql(operands, table_name, property_overrides) do |date_operand_sql, number_operand_sql|
        Project.connection.date_plus_days(date_operand_sql, number_operand_sql)
      end
    end

    def to_subtraction_sql(operands, table_name = Card.table_name, property_overrides = {})
      to_date_operation_sql(operands, table_name, property_overrides) do |date_operand_sql, number_operand_sql|
        Project.connection.date_minus_days(date_operand_sql, number_operand_sql)
      end
    end

    def select_card_values(column_name)
      ActiveRecord::Base.connection.select_values("SELECT DISTINCT #{column_name} FROM #{Card.quoted_table_name} WHERE #{column_name} IS NOT NULL ORDER BY #{column_name}")
    end

    def to_output_format(value)
      ::Date.strptime(value).strftime(Project.current.date_format) rescue nil
    end

    def describe
      'date'
    end

    def numeric?
      false
    end

    def date?
      true
    end

    def null?
      false
    end

    def ==(another)
      another.date?
    end

    def describe_operations(right_side_type)
      right_side_type.valid_operations_against_dates.map(&:name)
    end

    def valid_operations_against_numbers
      [Formula::Addition]
    end

    def valid_operations_against_dates
      [Formula::Subtraction]
    end

    private

    def partition_date_and_numeric_operands(operands)
      operands.partition { |op| op.output_type.date? }.flatten
    end

    def to_date_operation_sql(operands, table_name = Card.table_name, property_overrides = {})
      date_operand, number_operand = partition_date_and_numeric_operands(operands)
      date_operand_sql = date_operand.to_sql(table_name, true, property_overrides)
      number_operand_sql = number_operand.to_sql(table_name, true, property_overrides)
      if (date_operand_sql == "NULL" || number_operand_sql == "NULL")
        "NULL"
      else
        yield(date_operand_sql, number_operand_sql)
      end
    end
  end
end
