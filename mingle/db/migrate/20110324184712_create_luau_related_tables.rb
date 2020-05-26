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

class CreateLuauRelatedTables < ActiveRecord::Migration
  def self.up
    create_table(:luau_groups) do |t|
      t.string :identifier, :null => false
      t.string :full_name, :null => false
    end

    create_table(:luau_group_user_mappings) do |t|
      t.integer :luau_group_id
      t.string :user_login
    end
  end

  def self.down
    drop_table :luau_groups_users
    drop_table :luau_groups
  end
end
