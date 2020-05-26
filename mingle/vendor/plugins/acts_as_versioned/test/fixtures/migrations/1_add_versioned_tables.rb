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

class AddVersionedTables < ActiveRecord::Migration
  def self.up
    create_table("things") do |t|
      t.column :title, :text
      t.column :price, :decimal, :precision => 7, :scale => 2
      t.column :type, :string
    end
    Thing.create_versioned_table
  end
  
  def self.down
    Thing.drop_versioned_table
    drop_table "things" rescue nil
  end
end
