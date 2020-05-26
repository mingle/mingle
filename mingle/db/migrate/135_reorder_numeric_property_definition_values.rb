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

class M135PropertyDefinition < ActiveRecord::Base  
  set_table_name "#{ActiveRecord::Base.table_name_prefix}property_definitions"
  self.inheritance_column = 'm135_type' # disable single table inheritance
  has_many :enumeration_values, :order => 'value', :foreign_key => 'property_definition_id',:class_name => 'M135EnumerationValue'
end  

class M135EnumerationValue < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}enumeration_values"
end
class ReorderNumericPropertyDefinitionValues < ActiveRecord::Migration
  def self.up
    M135PropertyDefinition.find(:all).select(&:is_numeric).each  do |prop_def|
      sorted_enumeration_values = prop_def.enumeration_values.sort_by{|enu_value| enu_value.value.to_f}
      sorted_enumeration_values.each_with_index do |value, index|
        value.update_attribute(:position, index + 1)
      end
    end
  end
  
  def self.down
  end
end
