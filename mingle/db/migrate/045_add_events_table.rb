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

class AddEventsTable < ActiveRecord::Migration
  def self.up
    create_table :events do |t|
      t.column :type, :string, :null => false
      t.column :origin_type, :string, :null => false
      t.column :origin_id, :integer, :null => false
      t.column :created_at, :datetime, :null => false
      t.column :created_by_user_id, :integer
      t.column "project_id", :integer, :null => false
    end
    add_index(:events, [:origin_type, :origin_id], :unique => true)
    add_index(:events, :created_by_user_id)
    
    drop_table :changes
    create_table "changes", :force => true do |t|
      t.column "event_id", :integer, :null => false
      t.column "type", :string, :default => "", :null => false
      t.column "old_value", :string
      t.column "new_value", :string
      t.column "attachment_id", :integer
      t.column "tag_id", :integer
      t.column "field", :string, :default => "", :null => false
    end
  end

  def self.down
    drop_table :changes
    create_table "changes", :force => true do |t|
      t.column "version_id",         :integer,                  :null => false
      t.column "version_type",       :string,   :default => "", :null => false
      t.column "type",               :string,   :default => "", :null => false
      t.column "old_value",          :string
      t.column "new_value",          :string
      t.column "attachment_id",      :integer
      t.column "tag_id",             :integer
      t.column "field",              :string,   :default => "", :null => false
      t.column "project_id",         :integer,                  :null => false
      t.column "created_at",         :datetime,                 :null => false
      t.column "created_by_user_id", :integer
    end
    drop_table :events
  end
end
