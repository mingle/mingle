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

class CleanDuplicateTeamMemberships < ActiveRecord::Migration
  def self.up
    duplicates = select_all <<-SQL
      SELECT pm.id, pm.project_id, pm.user_id
      FROM #{safe_table_name('projects_members')} pm 
      INNER JOIN (SELECT user_id, project_id, count(*) AS c 
                  FROM #{safe_table_name('projects_members')}
                  GROUP BY project_id, user_id
                  ) t on (t.user_id = pm.user_id and t.project_id = pm.project_id)
      WHERE t.c > 1
      ORDER BY pm.project_id, pm.user_id
    SQL
    
    
    (duplicates - uniquify(duplicates)).each do |dup_row|
      execute <<-SQL
        DELETE FROM #{safe_table_name('projects_members')} WHERE id=#{dup_row['id']}
      SQL
    end
    
    if ActiveRecord::Base.table_name_prefix.blank?
      remove_index :projects_members, :name => 'idx_proj_memb_on_proj_user'
      add_index :projects_members, [:project_id, :user_id], :unique => true, :name => 'idx_proj_memb_on_proj_user'
    end
  end

  def self.uniquify(duplicates)
    duplicates.inject({}) do |memo, row|
      memo[row['project_id'].to_s + ' ' + row['user_id'].to_s] = row
      memo
    end.values
  end

  def self.down
    raise 'can not go back'
  end
end
