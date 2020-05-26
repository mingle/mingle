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

class AddNotNullConstraintToPropertyTypeMapping < ActiveRecord::Migration
   include SqlHelper
   
   class << self 
     def up
       fix_corrupt_property_type_mappings
       change_column :property_type_mappings, :position, :integer, :null => false
     end

     def down
       change_column :property_type_mappings, :position, :integer, :null => true
     end
   
    def property_type_mapping_table
      @property_type_mapping_table ||= ActiveRecord::Base.connection.safe_table_name('property_type_mappings')
    end


    def fix_corrupt_property_type_mappings
      sql = sanitize_sql("SELECT * FROM #{property_type_mapping_table} WHERE position IS NULL")
      corrupt_mappings = ActiveRecord::Base.connection.select_all(sql)

      mappings_to_delete = corrupt_mappings.select do |mapping|
        sql = sanitize_sql("SELECT * FROM #{property_type_mapping_table} WHERE property_definition_id = ? AND card_type_id= ? AND position IS NOT NULL", mapping["property_definition_id"], mapping["card_type_id"])
        duplicates = ActiveRecord::Base.connection.select_all(sql)
        duplicates.any?
      end

      mappings_to_add_indices = corrupt_mappings - mappings_to_delete
      add_index_to_mappings(mappings_to_add_indices)
      delete_mappings(mappings_to_delete)
    end

    def add_index_to_mappings(mappings)
      max_position = nil 
      mappings.each do |mapping|
        max_position ||= last_max_position(mapping)
        max_position += 1
        update_sql = sanitize_sql("UPDATE #{property_type_mapping_table} SET position = ? WHERE id= ?", max_position, mapping["id"])
        ActiveRecord::Base.connection.execute(update_sql)
      end
    end

    def delete_mappings(mappings)
      mappings.each do |mapping| 
        sql = sanitize_sql("DELETE FROM #{property_type_mapping_table} WHERE id = ?", mapping["id"])
        ActiveRecord::Base.connection.execute(sql)
      end  
    end

    def last_max_position(mapping)
      max_sql = sanitize_sql("SELECT max(position) FROM #{property_type_mapping_table} WHERE card_type_id = ?", mapping["card_type_id"])
      (ActiveRecord::Base.connection.select_value(max_sql) || 0).to_i
    end
     
  end
end
