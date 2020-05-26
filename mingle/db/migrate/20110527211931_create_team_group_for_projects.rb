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

class CreateTeamGroupForProjects < ActiveRecord::Migration
  def self.up
    remove_column :groups, :created_at
    remove_column :groups, :updated_at
    insert_with_select(:table => 'groups', :from => 'projects', 
      :insert_columns => ['project_id', 'name'  , 'internal'],
      :select_columns => ['id'        , "'team'", '?'    ], 
      :bind_values =>  [true] )
  end

  def self.down
    execute(sanitize_sql(<<-SQL, true))
     DELETE FROM #{safe_table_name('groups')} 
     WHERE internal=?
    SQL
  end
  
  
  def self.insert_with_select(options)
    options[:insert_columns].unshift('id')
    insert_columns = options[:insert_columns].join(", ")
    
    options[:select_columns].unshift(next_id_sql(safe_table_name(options[:table])))
    select_columns = options[:select_columns].join(", ")
    
    sql = %{
      INSERT INTO #{safe_table_name(options[:table])} (#{insert_columns})
        (SELECT #{select_columns} FROM #{safe_table_name(options[:from])})
    }
    execute(sanitize_sql(sql, *(options[:bind_values] || [])))
  end
end
