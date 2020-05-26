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

class AddUniquIndexToCardTreeName < ActiveRecord::Migration
  UNIQUE_CARD_TREE_NAME_IN_PROJECT = "#{ActiveRecord::Base.table_name_prefix}uniq_tree_name_in_project" unless defined?(UNIQUE_CARD_TREE_NAME_IN_PROJECT)
  def self.up
    add_index(:card_trees, [:project_id, :name], :unique => true, :name => UNIQUE_CARD_TREE_NAME_IN_PROJECT)
  end

  def self.down
    remove_index(:card_trees, :name => UNIQUE_CARD_TREE_NAME_IN_PROJECT)
  end
end
