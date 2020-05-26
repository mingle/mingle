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

class Project20100914004239 < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"

  def card_version_table_name
    CardSchema.generate_card_versions_table_name(self.identifier)
  end
end

class FixMissingEvents < ActiveRecord::Migration
  
  def self.up
    return unless ActiveRecord::Base.table_name_prefix.starts_with?('mi_') #should only run for upgrades
    Project20100914004239.all.each do |project|
      insert_columns = ['type', 'origin_type', 'origin_id', 'created_at', 'created_by_user_id', 'project_id']      
      card_select_columns = [
          connection.quote('CardVersionEvent') + ' as type', 
          connection.quote('Card::Version') + ' as origin_type', 
          'cv.id AS origin_id',
          'cv.updated_at as created_at', 
          'cv.modified_by_user_id as created_by_user_id', 
          'cv.project_id as project_id']
          
      page_select_columns = [
          connection.quote('PageVersionEvent') + ' as type', 
          connection.quote('Page::Version') + ' as origin_type', 
          'pv.id as origin_id', 
          'pv.updated_at as created_at', 
          'pv.modified_by_user_id as created_by_user_id', 
          'pv.project_id as project_id']
          
      revision_select_columns = [
          connection.quote('RevisionEvent')  + ' as type',
          connection.quote('Revision') + ' as origin_type',
          'rv.id as origin_id',
          'rv.commit_time as created_at',
          'u.id as created_by_user_id',
          'rv.project_id as project_id']
      
      unified_select_columns = insert_columns.clone
      if connection.prefetch_primary_key?(Event)
        insert_columns.unshift('id')
        unified_select_columns.unshift(connection.next_id_sql(Event.table_name))
      end
      
      insert_events_sql = "INSERT INTO #{safe_table_name("events")} (#{insert_columns.join(',')})
                          SELECT #{unified_select_columns.join(', ')}
                          FROM (
                            SELECT *
                            FROM (
                              SELECT #{card_select_columns.join(',')}
                              FROM #{safe_table_name(project.card_version_table_name)} cv 
                              WHERE project_id = ? AND cv.id NOT IN (
                                SELECT origin_id 
                                FROM #{safe_table_name("events")} 
                                WHERE origin_type = ? AND project_id = ?
                              )
    
                              UNION ALL
    
                              SELECT #{page_select_columns.join(',')}
                              FROM #{safe_table_name('page_versions')} pv 
                              WHERE project_id = ? AND pv.id NOT IN (
                                SELECT origin_id 
                                FROM #{safe_table_name("events")} 
                                WHERE origin_type =? AND project_id = ?
                              )
    
                              UNION ALL
    
                              SELECT #{revision_select_columns.join(',')}
                              FROM #{safe_table_name('revisions')} rv
                              JOIN #{safe_table_name('projects')} p ON (rv.project_id = p.id)
                              LEFT OUTER JOIN #{safe_table_name('users')} u ON (rv.commit_user = u.version_control_user_name)
                              WHERE p.id = ? AND rv.id NOT IN (
                                SELECT origin_id
                                FROM #{safe_table_name("events")}
                                WHERE origin_type = ? AND project_id = ?
                              )
                            ) unordered
                            ORDER BY unordered.created_at, unordered.origin_id ASC 
                          ) ordered"
                            
      
      execute(SqlHelper.sanitize_sql(insert_events_sql, 
          project.id, 'Card::Version', project.id, 
          project.id, 'Page::Version', project.id,
          project.id, 'Revision', project.id))
    end
  end

  def self.down
  end
end
