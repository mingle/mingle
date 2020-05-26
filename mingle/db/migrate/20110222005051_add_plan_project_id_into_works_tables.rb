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

class AddPlanProjectIdIntoWorksTables < ActiveRecord::Migration
  def self.up
    add_column :draft_works, :plan_project_id, :integer
    add_column :scheduled_works, :plan_project_id, :integer
    add_column :scheduled_work_versions, :plan_project_id, :integer

    execute "DELETE FROM #{safe_table_name("draft_works")}"
    execute "DELETE FROM #{safe_table_name("scheduled_works")}"
    execute "DELETE FROM #{safe_table_name("scheduled_work_versions")}"

    remove_column :draft_works, :project_id
    remove_column :scheduled_works, :project_id
    remove_column :scheduled_work_versions, :project_id
  end

  def self.down
    remove_column :scheduled_work_versions, :plan_project_id
    remove_column :scheduled_works, :plan_project_id
    remove_column :draft_works, :plan_project_id

    execute "DELETE FROM #{safe_table_name("draft_works")}"
    execute "DELETE FROM #{safe_table_name("scheduled_works")}"
    execute "DELETE FROM #{safe_table_name("scheduled_work_versions")}"

    add_column :draft_works, :project_id, :integer
    add_column :scheduled_works, :project_id, :integer
    add_column :scheduled_work_versions, :project_id, :integer
  end
end
