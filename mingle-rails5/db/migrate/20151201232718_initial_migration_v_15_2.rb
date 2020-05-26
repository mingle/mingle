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

class InitialMigrationV152 < ActiveRecord::Migration[5.0]
  def self.up
    structure_file_name = "#{ActiveRecord::Base.connection.database_vendor rescue 'oracle'}_structure.sql"
    structure_sql_file_relative_path = File.join("..", "rollup_v15_2_0", structure_file_name)
    structure_sql_file_absolute_path = File.expand_path(structure_sql_file_relative_path, File.dirname(__FILE__))
    queries = File.read(structure_sql_file_absolute_path, encoding: 'utf-8')
    puts "Total size of query is #{queries.length}"
    ActiveRecord::Base.transaction do
      queries.split(";\n").each do |query|
        execute query
      end
    end
  end

  def self.down
    #you wish!
  end
end
