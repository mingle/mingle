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

class AddCardPropertyColumnIndicesToCardsTables < ActiveRecord::Migration
  class MyPropertyDefinition < ActiveRecord::Base
    set_table_name "#{ActiveRecord::Base.table_name_prefix}property_definitions"
    self.inheritance_column = '9328jkjoji_type' # disable single table inheretance
  end
  class MyProject < ActiveRecord::Base
    set_table_name "#{ActiveRecord::Base.table_name_prefix}deliverables"
    self.inheritance_column = '9328jkjoji_type' # disable single table inheretance
    has_many :property_definitions, :class_name => 'AddCardPropertyColumnIndicesToCardsTables::MyPropertyDefinition', :foreign_key => 'project_id'
  end

  def self.up
    return if ActiveRecord::Base.table_name_prefix =~ Project::INTERNAL_TABLE_PREFIX_PATTERN
    MyProject.find(:all, :conditions => ["type = ?", 'Project']).each do |proj|
      next unless MyProject.connection.table_exists?(proj.cards_table)
      cards_columns = column_names(proj.cards_table)
      card_versions_columns = column_names(proj.card_versions_table)
      proj.property_definitions.find(:all, :conditions => ["type = ? OR type = ?", 'TreeRelationshipPropertyDefinition', 'CardRelationshipPropertyDefinition']).each do |pd|
        if cards_columns.include?(pd.column_name.downcase)
          add_index(proj.cards_table, pd.column_name)
        end
        if card_versions_columns.include?(pd.column_name.downcase)
          add_index(proj.card_versions_table, pd.column_name)
        end
      end
    end
  end

  def self.down
    return if ActiveRecord::Base.table_name_prefix =~ Project::INTERNAL_TABLE_PREFIX_PATTERN

    MyProject.find(:all, :conditions => ["type = ?", 'Project']).each do |proj|
      next unless MyProject.connection.table_exists?(proj.cards_table)
      cards_columns = column_names(proj.cards_table)
      card_versions_columns = column_names(proj.card_versions_table)
      proj.property_definitions.find(:all, :conditions => ["type = ? OR type = ?", 'TreeRelationshipPropertyDefinition', 'CardRelationshipPropertyDefinition']).each do |pd|
        if card_versions_columns.include?(pd.column_name.downcase)
          remove_index(proj.card_versions_table, pd.column_name)
        end
        if cards_columns.include?(pd.column_name.downcase)
          remove_index(proj.cards_table, pd.column_name)
        end
      end
    end
  end

  def self.column_names(table)
    MyProject.connection.columns(table).map(&:name).map(&:downcase)
  end
end
