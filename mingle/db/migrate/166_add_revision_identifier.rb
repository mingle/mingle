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

class AddRevisionIdentifier < ActiveRecord::Migration
  def self.up
    add_column :revisions, :identifier, :string
    execute("UPDATE #{safe_table_name("revisions")} SET #{quote_column_name 'identifier'} = #{quote_column_name 'number'} WHERE #{quote_column_name 'identifier'} IS NULL")
    change_column :revisions, :identifier, :string, :nil => false
  end

  def self.down
    remove_column :revisions, :identifier
  end
end
