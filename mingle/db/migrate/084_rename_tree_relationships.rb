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

class RenameTreeRelationships < ActiveRecord::Migration
  def self.up
    execute("UPDATE #{safe_table_name('property_definitions')} SET type = 'ContainmentRelationship' where type = 'TreeRelationship'")
    remove_column :property_definitions, :child_type_id
    PropertyDefinition.reset_column_information
  end

  def self.down
    execute("UPDATE #{safe_table_name('property_definitions')} SET type = 'TreeRelationship' where type = 'ContainmentRelationship'")
    add_column :property_definitions, :child_type_id, :integer
    PropertyDefinition.reset_column_information    
  end
end
