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

class CleanAsynchableModels < ActiveRecord::Migration
  def self.up
    drop_table "card_imports"
    create_table "card_imports", :force => true do |t|
      t.column "project_id",         :integer,                                :null => false
      t.column "mapping",            :string,  :limit => safe_limit(4096)
      t.column "ignore",             :string,  :limit => safe_limit(4096)
      t.column "user_id",            :integer,                                :null => false

      t.column "status",             :string
      t.column "progress_message",   :string
      t.column "error_count",        :integer,                 :default => 0, :null => false
      t.column "warning_count",      :integer,                 :default => 0
      t.column "total",              :integer,                 :default => 1, :null => false
      t.column "completed",          :integer,                 :default => 0, :null => false
    end

    drop_table "project_imports"
    create_table "project_imports", :force => true do |t|
      t.column "project_id",          :integer
      t.column "project_name",        :string
      t.column "project_identifier",  :string
      t.column "directory",           :string
      t.column "created_at",          :date
      t.column "updated_at",          :date
      t.column "created_by_user_id",  :integer
      t.column "modified_by_user_id", :integer
      
      t.column "status",             :string
      t.column "progress_message",   :string
      t.column "error_count",        :integer,                 :default => 0, :null => false
      t.column "warning_count",      :integer,                 :default => 0
      t.column "total",              :integer,                 :default => 1, :null => false
      t.column "completed",          :integer,                 :default => 0, :null => false
    end

    drop_table "project_exports"
    create_table "project_exports", :force => true do |t|
      t.column "project_id",       :integer,                 :null => false
      t.column "template",         :boolean,                 :null => false
      t.column "filename",         :string,                  :limit => safe_limit(4096)

      t.column "status",             :string
      t.column "progress_message",   :string
      t.column "error_count",        :integer,                 :default => 0, :null => false
      t.column "warning_count",      :integer,                 :default => 0
      t.column "total",              :integer,                 :default => 1, :null => false
      t.column "completed",          :integer,                 :default => 0, :null => false
    end
  end

  def self.down
    drop_table "card_imports"
    create_table "card_imports", :force => true do |t|
      t.column "project_id",    :integer,                                :null => false
      t.column "size",          :integer,                 :default => 0, :null => false
      t.column "created_count", :integer,                 :default => 0, :null => false
      t.column "updated_count", :integer,                 :default => 0, :null => false
      t.column "error_count",   :integer,                 :default => 0, :null => false
      t.column "warning_count", :integer,                 :default => 0
      t.column "status",        :string
      t.column "mapping",       :string,  :limit => safe_limit(4096)
      t.column "ignore",        :string,  :limit => safe_limit(4096)
      t.column "user_id",       :integer,                                :null => false
    end
    
    drop_table "project_imports"
    create_table "project_imports", :force => true do |t|
      t.column "project_id",          :integer
      t.column "project_name",        :string
      t.column "project_identifier",  :string
      t.column "directory",           :string
      t.column "failed",              :boolean
      t.column "created_at",          :date
      t.column "updated_at",          :date
      t.column "created_by_user_id",  :integer
      t.column "modified_by_user_id", :integer
      t.column "total_tables",        :integer
      t.column "completed_tables",    :integer
      t.column "status_message",      :string
      t.column "processing_status",   :string
    end
    
    drop_table "project_exports"
    create_table "project_exports", :force => true do |t|
      t.column "project_id",       :integer,                 :null => false
      t.column "template",         :boolean,                 :null => false
      t.column "total_tables",     :integer
      t.column "completed_tables", :integer
      t.column "status_message",   :string
      t.column "completed",        :boolean
      t.column "failed",           :boolean
      t.column "filename",         :string,  :limit => safe_limit(4096)
      t.column "error_detail",     :string,  :limit => safe_limit(4096)
    end
  end
end
