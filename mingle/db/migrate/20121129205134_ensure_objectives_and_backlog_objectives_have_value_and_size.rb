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

class EnsureObjectivesAndBacklogObjectivesHaveValueAndSize < ActiveRecord::Migration
  def self.up
    ActiveRecord::Base.connection.execute(<<-SQL)
      UPDATE #{backlog_objectives}
         SET #{column("size")} = 0, #{column("value")} = 0
       WHERE #{column("size")} IS NULL
          OR #{column("value")} IS NULL
    SQL

    ActiveRecord::Base.connection.execute(<<-SQL)
      UPDATE #{objectives}
         SET #{column("size")} = 0, #{column("value")} = 0
       WHERE #{column("size")} IS NULL
          OR #{column("value")} IS NULL
    SQL

    change_column :backlog_objectives, column("size"), :integer, :default => 0, :null => false
    change_column :backlog_objectives, column("value"), :integer, :default => 0, :null => false

    change_column :objectives, column("size"), :integer, :default => 0, :null => false
    change_column :objectives, column("value"), :integer, :default => 0, :null => false

    Objective.reset_column_information
  end

  def self.down
    change_column :backlog_objectives, column("size"), :integer, :default => 0, :null => true
    change_column :backlog_objectives, column("value"), :integer, :default => 0, :null => true

    change_column :objectives, column("size"), :integer, :default => 0, :null => true
    change_column :objectives, column("value"), :integer, :default => 0, :null => true

    Objective.reset_column_information
  end

  def self.backlog_objectives
    ActiveRecord::Base.connection.safe_table_name("backlog_objectives")
  end

  def self.objectives
    ActiveRecord::Base.connection.safe_table_name("objectives")
  end

  def self.column(column_name)
    ActiveRecord::Base.connection.quote_column_name(column_name)
  end

end
