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

class CreateObjectivePropDefsAndObjectivePropMappingsTable < ActiveRecord::Migration
  class << self
    def up
      create_table :objective_prop_defs do |table|
        table.string :name, null: false
        table.references :program
        table.string :type
        table.timestamps
      end
      create_table :objective_prop_mappings do |table|
        table.references :objective_prop_def
        table.references :objective_type
      end
      add_index(:objective_prop_defs, [:program_id, :name], :unique => true)
      add_index(:objective_prop_mappings, [:objective_prop_def_id, :objective_type_id], :unique => true)
    end

    def down
      remove_index(:objective_prop_mappings, column:[:objective_prop_def_id, :objective_type_id])
      remove_index(:objective_prop_defs, column:[:program_id, :name])
      drop_table :objective_prop_defs
      drop_table :objective_prop_mappings
    end
  end
end
