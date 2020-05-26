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

class AddUniqConstraintToObjectivesSnapshots < ActiveRecord::Migration
  def self.up
    execute("delete from #{safe_table_name('objective_snapshots')} where id not in (select min(id) as id from #{safe_table_name('objective_snapshots')} group by objective_id, project_id, dated)")
    add_index(:objective_snapshots, [:objective_id, :project_id, :dated], :unique => true, :name => "#{ActiveRecord::Base.table_name_prefix}idx_obj_proj_dated")

  end

  def self.down
    remove_index(:objective_snapshots, :name => "#{ActiveRecord::Base.table_name_prefix}idx_obj_proj_dated")
  end
end
