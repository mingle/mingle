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

class M50Project < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
end

class ChangeCardsAndCardVersionsToUseCardTypeName < ActiveRecord::Migration
  def self.up
    add_column :cards, :card_type_name, :string, :null => false
    add_column :card_versions, :card_type_name, :string, :null => false
    
    remove_column :cards, :card_type_id
    remove_column :card_versions, :card_type_id
    
    M50Project.find(:all).each do |project|
      ["#{project.identifier}_cards", "#{project.identifier}_card_versions"].each do |table_name|
        add_column table_name.to_sym, :card_type_name, :string
        execute("UPDATE #{safe_table_name(table_name)} SET card_type_name = (SELECT #{safe_table_name('card_types')}.name FROM #{safe_table_name('card_types')} WHERE #{safe_table_name('card_types')}.id=#{safe_table_name(table_name)}.card_type_id)")
        change_column table_name.to_sym, :card_type_name, :string, :null => false
        remove_column table_name.to_sym, :card_type_id
      end
    end
  end

  def self.down
    remove_column :cards, :card_type_name
    remove_column :card_versions, :card_type_name
    add_column :cards, :card_type_id, :integer
    add_column :card_versions, :card_type_id, :integer

    M50Project.find(:all).each do |project|
      card_table_name = "#{project.identifier}_cards"
      card_version_table_name = "#{project.identifier}_card_versions"
      
      remove_column card_table_name.to_sym, :card_type_name
      remove_column card_version_table_name.to_sym, :card_type_name
      
      add_column card_table_name.to_sym, :card_type_id, :integer
      add_column card_version_table_name.to_sym, :card_type_id, :integer
    end
  end
end
