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

class CreateSearchableTermLists < ActiveRecord::Migration
  def self.up
    ActiveRecord::Base.connection.execute(%{ DELETE FROM #{safe_table_name('terms')} where term LIKE '%{%' or term LIKE '%}%' })
    
    create_table :searchable_term_lists do |t|
      t.column :project_id, :integer
      t.column :searchable_type, :string
      t.column :searchable_id, :integer
      t.column :terms, :text
    end
  end

  def self.down
    drop_table :searchable_term_lists
  end
end
