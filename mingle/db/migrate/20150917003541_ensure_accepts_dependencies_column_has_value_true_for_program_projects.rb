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

class EnsureAcceptsDependenciesColumnHasValueTrueForProgramProjects < ActiveRecord::Migration
  def self.up
    sql = if connection.database_vendor == :oracle
            "UPDATE #{safe_table_name('program_projects')} set accepts_dependencies = 1 where accepts_dependencies IS NULL;"
          else
            "UPDATE #{safe_table_name('program_projects')} set accepts_dependencies = '1' where accepts_dependencies IS NULL;"
          end
    execute(sql)
  end

  def self.down
    sql = if connection.database_vendor == :oracle
            "UPDATE #{safe_table_name('program_projects')} set accepts_dependencies = NULL where accepts_dependencies = 1;"
          else
            "UPDATE #{safe_table_name('program_projects')} set accepts_dependencies = NULL where accepts_dependencies = '1';"
          end
    execute(sql)
  end
end
