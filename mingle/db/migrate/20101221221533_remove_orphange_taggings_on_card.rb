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

class RemoveOrphangeTaggingsOnCard < ActiveRecord::Migration
  
  class M20101221221533Project < ActiveRecord::Base
    set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"

    def card_table_name
      ActiveRecord::Base.connection.db_specific_table_name("#{identifier}_cards")
    end
  end
  
  def self.up
    tagging_table_name = safe_table_name('taggings')
    M20101221221533Project.all.each do |project|
      project.connection.execute(<<-SQL)
        DELETE
        FROM #{tagging_table_name} 
        WHERE #{tagging_table_name}.tag_id IN (SELECT id FROM #{safe_table_name('tags')} WHERE project_id=#{project.id})
        AND #{tagging_table_name}.taggable_type = 'Card'
        AND #{tagging_table_name}.taggable_id NOT IN (SELECT id FROM #{safe_table_name(project.card_table_name)})
      SQL
    end
  end

  def self.down
  end
end
