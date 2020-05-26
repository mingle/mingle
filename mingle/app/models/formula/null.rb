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
  class Null < Formula::Primitive

    def initialize; end

    def +(another)
      self
    end

    def -(another)
      self
    end

    def *(another)
      self
    end

    def /(another)
      self
    end

    def div(other)
      self
    end

    def -@
      self
    end

    def to_f
      self
    end

    def to_s
      nil
    end

    def to_sql(table_name = Card.table_name, cast_to_integer = false, property_overrides = {})
      "NULL"
    end

    def undefined?
      true
    end

    def output_type
      Formula::NullType.new
    end

    def coerce(other)
      if other.kind_of?(Formula) || other.kind_of?(Numeric)
        return self, other
      elsif other.kind_of?(::Date)
        return self, other.ajd
      else
        super
      end
    end

    def ==(another)
      self.class == another.class
    end

    def can_be_added_to_date?
      true
    end

    def accept(operation)
      operation.visit_null_primitive
    end
  end
end
