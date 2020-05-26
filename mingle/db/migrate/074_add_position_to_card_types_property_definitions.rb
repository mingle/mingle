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

class AddPositionToCardTypesPropertyDefinitions <ActiveRecord::Migration
  def self.up
    create_table "property_type_mapping_tmp" do |t|
      t.column "card_type_id",            :integer, :null => false
      t.column "property_definition_id",  :integer, :null => false
      t.column "position",                :integer
    end
    renew_card_types_property_definitions("card_types_property_definitions", "property_type_mapping_tmp")
          
    drop_table "card_types_property_definitions"
    create_table "card_types_property_definitions" do |t|
      t.column "card_type_id",            :integer, :null => false
      t.column "property_definition_id",  :integer, :null => false
      t.column "position",                :integer
    end
    renew_card_types_property_definitions("property_type_mapping_tmp", "card_types_property_definitions")
    
    drop_table "property_type_mapping_tmp"
    
    unless ActiveRecord::Base.table_name_prefix =~ Project::INTERNAL_TABLE_PREFIX_PATTERN
      add_index "card_types_property_definitions", ["card_type_id"], :name => "index_card_types_property_definitions_on_card_type_id"
      add_index "card_types_property_definitions", ["property_definition_id"], :name => "index_card_types_property_definitions_on_property_definition_id"
    end
  end
 
  def self.down
    rename_table "card_types_property_definitions", "card_types_property_definitions_tmp"

    create_table "card_types_property_definitions", :id => false, :force => true do |t|
      t.column "card_type_id",            :integer, :null => false
      t.column "property_definition_id",  :integer, :null => false
    end
    renew_card_types_property_definitions("card_types_property_definitions_tmp", "card_types_property_definitions")

    drop_table "card_types_property_definitions_tmp"
  end
  
  def self.renew_card_types_property_definitions(from_table, to_table)
    from_table = safe_table_name(from_table)
    to_table = safe_table_name(to_table)
    
    insert_columns = ['card_type_id', 'property_definition_id']
    select_columns = ["#{from_table}.card_type_id as card_type_id", "#{from_table}.property_definition_id as property_definition_id"]
    if prefetch_primary_key?
      insert_columns.unshift('id')
      select_columns.unshift(next_id_sql(to_table))
    end
    execute "insert into #{to_table} (#{insert_columns.join(", ")}) (select #{select_columns.join(", ")} from #{from_table})"
  end
end
