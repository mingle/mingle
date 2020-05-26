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

class ChangeProjectStructureKeysToProjectKeys < ActiveRecord::Migration
  def self.up
    rename_table :project_structure_keys, safe_table_name('project_keys')
    rename_column :project_keys, :key, :structure_key
    add_column :project_keys, :card_key, :string
  end

  def self.down
    remove_column :project_keys, :card_key
    rename_column :project_keys, :structure_key, :key
    rename_table :project_keys, :project_structure_keys
  end
end
