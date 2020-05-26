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

class RecreateSearchableTermsList < ActiveRecord::Migration
  def self.up
    if ActiveRecord::Base.table_name_prefix.blank?
      # we removed the recreate search terms part of this migration
      add_index :terms, [:project_id, :searchable_type, :term], :name => 'idx_terms_on_p_id_type_term2'
    end
  end

  def self.down
    if ActiveRecord::Base.table_name_prefix.blank?
      remove_index :terms, :name => 'idx_terms_on_p_id_type_term2'
    end
  end
end
