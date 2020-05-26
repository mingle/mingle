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

class MoveProjectsMembersToInternalGroupNamedTeam < ActiveRecord::Migration
  def self.up
    remove_column :group_memberships, :created_at
    remove_column :group_memberships, :updated_at
    
    insert_columns = ['id', 'project_id', 'group_id', 'user_id']
    select_columns = [next_id_sql(safe_table_name('group_memberships')), 'team_group.project_id', 'team_group.id', 'user_id']
        
    execute(sanitize_sql(<<-SQL, true))
      INSERT INTO #{safe_table_name('group_memberships')} (#{insert_columns.join(',')})
        ( SELECT #{select_columns.join(',')} 
          FROM #{safe_table_name('projects_members')} pm
          LEFT OUTER JOIN #{safe_table_name('groups')} team_group ON ( team_group.project_id = pm.project_id AND team_group.internal = ?)
        )
    SQL

  end

  def self.down
  end
  
end
