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
  class DatePrimitive < Formula::Primitive

    def initialize(date)
      @value = if (date.respond_to?(:value))
                 date.value
               else
                 date
               end
    end

    def +(numeric_primitive)
      raise Formula::UnsupportedOperationException unless numeric_primitive.can_be_added_to_date?

      if numeric_primitive.respond_to?(:value)
        @value + numeric_primitive.value.round
      else
        @value + numeric_primitive.round
      end
    end

    def -@
      raise Formula::UnsupportedOperationException
    end

    def -(another)
      if another.respond_to?(:value)
        @value - another.value.round
      elsif another.is_a?(::Date)
        @value - another
      else
        @value - another.round
      end
    end

    def *(another)
      raise Formula::UnsupportedOperationException
    end

    def /(another)
      raise Formula::UnsupportedOperationException
    end

    def to_f
      nil
    end

    def to_sql(table_name = Card.table_name, cast_as_integer = false, property_overrides = {})
      "date '#{@value.strftime}'"
    end

    def output_type
      Formula::Date.new
    end

    def coerce(other)
      if other.kind_of?(Numeric)
        return @value, other.round
      elsif other.kind_of?(::Date)
        return other, @value
      else
        super
      end
    end

    def accept(operation)
      operation.visit_date_primitive(self)
    end
  end
end
