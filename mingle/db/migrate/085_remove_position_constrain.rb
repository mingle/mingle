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

class RemovePositionConstrain < ActiveRecord::Migration
  UNIQUE_PROP_DEF_POSITION_IN_CARD_TREE_INDEX = "#{ActiveRecord::Base.table_name_prefix}unique_pos_in_tree" unless defined?(UNIQUE_PROP_DEF_POSITION_IN_CARD_TREE_INDEX)
  
  def self.up
    remove_index(:property_definitions, :name => UNIQUE_PROP_DEF_POSITION_IN_CARD_TREE_INDEX)    
  end

  def self.down
    add_index(:property_definitions, [:card_tree_id, :position], :unique => true, :name => UNIQUE_PROP_DEF_POSITION_IN_CARD_TREE_INDEX)
  end
end
