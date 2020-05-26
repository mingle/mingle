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

class ChangePlvsToBeAssociatedWithPropertyDefinitionsThroughBindings < ActiveRecord::Migration
  def self.up
    create_table :variable_bindings do |t|
      t.column "project_variable_id",          :integer, :null => false
      t.column "property_definition_id",       :integer, :null => false
    end
    
    insert_columns = ['project_variable_id', 'property_definition_id']
    select_columns = ["property_definition_id", "property_definition_id"]
    if prefetch_primary_key?
      insert_columns.unshift('id')
      select_columns.unshift(next_id_sql(:variable_bindings))
    end
    execute "insert into #{safe_table_name('variable_bindings')} (#{insert_columns.join(", ")}) (select #{select_columns.join(", ")} from #{safe_table_name('project_variables_property_definitions')})"
    
    drop_table :project_variables_property_definitions
  end

  def self.down
  end
end
