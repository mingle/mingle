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

class DropProgressUpdateColumnsFromOnlineJobTables < ActiveRecord::Migration
  def self.up
    drop_status_columns_from('card_importing_previews')
    drop_status_columns_from('card_imports')
    drop_status_columns_from('project_exports')
    drop_status_columns_from('project_imports')
  end

  def self.drop_status_columns_from(table)
    remove_column table.to_sym, :status
    remove_column table.to_sym, :progress_message
    remove_column table.to_sym, :error_count
    remove_column table.to_sym, :warning_count
    remove_column table.to_sym, :total
    remove_column table.to_sym, :completed
  end  
  
  def self.down
  end
end
