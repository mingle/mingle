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

class PropertyUsage

  class CardDefaults
    attr_reader :card_defaults

    def initialize(property_value, card_defaults)
      @card_defaults = card_defaults
      @property_value = property_value
    end

    def project
      @property_value.project
    end

    def empty?
      @card_defaults.empty?
    end

    def clean
      @card_defaults.each do |default|
        default.stop_using_property_value(@property_value)
      end
    end
  end

  attr_reader :count, :property_value
  
  def initialize(property_value, count)
    @property_value = property_value
    @count = count
  end

  def property_name
    @property_value.name
  end

  def empty?
    @count == 0
  end

  def clean
    return if empty?
    @property_value.property_definition.replace_values(@property_value.db_identifier, nil)
  end

  def project
    @property_value.project
  end
end
