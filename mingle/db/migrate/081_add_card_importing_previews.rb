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

class AddCardImportingPreviews < ActiveRecord::Migration
  def self.up
    create_table "card_importing_previews", :force => true do |t|
      t.column "project_id",         :integer,                                :null => false
      t.column "mapping",            :string,  :limit => safe_limit(4096)
      t.column "status",             :string
      t.column "progress_message",   :string
      t.column "error_count",        :integer,                 :default => 0, :null => false
      t.column "total",              :integer,                 :default => 1, :null => false
      t.column "completed",          :integer,                 :default => 0, :null => false
    end
  end

  def self.down
    drop_table "card_importing_previews"
  end
end
