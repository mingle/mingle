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

class M48Project < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
  has_many :property_definitions, :class_name => 'M48PropertyDefinition', :foreign_key => 'project_id'
  has_many :card_types, :class_name => 'M48CardType', :foreign_key => 'project_id'
  
  def create_default_card_type
    card_types.create :name => 'Card'
  end
end

class M48CardType < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}card_types"
  belongs_to :project, :class_name => 'M48Project', :foreign_key => 'project_id'
  acts_as_list :scope => :project
end

class M48PropertyDefinition < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}property_definitions"
  self.inheritance_column = 'm48_type' #disable single table inheretance
  belongs_to :project, :class_name => 'M48Project', :foreign_key => 'project_id'
  has_many :enumeration_values, :order => :position, :foreign_key => 'property_definition_id'
  def quoted_column_name
    "#{Project.connection.quote_column_name(column_name)}"
  end
  
end

class M48EnumerationValue < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}enumeration_values"
  belongs_to :property_definition, :class_name => "M48PropertyDefinition", :foreign_key => "property_definition_id"
end

class CreateCardTypes < ActiveRecord::Migration
  def self.up
    create_table :card_types do |t|
      t.column "project_id",             :integer
      t.column "name",                   :string,  :null => false
      t.column "color",                  :string
      t.column "position",               :integer
    end
    add_column :cards, :card_type_id, :integer, :null => false
    add_column :card_versions, :card_type_id, :integer, :null => false
    
    M48Project.find(:all).each do |project|
      card_table_name = "#{project.identifier}_cards"
      card_version_table_name = "#{project.identifier}_card_versions"
      add_column card_table_name.to_sym, :card_type_id, :integer
      add_column card_version_table_name.to_sym, :card_type_id, :integer

      property_definitions = project.property_definitions
      type_prop_def = property_definitions.detect{|definition| definition.name.downcase == 'type'}
      
      if type_prop_def
        property_definition_names = project.property_definitions.collect(&:name)
        
        renaming_chart = []
        build_renaming_chart(type_prop_def.name, property_definition_names, type_prop_def.name + " (1.0)", renaming_chart)
        
        renaming_chart.reverse.each do |rename|
          from_name = rename[:from]
          to_name = rename[:to]
          
          prop_def = property_definitions.detect{|definition| definition.name.downcase == from_name.downcase}
          prop_def.update_attribute :name, to_name
        end
      end

      default_card_type = project.create_default_card_type
      
      execute("UPDATE #{safe_table_name(card_table_name)} SET card_type_id = #{default_card_type.id} WHERE project_id = #{project.id}")
      execute("UPDATE #{safe_table_name(card_version_table_name)} SET card_type_id = #{default_card_type.id} WHERE project_id = #{project.id}")
      
      change_column card_table_name.to_sym, :card_type_id, :integer, :null => false
      change_column card_version_table_name.to_sym, :card_type_id, :integer, :null => false
    end
  end

  def self.down
    remove_column :cards, :card_type_id
    remove_column :card_versions, :card_type_id
    
    M48Project.find(:all).each do |project|
      card_table_name = "#{project.identifier}_cards"
      card_version_table_name = "#{project.identifier}_card_versions"
      remove_column card_table_name.to_sym, :card_type_id
      remove_column card_version_table_name.to_sym, :card_type_id
    end
    
    drop_table :card_types
  end
  
  def self.build_renaming_chart(original_name, existing_names, new_name, renaming_chart, root_name = nil, suffix = 1)
    root_name = new_name if (root_name.nil?)
    renaming_chart << {:from => original_name, :to => new_name}
    
    if !existing_names.collect(&:downcase).include?(new_name.downcase)
      return
    end
    
    build_renaming_chart(new_name, existing_names, "#{root_name}_#{suffix}", renaming_chart, root_name, suffix + 1)
  end
end
