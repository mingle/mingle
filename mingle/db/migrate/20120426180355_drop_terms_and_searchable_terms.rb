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

class DropTermsAndSearchableTerms < ActiveRecord::Migration
  def self.up
    [safe_table_name('terms'), safe_table_name('searchable_term_lists')].each do |table_name|
      ActiveRecord::Base.connection.indexes(table_name).each do |index|
        remove_index table_name, :name => index.name
      end
    end
    
    execute "TRUNCATE TABLE #{safe_table_name('terms')}"
    execute "TRUNCATE TABLE #{safe_table_name('searchable_term_lists')}"
    
    drop_table :terms
    drop_table :searchable_term_lists
  end

  def self.down
    create_table "terms", :force => true do |t|
      t.integer "project_id"
      t.integer "searchable_id"
      t.string  "searchable_type"
      t.string  "attribute_name"
      t.string  "term"
      t.integer "associated_id"
      t.string  "associated_type"
      t.integer "weight",          :default => 1, :null => false
    end
    
    create_table "searchable_term_lists", :force => true do |t|
      t.integer "project_id"
      t.string  "searchable_type"
      t.integer "searchable_id"
      t.text    "terms"
    end
    
    add_index :terms, :term, :name => "index_terms_on_term"
    add_index :terms, [:project_id, :searchable_type, :term], :name => 'idx_terms_on_p_id_type_term2'
    add_index :terms, [:project_id, :searchable_type, :searchable_id], :name => 'idx_terms_on_pid_stype_sid'
    
    add_index :searchable_term_lists, [:project_id, :searchable_id, :searchable_type], :name => 'idx_stl_on_search_id_and_type'
    
  end
end
