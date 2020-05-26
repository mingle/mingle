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

class DeleteOrphanedSearchableTermLists < ActiveRecord::Migration
  def self.up
    return if ActiveRecord::Base.table_name_prefix.starts_with?('mi_')

    searchable_term_lists_table = safe_table_name("searchable_term_lists")
    invalid_project_ids_in_term_lists_table = select_values(<<-SQL 
                                                                   SELECT project_id FROM #{searchable_term_lists_table}
                                                                   LEFT OUTER JOIN #{safe_table_name("projects")} ON #{safe_table_name("projects")}.id = #{searchable_term_lists_table}.project_id
                                                                   WHERE #{safe_table_name("projects")}.id IS NULL
                                                               SQL
                                                           )
    if invalid_project_ids_in_term_lists_table.any?
      execute("DELETE FROM #{searchable_term_lists_table} WHERE project_id IN (#{invalid_project_ids_in_term_lists_table.uniq.compact.join(', ')})")
    end
  end
  
  def self.down
  end
end
