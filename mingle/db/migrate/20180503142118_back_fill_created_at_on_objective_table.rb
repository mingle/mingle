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

class BackFillCreatedAtOnObjectiveTable < ActiveRecord::Migration
  class << self
    def up
      insert_created_at_on_all_backlog_objective_updated_at_is_not_set

      update_created_at_to_updated_at_where_updated_at_is_set
    end

    private
    def update_created_at_to_updated_at_where_updated_at_is_set
      sql = sanitize_sql(%Q{
      UPDATE #{Objective.quoted_table_name}
          SET #{quote_column_name('created_at')} = #{quote_column_name('updated_at')}
          where #{quote_column_name('created_at')} IS ? AND #{quote_column_name('updated_at')} IS NOT ?
    }, nil, nil)
      execute(sql)
    end

    def insert_created_at_on_all_backlog_objective_updated_at_is_not_set
      sql = sanitize_sql(%Q{
      UPDATE #{Objective.quoted_table_name}
          SET #{quote_column_name('created_at')} = ?
          where #{quote_column_name('status')} = ? AND #{quote_column_name('created_at')} IS ? AND #{quote_column_name('updated_at')} IS ?
    }, Clock.now, Objective::BACKLOG, nil, nil)
      execute(sql)
    end
  end
end
