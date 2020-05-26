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
  class Negation < Formula::Operator
    def initialize(operand)
      @operand = operand
    end

    def value(card = nil)
      -@operand
    end

    def to_s
      "-#{@operand}"
    end

    def reason_operation_is_invalid
      "#{@operand.to_s.bold} is a #{@operand.describe_type} and cannot be negated"
    end

    def to_sql(table_name = Card.table_name, cast_to_integer = false, property_overrides = {})
      output_type.to_negation_sql(operands, table_name, property_overrides)
    end

    def operands
      [@operand]
    end

    def self.name
      "negation"
    end

    def accept(operation)
      operation.visit_negation_operator(self, @operand)
      @operand.accept(operation)
    end

    def output_type
      return Formula::NullType.new if undefined?
      types = operand_output_types
      return Formula::NullType.new if types.any?(&:null?)

      types.all?(&:numeric?) ? Formula::Number.new : Formula::NullType.new
    end
    memoize :output_type
  end
end
