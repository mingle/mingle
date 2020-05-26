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

class ChangeObjectiveNameLengthTo80 < ActiveRecord::Migration
  def self.up
    backlog_objectives_table_name = ActiveRecord::Base.connection.safe_table_name('backlog_objectives')
    ActiveRecord::Base.connection.execute("update #{backlog_objectives_table_name} set name = substr(name, 1, 80)")

    change_column :backlog_objectives, :name, :string, :limit => 80
    change_column :objectives, :name, :string, :limit => 80

    Objective.reset_column_information
  end

  def self.down
    backlog_objectives_table_name = ActiveRecord::Base.connection.safe_table_name('backlog_objectives')
    objectives_table_name = ActiveRecord::Base.connection.safe_table_name('objectives')

    ActiveRecord::Base.connection.execute("update #{backlog_objectives_table_name} set name = substr(name, 1, 40)")
    ActiveRecord::Base.connection.execute("update #{objectives_table_name} set name = substr(name, 1, 40)")

    change_column :objectives, :name, :string, :limit => 40
    change_column :backlog_objectives, :name, :string, :limit => 40

    Objective.reset_column_information
  end
end
