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

class CreateGroupLuauGroupMembershipsTable < ActiveRecord::Migration
  def self.up
    rename_table :group_memberships, safe_table_name('user_memberships')
    create_table :luau_group_memberships, :force => true do |t|
      t.column :project_id, :integer, :null => false
      t.column :luau_group_id, :integer, :null => false
      t.column :group_id, :integer, :null => false
    end
  end

  def self.down
    rename_table :user_memberships, :group_memberships
    drop_table :luau_group_memberships
  end
end
