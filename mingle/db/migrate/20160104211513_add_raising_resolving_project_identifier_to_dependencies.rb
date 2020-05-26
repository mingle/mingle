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

class AddRaisingResolvingProjectIdentifierToDependencies < ActiveRecord::Migration
  class << self
    alias_method :c, :quote_column_name
    alias_method :t, :safe_table_name

    def up
      add_column :dependencies, :raising_project_identifier, :string
      add_column :dependencies, :resolving_project_identifier, :string
      add_column :dependency_versions, :raising_project_identifier, :string
      add_column :dependency_versions, :resolving_project_identifier, :string

      each_project do |id, identifier|
       execute sanitize_sql("UPDATE #{safe_table_name('dependencies')} SET #{quote_column_name('raising_project_identifier')} = ? WHERE #{quote_column_name('raising_project_id')} = ?", identifier, id)

        execute sanitize_sql("UPDATE #{safe_table_name('dependencies')} SET #{quote_column_name('resolving_project_identifier')} = ? WHERE #{quote_column_name('resolving_project_id')} = ?", identifier, id)

       execute sanitize_sql("UPDATE #{safe_table_name('dependency_versions')} SET #{quote_column_name('raising_project_identifier')} = ? WHERE #{quote_column_name('raising_project_id')} = ?", identifier, id)

        execute sanitize_sql("UPDATE #{safe_table_name('dependency_versions')} SET #{quote_column_name('resolving_project_identifier')} = ? WHERE #{quote_column_name('resolving_project_id')} = ?", identifier, id)
      end
    end

    def down
      remove_column :dependencies, :raising_project_identifier
      remove_column :dependencies, :resolving_project_identifier
    end
  end
end
