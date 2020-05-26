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

class Project076 < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
  has_many :property_definitions, :class_name => 'PropertyDefinition076', :foreign_key => 'project_id'
end
class PropertyDefinition076 < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}property_definitions"
  self.inheritance_column = 'm76_type' # disable single table inheritance
  has_many :enumeration_values, :class_name => 'EnumerationValue076', :foreign_key => 'property_definition_id'
  belongs_to :project, :class_name => 'Project076', :foreign_key => 'project_id'
end

class EnumerationValue076 < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}enumeration_values"
  belongs_to :property_definition, :class_name => 'PropertyDefinition076', :foreign_key => 'property_definition_id'
end

class AddNumericToPropertyDefinition < ActiveRecord::Migration
  
  def self.up
    add_column :property_definitions, :is_numeric, :boolean, :default => false
    
    PropertyDefinition076.find_all_by_type('EnumeratedPropertyDefinition').each do |prop_def|
      prop_def.is_numeric = !prop_def.enumeration_values.empty? && prop_def.enumeration_values.all? {|enum_value| enum_value.value.numeric? }
      prop_def.save!
    end
    
    Project076.find(:all).each do |project|
      table_name = safe_table_name("{project.identifier}_cards")
      next unless ActiveRecord::Base.connection.table_exists?(table_name)
      project.property_definitions.find_all_by_type('TextPropertyDefinition').each do |prop_def|
        null_or_blank_count = project.connection.select_value("SELECT COUNT(*) FROM #{table_name} WHERE #{quote_column_name(prop_def.column_name)} IS NULL OR TRIM(#{quote_column_name(prop_def.column_name)}) = ''").to_i
        total_count = project.connection.select_value("SELECT COUNT(*) FROM #{table_name}").to_i
        prop_def.is_numeric = null_or_blank_count != total_count && project.connection.all_property_values_numeric?(table_name, prop_def.column_name)
        prop_def.save!
      end
    end
    
    PropertyDefinition.reset_column_information
  end

  def self.down
    remove_column :property_definitions, :is_numeric
    PropertyDefinition.reset_column_information
  end
end
