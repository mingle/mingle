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

class MergeWorksTables < ActiveRecord::Migration
  def self.up
    rename_table :scheduled_works, safe_table_name("works")
    rename_table :scheduled_work_versions, safe_table_name("work_versions")
    rename_column :work_versions, :scheduled_work_id, :work_id
    drop_table :draft_works
  end

  def self.down
    create_table "draft_works", :force => true do |t|
      t.references :stream
      t.references :project
      t.references :card
      t.timestamps
    end
    rename_column :work_versions, :work_id, :scheduled_work_id
    rename_table :works, safe_table_name('scheduled_works')
    rename_table :work_versions, safe_table_name('scheduled_work_versions')
  end
end
