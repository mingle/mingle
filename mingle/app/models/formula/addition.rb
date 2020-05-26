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
  class Addition < Formula::Operator
    def initialize(operand1, operand2)
      @operand1, @operand2 = operand1, operand2
    end

    def value(card = nil)
      @operand1 + @operand2
    end

    def to_s
      "#{@operand1} + #{@operand2}"
    end

    def to_sql(table_name = Card.table_name, cast_to_integer = false, property_overrides = {})
      output_type.to_addition_sql(operands, table_name, property_overrides)
    end

    def reason_operation_is_invalid
      "a #{@operand1.describe_self_with_type } cannot be added to a #{@operand2.describe_self_with_type}"
    end

    def operands
      [@operand1, @operand2]
    end

    def self.name
      "addition"
    end

    def accept(operation)
      operation.visit_addition_operator(self, *operands)
      operands.each { |o| o.accept(operation) }
    end

    def output_type
      return Formula::NullType.new if undefined?
      types = operand_output_types
      return Formula::NullType.new if types.any?(&:null?)
      return Formula::Number.new if types.all?(&:numeric?)

      if types.all?(&:date?)
        Formula::Null.new
      else
        Formula::Date.new
      end
    end
    memoize :output_type
  end
end
