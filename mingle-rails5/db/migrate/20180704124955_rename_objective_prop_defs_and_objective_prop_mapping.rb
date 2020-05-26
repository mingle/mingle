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

class RenameObjectivePropDefsAndObjectivePropMapping < ActiveRecord::Migration[5.0]
  class << self
    def up
      rename_table :objective_prop_defs, :obj_prop_defs
      rename_table :objective_prop_mappings, :obj_prop_mappings

      rename_column(:obj_prop_mappings, :objective_prop_def_id, :obj_prop_def_id)

    end

    def down
      rename_table :obj_prop_defs, :objective_prop_defs
      rename_table :obj_prop_mappings, :objective_prop_mappings

      rename_column(:objective_prop_mappings, :obj_prop_def_id, :objective_prop_def_id)
    end
  end
end
