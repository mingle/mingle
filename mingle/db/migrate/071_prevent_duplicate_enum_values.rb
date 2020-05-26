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

class PreventDuplicateEnumValues < ActiveRecord::Migration
  def self.up
    enum_value_records = ActiveRecord::Base.connection.select_all("SELECT * FROM #{safe_table_name('enumeration_values')}")
    values_by_property_defintion = {}
    duplicates = []
    enum_value_records.each do |record|
      prop_def_id = record['property_definition_id']
      value = record['value'].downcase
      values = (values_by_property_defintion[prop_def_id] ||= [])

      if values.include?(value)
        duplicates << record['id']
      else
        values << value
      end
    end
    
    duplicates.each do |id|
      ActiveRecord::Base.connection.execute("DELETE FROM #{safe_table_name('enumeration_values')} WHERE id = #{id}")
    end
    
    add_index(:enumeration_values, [:value, :property_definition_id], :name => "#{ActiveRecord::Base.table_name_prefix}unique_enumeration_values", :unique => true)
  end

  def self.down
    remove_index(:enumeration_values, :name => "#{ActiveRecord::Base.table_name_prefix}unique_enumeration_values")
  end
end
