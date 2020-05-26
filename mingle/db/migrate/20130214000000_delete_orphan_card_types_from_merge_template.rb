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

class DeleteOrphanCardTypesFromMergeTemplate < ActiveRecord::Migration
  def self.up
    orphaned_card_type_scope = "FROM #{safe_table_name('card_types')} WHERE project_id IS NULL"
    execute "DELETE FROM #{safe_table_name('card_defaults')} WHERE card_type_id IN (SELECT id #{orphaned_card_type_scope})"
    execute "DELETE #{orphaned_card_type_scope}"
  end

  def self.down
    # n/a
  end
end
