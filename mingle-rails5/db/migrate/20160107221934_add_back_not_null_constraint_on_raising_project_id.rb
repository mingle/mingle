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

class AddBackNotNullConstraintOnRaisingProjectId < ActiveRecord::Migration[5.0]
  def self.up
    if connection.database_vendor == :oracle
      change_column :dependencies, :raising_project_id, :integer, :null => false
      change_column :dependency_versions, :raising_project_id, :integer, :null => false
    else
      execute "alter table #{safe_table_name('dependencies')} alter column #{quote_column_name('raising_project_id')} set not null;"
      execute "alter table #{safe_table_name('dependency_versions')} alter column #{quote_column_name('raising_project_id')} set not null;"
    end
    Dependency.reset_column_information
    Dependency::Version.reset_column_information
  end

  def self.down
    if connection.database_vendor == :oracle
      change_column :dependencies, :raising_project_id, :integer, :null => true
      change_column :dependency_versions, :raising_project_id, :integer, :null => true
    else
      execute "alter table #{safe_table_name('dependencies')} alter column #{quote_column_name('raising_project_id')} drop not null;"
      execute "alter table #{safe_table_name('dependency_versions')} alter column #{quote_column_name('raising_project_id')} drop not null;"
    end
    Dependency.reset_column_information
    Dependency::Version.reset_column_information
  end
end
