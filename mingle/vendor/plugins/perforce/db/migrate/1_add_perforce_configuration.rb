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

class AddPerforceConfiguration < ActiveRecord::Migration
  def self.up

    return if ActiveRecord::Base.connection.table_exists?("#{ActiveRecord::Base.table_name_prefix}perforce_configurations")

    create_table :perforce_configurations, :force => true do |t|
      t.column :project_id,      :integer
      t.column :username,        :string
      t.column :password,        :string
      t.column :port,            :string
      t.column :host,            :string
      t.column :repository_path, :text
      t.column :initialized,      :boolean
      t.column :card_revision_links_invalid, :boolean
      t.column :marked_for_deletion, :boolean, :default => false
    end
  end

  def self.down
    drop_table :perforce_configurations
  end
end
