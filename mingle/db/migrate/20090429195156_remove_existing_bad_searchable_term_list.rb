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

class RemoveExistingBadSearchableTermList < ActiveRecord::Migration
  class M20090429195156Project < ActiveRecord::Base
    set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
    
    def card_table_name
      RemoveExistingBadSearchableTermList.safe_table_name(self.identifier + '_cards')
    end
  end  
  
  def self.up
    select_values("SELECT DISTINCT project_id FROM #{searchable_terms_list_table}").each do |project_id|
      project = M20090429195156Project.find_by_id(project_id)
      if project
        execute <<-SQL
          DELETE FROM #{searchable_terms_list_table} 
          WHERE searchable_id NOT IN (SELECT id FROM #{project.card_table_name})
          AND searchable_type='Card'
          AND project_id=#{project.id}
        SQL
        execute <<-SQL
          DELETE FROM #{searchable_terms_list_table}
          WHERE searchable_id NOT IN (SELECT id FROM pages WHERE project_id=#{project.id})
          AND searchable_type='Page'
          AND project_id=#{project.id}
        SQL
        execute <<-SQL
          DELETE FROM #{searchable_terms_list_table}
          WHERE searchable_id NOT IN (SELECT id FROM revisions WHERE project_id=#{project.id})
          AND searchable_type='Revision'
          AND project_id=#{project.id}
        SQL
      elsif project_id
        execute(sanitize_sql("DELETE FROM #{searchable_terms_list_table} WHERE project_id = ?", project_id))
      else
        execute("DELETE FROM #{searchable_terms_list_table} WHERE project_id IS NULL")
      end
    end  
  end

  def self.searchable_terms_list_table
   safe_table_name("searchable_term_lists")
  end

  def self.down
  end
end
