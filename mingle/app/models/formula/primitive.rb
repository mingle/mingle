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
  class Primitive < Formula

    class << self
      def create(primitive_value)
        primitive_value.respond_to?(:strftime) ? Formula::DatePrimitive.new(primitive_value) : Formula::NumericPrimitive.new(primitive_value)
      end
    end

    def value(card = nil)
      self
    end

    def bind_to(card); end

    def undefined?
      false
    end

    def to_s
      "#{@value}"
    end

    def rename_property(old_name, new_name); end

    def invalid_properties
      []
    end

    def describe_invalid_operations
      []
    end

    def round
      self
    end
  end
end
