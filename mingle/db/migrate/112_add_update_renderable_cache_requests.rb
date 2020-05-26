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

class AddUpdateRenderableCacheRequests < ActiveRecord::Migration
  def self.up
    create_table :update_renderable_cache_requests, :force => true do |t|
      t.column "project_id", :integer
      t.column "request_type", :string
      t.column "source", :string
    end    
    remove_column :projects, :last_cached_card_version_id
    Project.reset_column_information
  end

  def self.down
    drop_table :update_renderable_cache_requests
    add_column :projects, :last_cached_card_version_id, :integer
    Project.reset_column_information
  end
end
