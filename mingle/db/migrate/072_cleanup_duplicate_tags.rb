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

class CleanupDuplicateTags < ActiveRecord::Migration
  def self.up
    project_ids = ActiveRecord::Base.connection.select_values(%{
      SELECT id FROM #{safe_table_name('projects')}
    })
    project_ids.each do |project_id|
      tag_records = ActiveRecord::Base.connection.select_all(%{
        SELECT * FROM #{safe_table_name('tags')} WHERE project_id = #{project_id}
      })
      tag_ids_by_name = {}
      tag_records.each do |tag_record|
        existing_id_for_name = tag_ids_by_name[tag_record['name'].downcase]
        if existing_id_for_name
          ActiveRecord::Base.connection.execute(%{
            UPDATE #{safe_table_name('taggings')} SET tag_id = #{existing_id_for_name} WHERE tag_id = #{tag_record['id']}
          })
          ActiveRecord::Base.connection.execute(%{
            DELETE from #{safe_table_name('tags')} WHERE id = #{tag_record['id']}
          })
          
          # impossible to figure out whether the survivor should be marked deleted, so 
          # they will all by left visible
          ActiveRecord::Base.connection.execute(%{
            UPDATE #{safe_table_name('tags')} SET deleted_at = NULL WHERE id = #{existing_id_for_name}
          })
        else
          tag_ids_by_name[tag_record['name'].downcase] = tag_record['id']
        end
      end
    end
    
    add_index(:tags, [:name, :project_id], :unique => true,
      :name => "#{ActiveRecord::Base.table_name_prefix}unique_tag_names")
  end

  def self.down
    remove_index(:tags, :name => "#{ActiveRecord::Base.table_name_prefix}unique_tag_names")
  end
end
