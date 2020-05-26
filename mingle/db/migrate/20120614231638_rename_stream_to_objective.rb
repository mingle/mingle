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

class RenameStreamToObjective < ActiveRecord::Migration
  def self.up
    rename_table 'streams', "#{ActiveRecord::Base.table_name_prefix}objectives"
    rename_table 'stream_snapshots', "#{ActiveRecord::Base.table_name_prefix}objective_snapshots"
    rename_column :works, :stream_id, :objective_id
    rename_column :work_versions, :stream_id, :objective_id
    rename_column :objective_snapshots, :stream_id, :objective_id
  end

  def self.down
    rename_column :objective_snapshots, :objective_id, :stream_id
    rename_table 'objective_snapshots', "#{ActiveRecord::Base.table_name_prefix}stream_snapshots"
    rename_column :work_versions, :objective_id, :stream_id
    rename_column :works, :objective_id, :stream_id
    rename_table 'objectives', "#{ActiveRecord::Base.table_name_prefix}streams"
  end
end
