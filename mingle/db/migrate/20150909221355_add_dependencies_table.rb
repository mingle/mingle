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

class AddDependenciesTable < ActiveRecord::Migration
  def self.up
    create_table :dependencies do |t|
      t.string :name, :null => false
      t.text :description
      t.date :desired_end_date, :null => false
      t.integer :resolving_project_id
      t.integer :raising_project_id, :null => false
      t.integer :raising_card_id, :null => false
    end
  end

  def self.down
    drop_table :dependencies
  end
end
