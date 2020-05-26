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

class AddProgressUpdateColumnsToAsynchRequestsTable < ActiveRecord::Migration
  def self.up
    # This keeps all tables consistent for easier data migration later.
    add_column :card_importing_previews, :warning_count, :integer, :default => 0

    add_column :asynch_requests, :status, :string
    add_column :asynch_requests, :progress_message, :string
    add_column :asynch_requests, :error_count, :integer, :null => false, :default => 0
    add_column :asynch_requests, :warning_count, :integer, :default => 0
    add_column :asynch_requests, :total, :integer, :null => false, :default => 1
    add_column :asynch_requests, :completed, :integer, :null => false, :default => 0

    migrate_data_to_asynch_requests_from('card_importing_previews', 'CardImportingPreview')
    migrate_data_to_asynch_requests_from('card_imports', 'CardImport')
    migrate_data_to_asynch_requests_from('project_exports', 'ProjectExport')
    migrate_data_to_asynch_requests_from('project_imports', 'ProjectImport')
  end

  def self.sanitize_sql(sql, bind_params)
    SqlHelper.sanitize_sql(sql, bind_params)
  end  

  def self.migrate_data_to_asynch_requests_from(source_table, class_name)
    original_data_sql = <<-SQL
      SELECT id, status, progress_message, error_count, warning_count, total, completed
      FROM #{safe_table_name(source_table)}
    SQL
    
    ActiveRecord::Base.connection.select_all(original_data_sql).each do |data_row|
      update_asynch_request_with_progress_data_sql = <<-SQL
        UPDATE #{safe_table_name("asynch_requests")} SET
          status = :status,
          progress_message = :progress_message,
          error_count = :error_count,
          warning_count = :warning_count,
          total = :total,
          completed = :completed
        WHERE
          asynchable_type = :asynchable_type
          AND asynchable_id = :asynchable_id  
      SQL
      
      bind_params = {
        :status           => data_row['status'],
        :progress_message => data_row['progress_message'],
        :error_count      => data_row['error_count'].to_i,
        :warning_count    => data_row['warning_count'].to_i,
        :total            => data_row['total'].to_i,
        :completed        => data_row['completed'].to_i,
        :asynchable_id    => data_row['id'].to_i,
        :asynchable_type  => class_name
      }
      
      ActiveRecord::Base.connection.execute sanitize_sql(update_asynch_request_with_progress_data_sql, bind_params)
    end
  end
    
  def self.down
    remove_column :card_importing_previews, :warning_count
    remove_column :asynch_requests, :status
    remove_column :asynch_requests, :progress_message
    remove_column :asynch_requests, :error_count
    remove_column :asynch_requests, :warning_count
    remove_column :asynch_requests, :total
    remove_column :asynch_requests, :completed
  end
end
