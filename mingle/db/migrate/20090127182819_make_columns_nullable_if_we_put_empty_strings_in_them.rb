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

# we sometimes put empty strings into non-nullable columns, but Oracle treats those as nulls, and a SQL exception occurs
class MakeColumnsNullableIfWePutEmptyStringsInThem < ActiveRecord::Migration
  def self.up
    change_column :revisions, :commit_user, :string, :null => true
    change_column :changes, :field, :string, :default => "", :null => true
  end

  def self.down
  end
end
