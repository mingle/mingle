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

class FixNon255VarcharLimitsOnOracle < ActiveRecord::Migration
  def self.up
    if connection.database_vendor == :oracle
      change_column :objectives, :name, :string, :limit => '80 CHAR'
      change_column :backlog_objectives, :name, :string, :limit => '80 CHAR'
      change_column :backlog_objectives, :value_statement, :string, :limit => '750 CHAR'
      change_column :objective_versions, :value_statement, :string, :limit => '750 CHAR'
    end
  end

  def self.down
    if connection.database_vendor == :oracle
      change_column :objectives, :name, :string, :limit => '80 BYTE'
      change_column :backlog_objectives, :name, :string, :limit => '80 BYTE'
      change_column :backlog_objectives, :value_statement, :string, :limit => '750 BYTE'
      change_column :objective_versions, :value_statement, :string, :limit => '750 BYTE'
    end
  end
end
