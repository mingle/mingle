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

class MoveProjectIdFromAsynchableToAsynchRequest < ActiveRecord::Migration
  def self.up
    delete_asynch_requests_without_corresponding_project('card_importing_previews', 'CardImportingPreview')
    delete_asynch_requests_without_corresponding_project('card_imports', 'CardImport')
    delete_asynch_requests_without_corresponding_project('project_exports', 'ProjectExport')
    delete_asynch_requests_without_corresponding_project('project_imports', 'ProjectImport')
  
    add_column :asynch_requests, :project_identifier, :string
    migrate_project_id_from('card_importing_previews', 'CardImportingPreview')
    migrate_project_id_from('card_imports', 'CardImport')
    migrate_project_id_from('project_exports', 'ProjectExport')
    migrate_project_id_from('project_imports', 'ProjectImport')
    create_not_null_constraint :asynch_requests, :project_identifier
  end

  def self.sanitize_sql(sql, bind_params)
    SqlHelper.sanitize_sql(sql, bind_params)
  end  

  def self.delete_asynch_requests_without_corresponding_project(asynchable_table, asynchable_type)
    delete_orphan_asynch_requests_sql = <<-SQL
      DELETE FROM #{safe_table_name("asynch_requests")} 
      WHERE 
      asynchable_type = :asynchable_type
      AND asynchable_id NOT IN (
        SELECT a.id 
        FROM #{safe_table_name(asynchable_table)} a
        JOIN #{safe_table_name("projects")} p ON (p.id = a.project_id)
      )
    SQL
    
    ActiveRecord::Base.connection.execute sanitize_sql(delete_orphan_asynch_requests_sql, :asynchable_type => asynchable_type)
  end  

  def self.migrate_project_id_from(asynchable_table, asynchable_type)
    project_id_by_asynchable_id_sql = <<-SQL
      SELECT p.identifier AS project_identifier, a.id
      FROM #{safe_table_name(asynchable_table)} a
      JOIN #{safe_table_name("projects")} p ON (p.id = a.project_id)
    SQL
    
    ActiveRecord::Base.connection.select_all(project_id_by_asynchable_id_sql).each do |data_row|
      update_asynch_request_with_project_id_sql = <<-SQL
        UPDATE #{safe_table_name("asynch_requests")} 
        SET project_identifier = :project_identifier
        WHERE asynchable_id = :asynchable_id
        AND asynchable_type = :asynchable_type
      SQL
      
      bind_params = {
        :project_identifier => data_row['project_identifier'],
        :asynchable_id      => data_row['id'].to_i,
        :asynchable_type    => asynchable_type
      }
      ActiveRecord::Base.connection.execute sanitize_sql(update_asynch_request_with_project_id_sql, bind_params)
    end
  end  

  def self.down
    remove_column :asynch_requests, :project_identifier
  end
end
