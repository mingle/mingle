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

class AddSizeValueStatementAndValueColumnsToObjective < ActiveRecord::Migration
  def self.up
    add_column :objectives, :value_statement, :string, :limit => 750, :default => nil
    add_column :objectives, :size, :integer, :default => 0
    add_column :objectives, :value, :integer, :default => 0
    Objective.reset_column_information
  end

  def self.down
    remove_column :objectives, :value_statement
    remove_column :objectives, :size
    remove_column :objectives, :value
  end
end
