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

class AddRubyNameColumnToPropertyDefinitions < ActiveRecord::Migration
  def self.up
    add_column :property_definitions, :ruby_name, :string
    
    execute %{ UPDATE #{safe_table_name("property_definitions")}
               SET ruby_name = column_name
             }
    records = ActiveRecord::Base.connection.select_all("SELECT id, type, column_name FROM #{safe_table_name("property_definitions")} WHERE type in ('TreeRelationshipPropertyDefinition', 'CardRelationshipPropertyDefinition', 'UserPropertyDefinition')")
    records.each do |record|
      record['column_name'] =~ Regexp.new("(.+)_(card|user)_id$")
      execute %{ UPDATE #{safe_table_name("property_definitions")}
                 SET ruby_name = '#{$1}'
                 WHERE id = #{record['id']}
               }
    end
    
    change_column :property_definitions, :ruby_name, :string, :default => nil
  end
  
  def self.down
    drop_column :property_definitions, :ruby_name
  end
end
