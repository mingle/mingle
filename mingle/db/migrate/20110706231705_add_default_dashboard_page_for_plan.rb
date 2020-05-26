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

class AddDefaultDashboardPageForPlan < ActiveRecord::Migration
  def self.up
    insert_columns = ['id', 'name', 'deliverable_id', 'content', 'created_by_user_id', 'modified_by_user_id', 'version', 'has_macros', 'created_at', 'updated_at']
    select_columns = [next_id_sql(safe_table_name('pages')), "'dashboard'", "#{safe_table_name('deliverables')}.id", "'{{work-by-project}}'", "#{safe_table_name('deliverables')}.created_by_user_id", "#{safe_table_name('deliverables')}.created_by_user_id", '1', '?', "#{safe_table_name('deliverables')}.created_at", "#{safe_table_name('deliverables')}.created_at"]
        
    execute(sanitize_sql(<<-SQL, true))
      INSERT INTO #{safe_table_name('pages')} (#{insert_columns.join(',')})
        ( SELECT #{select_columns.join(',')} 
          FROM #{safe_table_name('deliverables')}
          WHERE type = 'Plan'
        )
    SQL
  end

  def self.down
  end
end
