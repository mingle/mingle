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

class AddUniqueIndexToLuauGroupFullName < ActiveRecord::Migration
  def self.up
    if ActiveRecord::Base.table_name_prefix.blank?
      add_index :luau_groups, :identifier, :unique => true, :name => 'idx_luau_groups_on_ident'
    end
  end

  def self.down
    if ActiveRecord::Base.table_name_prefix.blank?
      remove_index 'idx_luau_groups_on_ident'
    end
  end
end
