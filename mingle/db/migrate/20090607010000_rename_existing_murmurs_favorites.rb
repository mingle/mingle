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

class RenameExistingMurmursFavorites < ActiveRecord::Migration
  
  class M2009067010000Project < ActiveRecord::Base
    set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
  end
  
  class << self
    def murmurs_view_id_in(project)
      connection.select_one(<<-SQL
        SELECT id
        FROM #{safe_table_name('card_list_views')}
        WHERE project_id = #{project.id}
        AND name = 'Murmurs'
      SQL
      )
    end
    
    def murmurs_view_names(project)
      connection.select_values(<<-SQL
        SELECT name
        FROM #{safe_table_name('card_list_views')}
        WHERE name like 'Murmurs%'
        AND name <> 'Murmurs'
        AND project_id = #{project.id}
      SQL
      )
    end
    
    def update_murmurs_view_name(target_name, murmurs_view_id)
      connection.execute(<<-SQL
        UPDATE #{safe_table_name('card_list_views')} 
        SET name = '#{target_name}'
        WHERE id = #{murmurs_view_id['id']}
      SQL
      )
    end
  end
  
  def self.up
    connection = ActiveRecord::Base.connection
    projects = M2009067010000Project.all(:conditions => ['template = ?', false]).each do |project|
      murmurs_view_id = murmurs_view_id_in(project)
      
      if murmurs_view_id
        view_names =  murmurs_view_names(project)
        target_name = view_names.any? ? view_names.max.succ : 'Murmurs_1'
        update_murmurs_view_name target_name, murmurs_view_id
      end
    end
  end
  
  def self.down
  end
end
