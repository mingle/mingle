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

class MakeProjectAndProgramSingleTableInherited < ActiveRecord::Migration
  def self.up    
    connection.indexes(safe_table_name('projects')).each do |index|
      connection.remove_index(safe_table_name('projects'), :name => index.name)
    end
    
    add_column :projects, :start_at, :date
    add_column :projects, :end_at, :date
    add_column :projects, :type, :string
    
    execute(sanitize_sql("UPDATE #{safe_table_name('projects')} SET type = 'Project'"))
    
    change_column :projects, :type, :string, :null => false
    change_column :projects, :identifier, :string, :null => true
    
    old_id_name_values = ActiveRecord::Base.connection.select_rows <<-SQL
      SELECT id, name FROM #{safe_table_name('plans')}
    SQL

    old_name_id_hash = old_id_name_values.inject({}) do |result, pair|
      result[pair.last] = pair.first
      result
    end

    insert_columns = ['id', 'name', 'start_at', 'end_at', 'created_at', 'updated_at', 'type']
    select_columns = [next_id_sql(safe_table_name('projects')), 'name', 'start_at', 'end_at', 'created_at', 'updated_at', "'Plan'"]

    execute(sanitize_sql(<<-SQL, true))
      INSERT INTO #{safe_table_name('projects')} (#{insert_columns.join(',')})
         (
           SELECT #{select_columns.join(',')}
             FROM #{safe_table_name('plans')}
         )
    SQL
    
    new_id_name_values = ActiveRecord::Base.connection.select_rows <<-SQL
      SELECT id, name FROM #{safe_table_name('projects')} WHERE type = 'Plan'
    SQL

    new_name_id_hash = new_id_name_values.inject({}) do |result, pair|
      result[pair.last] = pair.first
      result
    end

    old_name_id_hash.each do |name, old_id|
      new_id = new_name_id_hash[name]
      execute <<-SQL
        UPDATE #{safe_table_name('plan_projects')}
           SET plan_id = #{new_id}
         WHERE plan_id = #{old_id}
      SQL

      execute <<-SQL
        UPDATE #{safe_table_name('streams')}
           SET plan_id = #{new_id}
         WHERE plan_id = #{old_id}
      SQL

      execute <<-SQL
        UPDATE #{safe_table_name('works')}
           SET plan_id = #{new_id}
         WHERE plan_id = #{old_id}
      SQL

      execute <<-SQL
        UPDATE #{safe_table_name('work_versions')}
           SET plan_id = #{new_id}
         WHERE plan_id = #{old_id}
      SQL
    end

    add_index :projects, [:name, :type], :unique => true
    add_index :projects, [:identifier, :type]
    rename_table :projects, safe_table_name("deliverables")
    drop_table :plans
  end

  def self.down
    remove_index :projects, [:name, :type]
    remove_index :projects, [:identifier, :type]
    
    remove_column :projects, :type
    remove_column :projects, :end_at
    remove_column :projects, :start_at
    
    change_column :projects, :identifier, :string, :null => 'false'
    
    add_index "projects", ["identifier"], :name => "unique_index__projects_on_identifier", :unique => true
    add_index "projects", ["name"], :name => "index_projects_on_name", :unique => true
    
    rename_table :deliverables, :projects
    
    create_table "plans", :force => true do |t|
      t.string   "name",       :limit => 40
      t.date     "start_at"
      t.date     "end_at"
      t.datetime "created_at"
      t.datetime "updated_at"
    end
  end
end
