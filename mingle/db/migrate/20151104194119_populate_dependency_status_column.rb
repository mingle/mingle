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

class PopulateDependencyStatusColumn < ActiveRecord::Migration

  class << self
    alias_method :c, :quote_column_name
    alias_method :t, :safe_table_name

    def up
      type = ActiveRecord::Base.connection.database_vendor
      sql = if type == :oracle
        %Q{
          MERGE INTO #{t("dependencies")} deps
               USING (#{status_sql}) stats
                  ON (deps.id = stats.id)
   WHEN MATCHED THEN
          UPDATE SET deps.status = stats.status
        }
      else
        %Q{
          UPDATE #{t("dependencies")} deps
             SET status = stats.status
            FROM (
              #{status_sql}
            ) stats
           WHERE stats.id = deps.id
        }
      end

      execute(sql)

      change_column_default :dependencies, :status, Dependency::NEW

      # unfortunately, change_column doesn't work with :null => false even as its own statement, at least in Postgres (didn't try in Oracle)
      execute(type == :oracle ? "ALTER TABLE #{t("dependencies")} MODIFY status VARCHAR2(255 CHAR) NOT NULL" : "ALTER TABLE #{t("dependencies")} ALTER COLUMN status SET NOT NULL")
      Dependency.reset_column_information
    end

    def down

      if :oracle == ActiveRecord::Base.connection.database_vendor
        execute("ALTER TABLE #{t("dependencies")} MODIFY status VARCHAR2(255 CHAR) NULL")
        change_column_default :dependencies, :status, nil
      else
        execute("ALTER TABLE #{t("dependencies")} ALTER COLUMN status DROP NOT NULL")
        execute("ALTER TABLE #{t("dependencies")} ALTER COLUMN status DROP DEFAULT") # this is broken in the Postgres JDBC adapter
      end

      Dependency.reset_column_information

      execute("UPDATE #{t("dependencies")} SET status = NULL")

    end

    def status_sql
      SqlHelper.sanitize_sql(%Q{

        SELECT id,
          CASE WHEN total_cards IS NULL THEN 'NEW'
               WHEN total_cards = completed_cards THEN 'RESOLVED'
               ELSE 'ACCEPTED'
           END AS status
          FROM (
            SELECT dep.id AS id, t1.num_cards AS total_cards, t2.num_done AS completed_cards
              FROM #{t("dependencies")} dep

         LEFT JOIN (SELECT d.id AS id, COUNT(drc.card_id) AS num_cards FROM #{t("dependencies")} d, #{t("dependency_resolving_cards")} drc WHERE d.id = drc.dependency_id GROUP BY d.id) t1
                ON dep.id = t1.id

         LEFT JOIN (SELECT d.id AS id, COUNT(drc.completed) AS num_done FROM #{t("dependencies")} d, #{t("dependency_resolving_cards")} drc WHERE d.id = drc.dependency_id AND drc.completed = ? GROUP BY d.id) t2
                ON dep.id = t2.id
          ) s1

      }, true)
    end
  end

end
