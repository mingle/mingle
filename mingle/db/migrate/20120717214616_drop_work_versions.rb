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

class DropWorkVersions < ActiveRecord::Migration
  def self.up
    remove_column :works, :version
    drop_table :work_versions
  end

  def self.down
    create_table "work_versions", :force => true do |t|
      t.integer  "work_id"
      t.integer  "version"
      t.integer  "objective_id"
      t.integer  "card_number"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "plan_id"
      t.boolean  "completed"
      t.string   "name"
      t.integer  "project_id"
    end

    add_index :work_versions, ["project_id"],                 :name => safe_name("idx_work_vs_on_proj_id")
    add_index :work_versions, ["project_id", "card_number"],  :name => safe_name("idx_work_vs_on_proj_card_num")
    add_index :work_versions, ["plan_id"],                    :name => safe_name("idx_work_vs_on_plan_id")
    add_index :work_versions, ["plan_id", 'stream_id'],       :name => safe_name("idx_work_vs_on_plan_stream_id")
    add_index :work_versions, ["plan_id", 'project_id'],      :name => safe_name("idx_work_vs_on_plan_proj_id")
    add_index :work_versions, ["version"],                    :name => safe_name("idx_work_vs_on_version")

    add_column :works, :version, :integer
  end
end
