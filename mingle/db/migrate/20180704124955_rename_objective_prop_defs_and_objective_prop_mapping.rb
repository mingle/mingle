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

class RenameObjectivePropDefsAndObjectivePropMapping < ActiveRecord::Migration
  class << self
    def up
      delete_indices(:objective_prop_defs, :objective_prop_mappings)
      rename_table :objective_prop_defs, safe_table_name(:obj_prop_defs)
      rename_table :objective_prop_mappings, safe_table_name(:obj_prop_mappings)

      rename_column(:obj_prop_mappings, :objective_prop_def_id, :obj_prop_def_id)


      add_index(:obj_prop_defs, [:program_id, :name], :unique => true)
      add_index(:obj_prop_mappings, [:obj_prop_def_id, :objective_type_id], :unique => true)
    end

    def down
      delete_indices(:obj_prop_defs, :obj_prop_mappings)
      rename_table :obj_prop_defs, safe_table_name(:objective_prop_defs)
      rename_table :obj_prop_mappings, safe_table_name(:objective_prop_mappings)

      rename_column(:objective_prop_mappings, :obj_prop_def_id, :objective_prop_def_id)

      add_index(:objective_prop_defs, [:program_id, :name], :unique => true)
      add_index(:objective_prop_mappings, [:objective_prop_def_id, :objective_type_id], :unique => true)
    end

    def delete_indices(*tables)
      tables.each do |table|
        indexes(table).each do |index|
          remove_index table, name: index.name
        end
      end
    end
  end
end
