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

class PostgresDropNotNullConstraintForProjectIdsOnDependencies < ActiveRecord::Migration[5.0]
  def self.up
    unless connection.database_vendor == :oracle
      execute "alter table #{safe_table_name('dependencies')} alter column #{quote_column_name('raising_project_id')} drop not null;"
      execute "alter table #{safe_table_name('dependency_versions')} alter column #{quote_column_name('raising_project_id')} drop not null;"
    end
  end

  def self.down
    unless connection.database_vendor == :oracle
      execute "alter table #{safe_table_name('dependencies')} alter column #{quote_column_name('raising_project_id')} set not null;"
      execute "alter table #{safe_table_name('dependency_versions')} alter column #{quote_column_name('raising_project_id')} set not null;"
    end
  end
end
