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

class MigrateGroupMembershipsToUsersRatherThanProjectMembers < ActiveRecord::Migration
  def self.up
    add_column :group_memberships, :user_id, :integer
    add_column :group_memberships, :project_id, :integer

    execute <<-SQL
      DELETE FROM #{safe_table_name('group_memberships')} WHERE projects_member_id NOT IN (SELECT id FROM #{safe_table_name('projects_members')})
    SQL

    execute <<-SQL
      UPDATE #{safe_table_name('group_memberships')} ogm 
      SET user_id=(
        SELECT pm.user_id
        FROM #{safe_table_name('group_memberships')} gm
        JOIN #{safe_table_name('projects_members')} pm ON (gm.projects_member_id = pm.id)
        WHERE gm.id=ogm.id
      ),
      project_id=(
        SELECT pm.project_id
        FROM #{safe_table_name('group_memberships')} gm
        JOIN #{safe_table_name('projects_members')} pm ON (gm.projects_member_id = pm.id)
        WHERE gm.id=ogm.id
      )
    SQL
    
    change_column :group_memberships, :user_id, :integer, :null => false
    change_column :group_memberships, :project_id, :integer, :null => false
    remove_column :group_memberships, :projects_member_id
  end

  def self.down
  end
end
