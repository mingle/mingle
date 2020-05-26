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

class SetupInfastructureForCardTrees < ActiveRecord::Migration
  UNIQUE_CARD_IN_CARD_TREE_INDEX = "#{ActiveRecord::Base.table_name_prefix}unique_card_in_tree" unless defined?(UNIQUE_CARD_IN_CARD_TREE_INDEX)
  UNIQUE_PROP_DEF_POSITION_IN_CARD_TREE_INDEX = "#{ActiveRecord::Base.table_name_prefix}unique_pos_in_tree" unless defined?(UNIQUE_PROP_DEF_POSITION_IN_CARD_TREE_INDEX)
  
  def self.up
    create_table :card_trees do |t|
      t.column "name",          :string,      :null => false   
      t.column "project_id",    :integer,      :null => false   
      t.column "description",   :string
    end
    
    create_table :card_trees_cards do |t|
      t.column 'card_tree_id', :integer, :null => false
      t.column 'card_id', :integer, :null => false
    end
    add_index(:card_trees_cards, [:card_tree_id, :card_id], :unique => true, :name => UNIQUE_CARD_IN_CARD_TREE_INDEX)
    
    add_column :property_definitions, :card_tree_id, :integer
    add_column :property_definitions, :child_type_id, :integer
    add_column :property_definitions, :position, :integer
    
    add_index(:property_definitions, [:card_tree_id, :position], :unique => true, :name => UNIQUE_PROP_DEF_POSITION_IN_CARD_TREE_INDEX)
  
    PropertyDefinition.reset_column_information
  end

  def self.down
    remove_index(:property_definitions, :name => UNIQUE_PROP_DEF_POSITION_IN_CARD_TREE_INDEX)
    remove_column :property_definitions, :card_tree_id
    remove_column :property_definitions, :position
    remove_column :property_definitions, :child_type_id
    
    remove_index(:card_trees_cards, :name => UNIQUE_CARD_IN_CARD_TREE_INDEX)
    drop_table :card_trees_cards
    
    drop_table :card_trees
    
    PropertyDefinition.reset_column_information
  end
end
