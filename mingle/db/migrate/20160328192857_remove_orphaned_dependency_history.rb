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

class RemoveOrphanedDependencyHistory < ActiveRecord::Migration
  def self.up

      clean_orphaned_dependency_events = %Q{
  DELETE FROM #{DependencyVersionEvent.quoted_table_name} E
    WHERE NOT EXISTS (SELECT 1 FROM #{Dependency::Version.quoted_table_name} DV
                       WHERE E.ORIGIN_ID = DV.ID AND E.ORIGIN_TYPE = 'Dependency::Version')
          AND E.TYPE = 'DependencyVersionEvent'
      }
      clean_changes_table_sql = %Q{
  DELETE FROM #{Change.quoted_table_name} ch
        WHERE NOT EXISTS (SELECT 1 FROM #{DependencyVersionEvent.quoted_table_name} ev WHERE ev.id = ch.event_id)
      }
      execute clean_orphaned_dependency_events
      execute clean_changes_table_sql
  end

  def self.down
  end
end
