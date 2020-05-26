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

class ActiveRecord::Base
  class << self
    def all_columns_except(*excluded_columns)
      (self.columns.collect(&:name) - excluded_columns.collect(&:to_s)).collect{|c| "#{quoted_table_name}.#{self.connection.quote_column_name(c)}"}
    end
  end
end

Project
class Project
  def self.select_by_dependencies_sql(ids)
    %Q{
      SELECT #{quoted_table_name}.*
        FROM #{quoted_table_name}
       WHERE id IN (#{ids})
    }
  end
end

User
class User
  def self.select_by_dependencies_sql(ids)
    # can't alias the main table because this query will be wrapped in pagination clause
    %Q{
      SELECT #{quoted_table_name}.*
        FROM #{quoted_table_name}
       WHERE EXISTS (
               SELECT 1
                 FROM (
                        SELECT dv.raising_user_id user_id
                          FROM #{Dependency::Version.quoted_table_name} dv
                         WHERE dv.raising_project_id IN (#{ids})
                           AND dv.resolving_project_id IN (#{ids})

                        UNION ALL

                        SELECT d.raising_user_id user_id
                          FROM #{Dependency.quoted_table_name} d
                         WHERE d.raising_project_id IN (#{ids})
                           AND d.resolving_project_id IN (#{ids})

                      ) du
                WHERE du.user_id = #{quoted_table_name}.id
             )
    }
  end
end

Dependency
class Dependency
  def self.select_by_dependencies_sql(ids)
    %Q{
      SELECT #{quoted_table_name}.*
        FROM #{quoted_table_name}
       WHERE raising_project_id IN (#{ids})
       AND resolving_project_id IN (#{ids})
    }
  end
end

Dependency::Version
class Dependency::Version
  def self.select_by_dependencies_sql(ids)
    %Q{
      SELECT #{quoted_table_name}.*
        FROM #{quoted_table_name}
       WHERE raising_project_id IN (#{ids})
       AND resolving_project_id IN (#{ids})
    }
  end
end

DependencyResolvingCard
class DependencyResolvingCard
  def self.select_by_dependencies_sql(ids)
    %Q{
      SELECT #{quoted_table_name}.*
        FROM #{quoted_table_name}
       LEFT JOIN #{Dependency.quoted_table_name} ON (#{Dependency.quoted_table_name}.id = #{quoted_table_name}.dependency_id AND dependency_type = 'Dependency')
       LEFT JOIN #{Dependency::Version.quoted_table_name} ON (#{Dependency::Version.quoted_table_name}.id = #{quoted_table_name}.dependency_id AND dependency_type = 'Dependency::Version')
       WHERE
        (
          #{Dependency::Version.quoted_table_name}.raising_project_id IN (#{ids})
          AND #{Dependency::Version.quoted_table_name}.resolving_project_id IN (#{ids})
        )
        OR
        (
          (#{Dependency.quoted_table_name}.raising_project_id IN (#{ids})
          AND #{Dependency.quoted_table_name}.resolving_project_id IN (#{ids}))
        )
    }
  end
end

Event
class Event < ActiveRecord::Base
  def self.select_by_dependencies_sql(ids)
    %Q{
      SELECT #{export_columns.join(',')}
        FROM #{self.quoted_table_name}
        JOIN #{Dependency::Version.quoted_table_name} dv
          ON #{quoted_table_name}.origin_id = dv.id
       WHERE #{quoted_table_name}.origin_type = 'Dependency::Version'
         AND #{quoted_table_name}.deliverable_id IN (#{ids})
         AND dv.raising_project_id IN (#{ids})
         AND dv.resolving_project_id IN (#{ids})
    }
  end

  private

  def self.export_columns
    all_columns_except('history_generated') + [ "#{connection.quote(false)} as history_generated", 'mingle_timestamp']
  end
end

Attaching # force loading the class from the normal "models" directory
class Attaching < ActiveRecord::Base
  def self.select_by_dependencies_sql(ids)
    %Q{
      SELECT #{Attaching.quoted_table_name}.*
      FROM #{Attaching.quoted_table_name}
      JOIN #{Attachment.quoted_table_name} ON #{Attachment.quoted_table_name}.id = #{Attaching.quoted_table_name}.attachment_id
      LEFT JOIN #{Dependency.quoted_table_name} ON #{Attaching.quoted_table_name}.attachable_id = #{Dependency.quoted_table_name}.id
      LEFT JOIN #{Dependency::Version.quoted_table_name} ON #{Attaching.quoted_table_name}.attachable_id = #{Dependency::Version.quoted_table_name}.id
      WHERE #{Attachment.quoted_table_name}.project_id in (#{ids})
      AND (
        (
          #{Dependency::Version.quoted_table_name}.raising_project_id IN (#{ids})
          AND #{Dependency::Version.quoted_table_name}.resolving_project_id IN (#{ids})
          AND #{Attaching.quoted_table_name}.attachable_type = 'Dependency::Version'
        )
      OR
        (
          #{Dependency.quoted_table_name}.raising_project_id IN (#{ids})
          AND #{Dependency.quoted_table_name}.resolving_project_id IN (#{ids})
          AND #{Attaching.quoted_table_name}.attachable_type = 'Dependency'
        )
      )
    }
  end
end

Attachment
class Attachment < ActiveRecord::Base
  def self.select_by_dependencies_sql(ids)
    %Q{
      SELECT #{Attachment.quoted_table_name}.*
      FROM #{Attachment.quoted_table_name}
      WHERE 0 < (SELECT COUNT(*)
                 FROM #{Attaching.quoted_table_name}
                 LEFT JOIN #{Dependency.quoted_table_name} ON #{Attaching.quoted_table_name}.attachable_id = #{Dependency.quoted_table_name}.id
                 LEFT JOIN #{Dependency::Version.quoted_table_name} ON #{Attaching.quoted_table_name}.attachable_id = #{Dependency::Version.quoted_table_name}.id
                 WHERE
                  #{Attaching.quoted_table_name}.attachment_id = #{Attachment.quoted_table_name}.id
                  AND (
                    (
                      #{Dependency::Version.quoted_table_name}.raising_project_id IN (#{ids})
                      AND #{Dependency::Version.quoted_table_name}.resolving_project_id IN (#{ids})
                      AND #{Attaching.quoted_table_name}.attachable_type = 'Dependency::Version'
                    )
                  OR
                    (
                      (#{Dependency.quoted_table_name}.raising_project_id IN (#{ids})
                      AND #{Dependency.quoted_table_name}.resolving_project_id IN (#{ids}))
                      AND #{Attaching.quoted_table_name}.attachable_type = 'Dependency'
                    )
                  )
                ) AND
            #{Attachment.quoted_table_name}.project_id IN (#{ids})
    }
  end
end
