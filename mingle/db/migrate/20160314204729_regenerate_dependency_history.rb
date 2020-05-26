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

class RegenerateDependencyHistory < ActiveRecord::Migration
  class << self
    alias_method :c, :quote_column_name
    alias_method :t, :safe_table_name

    def up
      execute SqlHelper.sanitize_sql(%Q{
        DELETE FROM #{t("changes")}
              WHERE event_id IN (
                SELECT id
                  FROM #{t("events")}
                 WHERE type = ?
              )
      }, "DependencyVersionEvent")

      execute SqlHelper.sanitize_sql(%Q{
        UPDATE #{t("events")}
           SET history_generated = ?
         WHERE type = ?
      }, false, "DependencyVersionEvent")

      execute(SqlHelper.sanitize_sql(%Q{
        SELECT DISTINCT deliverable_id
          FROM #{t("events")}
         WHERE type = ?
           AND deliverable_type = ?
      }, "DependencyVersionEvent", "Project")).each do |entry|
        project_id = entry["deliverable_id"].to_i
        Project.find(project_id).with_active_project do |project|
          project.generate_changes
        end
      end

    end

    def down
    end
  end
end
