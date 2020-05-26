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

class CleanupDependencyData < ActiveRecord::Migration[5.0]

  def self.up
    dependency_ids = select_values SqlHelper.sanitize_sql(%Q{
      SELECT DISTINCT(dependency_id)
        FROM #{DependencyResolvingCard.quoted_table_name}
       WHERE card_number is NULL
         AND dependency_type = 'Dependency'
    })

    sql = SqlHelper.sanitize_sql %Q{
      DELETE FROM #{DependencyResolvingCard.quoted_table_name}
            WHERE card_number is NULL
    }
    execute sql

    [Dependency, Dependency::Version].each do |model|
      execute SqlHelper.sanitize_sql(%Q{
        DELETE FROM #{model.quoted_table_name}
              WHERE raising_card_number is NULL
      })
    end

    dependency_ids.each do |id|
      dep = Dependency.find_by_id(id.to_i) # don't raise if dependency is missing
      dep.update_attribute(:status, dep.recalculate_status) if dep.present?
    end
  end

  def self.down
  end

end
