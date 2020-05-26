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

class AddDependencyVersionsTable < ActiveRecord::Migration
  def self.up
    create_table :dependency_versions do |t|
      t.integer  :dependency_id, :null => false
      t.integer  :version, :null => false
      t.string   :name, :null => false
      t.text     :description
      t.date     :desired_end_date, :null => false
      t.integer  :resolving_project_id
      t.integer  :raising_project_id, :null => false
      t.integer  :raising_card_id, :null => false
      t.integer  :number, :null => false
      t.datetime :created_at
      t.datetime :updated_at
      t.integer  :raising_user_id
      t.string   :status, :null => false
    end
    add_index :dependency_versions, :dependency_id

    add_column :dependencies, :version, :integer
  end

  def self.down
    drop_table :dependency_versions
    remove_column :dependencies, :version
    remove_index :dependency_versions, :dependency_id
  end
end
