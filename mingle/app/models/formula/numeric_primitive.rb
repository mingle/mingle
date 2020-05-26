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
  class NumericPrimitive < Formula::Primitive
    include SqlHelper

    def initialize(number)
      @value = if (number.respond_to?(:value))
                 number.value
               else
                 number
               end
    end

    def +(another)
      if another.respond_to?(:value)
        @value + another.value
      else
        @value + another
      end
    end

    def -(another)
      raise UnsupportedOperationException unless value_can_be_subtracted?(another)
      if another.respond_to?(:value)
        @value - another.value
      else
        @value - another
      end
    end

    def -@
      -@value
    end

    def *(another)
      if another.respond_to?(:value)
        @value * another.value
      else
        @value * another
      end
    end

    def /(another)
      if another.respond_to?(:value)
        @value / another.value
      else
        @value / another
      end
    end

    def to_f
      @value.to_f
    end

    def to_sql(table_name = Card.table_name, cast_to_integer = false, property_overrides = {})
      cast_to_integer ? as_integer(@value) : as_number(@value)
    end

    def output_type
      Formula::Number.new
    end

    def coerce(other)
      if other.kind_of?(Numeric)
        return other, @value
      elsif other.kind_of?(::Date)
        return other.ajd, @value.round
      else
        super
      end
    end

    def ==(another)
      return false if another.nil?
      return false unless another.respond_to?(:value) || another.kind_of?(Numeric)
      another_value = another.respond_to?(:value) ? another.value : another
      @value == another_value
    end

    def can_be_added_to_date?
      true
    end

    def accept(operation)
      operation.visit_numeric_primitive(self)
    end

    def round
      @value.round
    end

    private

    def value_can_be_subtracted?(val)
      return false if val.is_a?(::Date)
      return true if !val.respond_to?(:output_type)
      val.output_type.valid_operations_against_numbers.include?(Formula::Subtraction)
    end
  end
end
