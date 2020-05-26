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

class RemoveIdentifierAndNameFromPlan < ActiveRecord::Migration
  def self.up
    remove_column :plans, :identifier
    remove_column :plans, :name
    Plan.reset_column_information
  end

  def self.down
    add_column :plans, :identifier, :string
    add_column :plans, :name, :string
    Plan.reset_column_information
  end
end
