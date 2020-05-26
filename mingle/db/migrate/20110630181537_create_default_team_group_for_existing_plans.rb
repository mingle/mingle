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

class CreateDefaultTeamGroupForExistingPlans < ActiveRecord::Migration
  def self.up
    insert_columns = ['id', 'name', 'deliverable_id', 'internal']
    select_columns = [next_id_sql(safe_table_name('groups')), "?", "#{safe_table_name('deliverables')}.id", '?']
        
    execute(sanitize_sql(<<-SQL, 'Team', true, 'Plan'))
      INSERT INTO #{safe_table_name('groups')} (#{insert_columns.join(',')})
        ( SELECT #{select_columns.join(',')} 
          FROM #{safe_table_name('deliverables')}
          WHERE
            id NOT IN (select deliverable_id from #{safe_table_name('groups')})
            and type = ?
        )
    SQL
  end

  def self.down
  end
end
