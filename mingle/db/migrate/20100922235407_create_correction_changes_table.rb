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

class CreateCorrectionChangesTable < ActiveRecord::Migration
  def self.up
    create_table :correction_changes do |t|
      t.references :event
      t.string :old_value, :new_value
      t.string :type, :null => false
      t.integer :resource_1, :resource_2
    end
  end

  def self.down
    drop_table :correction_changes
  end
end
