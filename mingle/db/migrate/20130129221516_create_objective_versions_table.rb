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

class CreateObjectiveVersionsTable < ActiveRecord::Migration
  def self.up
    add_column :objectives, :version, :integer
    add_column :objectives, :modified_by_user_id, :integer

    # We don't use acts_as_versioned's helper Objective.create_versioned_table because
    # project import and export creates namespaces tables that the helper does not support
    create_table "objective_versions", :force => true do |t|
      t.column "objective_id",        :integer
      t.column "version",             :integer
      t.column "plan_id",             :integer
      t.column "vertical_position",   :integer
      t.column "identifier",          :string
      t.column "value_statement",     :string
      t.column "size",                :integer, :default => 0
      t.column "value",               :integer, :default => 0
      t.column "name",                :string
      t.column "start_at",            :datetime
      t.column "end_at",              :datetime
      t.column "created_at",          :datetime
      t.column "updated_at",          :datetime
      t.column "modified_by_user_id", :integer
    end

    Objective.reset_column_information
  end

  def self.down
    remove_column :objectives, :modified_by_user_id
    remove_column :objectives, :version

    drop_table :objective_versions
    remove_column :objectives, :version
  end
end
