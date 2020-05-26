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

class AddProjectIdIntoWorksTable < ActiveRecord::Migration
  def self.up
    add_column :works, :project_id, :integer
    add_column :work_versions, :project_id, :integer
    remove_column :works, :plan_project_id
    remove_column :work_versions, :plan_project_id

    add_index :works, ["project_id"],                 :name => safe_name("idx_works_on_proj_id")
    add_index :works, ["project_id", "card_number"],  :name => safe_name("idx_works_on_proj_card_num")
    add_index :works, ["plan_id"],                    :name => safe_name("idx_works_on_plan_id")
    add_index :works, ["plan_id", 'stream_id'],       :name => safe_name("idx_works_on_plan_stream_id")
    add_index :works, ["plan_id", 'project_id'],      :name => safe_name("idx_works_on_plan_proj_id")

    add_index :work_versions, ["project_id"],                 :name => safe_name("idx_work_vs_on_proj_id")
    add_index :work_versions, ["project_id", "card_number"],  :name => safe_name("idx_work_vs_on_proj_card_num")
    add_index :work_versions, ["plan_id"],                    :name => safe_name("idx_work_vs_on_plan_id")
    add_index :work_versions, ["plan_id", 'stream_id'],       :name => safe_name("idx_work_vs_on_plan_stream_id")
    add_index :work_versions, ["plan_id", 'project_id'],      :name => safe_name("idx_work_vs_on_plan_proj_id")
    add_index :work_versions, ["version"],                    :name => safe_name("idx_work_vs_on_version")
  end

  def self.down
    remove_index :works, :name => safe_name("idx_works_on_proj_id")
    remove_index :works, :name => safe_name("idx_works_on_proj_card_num")
    remove_index :works, :name => safe_name("idx_works_on_plan_id")
    remove_index :works, :name => safe_name("idx_works_on_plan_stream_id")
    remove_index :works, :name => safe_name("idx_works_on_plan_proj_id")

    remove_index :work_versions, :name => safe_name("idx_work_vs_on_proj_id")
    remove_index :work_versions, :name => safe_name("idx_work_vs_on_proj_card_num")
    remove_index :work_versions, :name => safe_name("idx_work_vs_on_plan_id")
    remove_index :work_versions, :name => safe_name("idx_work_vs_on_version")
    remove_index :work_versions, :name => safe_name("idx_work_vs_on_plan_stream_id")
    remove_index :work_versions, :name => safe_name("idx_work_vs_on_plan_proj_id")

    add_column :works, :plan_project_id, :integer
    add_column :work_versions, :plan_project_id, :integer
    remove_column :work_versions, :project_id
    remove_column :works, :project_id
  end

  def self.safe_name(name)
    "#{ActiveRecord::Base.table_name_prefix}#{name}"
  end
end
