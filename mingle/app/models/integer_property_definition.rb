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

class IntegerPropertyDefinition < PropertyDefinition
  def is_managed?
    true
  end

  def column_type
    :integer
  end
  def numeric?
    true
  end

  def numeric_comparison_for?(value)
    true
  end

  def property_type
    PropertyType::IntegerType.new
  end

  def values
    []
  end

  def describe_type
    self.name
  end
  alias_method :type_description, :describe_type

  def serialize_lightweight_attributes_to(serializer)
    serializer.property_definition do
      serializer.name name
      serializer.description description
      serializer.type_description describe_type
    end
  end

end
