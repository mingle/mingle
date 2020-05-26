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

class Work < ActiveRecord::Base
  
  module BulkOperations
    def bulk_delete
      conditions = (scope(:find) || {})[:conditions]
      with_exclusive_scope(:find => { :conditions => conditions}) { delete_all }
    end
    
    def bulk_update(attr_name, attr_value, conditions)
      bulk_updater_id = SecureRandomHelper.random_32_char_hex
      update_all(["#{attr_name} = ?, updated_at = ?, bulk_updater_id = ?", attr_value, Clock.now, bulk_updater_id], conditions)
    end
  end
  extend BulkOperations

  class BulkUpdater
    def initialize(project, card_id_criteria)
      @project = project
      @card_id_criteria = card_id_criteria
    end

    def insert(program_project, objective_id)
      created_at = Clock.now
      work_columns = %w(id name card_number completed plan_id project_id objective_id created_at updated_at bulk_updater_id)
      count = 0
      bulk_updater_id = SecureRandomHelper.random_32_char_hex
      done_status_query = DoneStatusQuery.for(program_project)

      cards_sql = <<-SQL
          SELECT #{work_next_seq_sql}, name, #{quote_column_name('number')}, 
                 #{done_status_query.done_value_select} AS completed,
                 ? AS plan_id, ? AS project_id, ? AS objective_id, ? as created_at, ? as updated_at, ? as bulk_updater_id
          FROM #{@project.cards_table} 
            #{done_status_query.join_sql}
          WHERE #{@project.cards_table}.id #{@card_id_criteria.to_sql}
      SQL

      sql_params = [program_project.program.plan.id, @project.id, objective_id, created_at, created_at, bulk_updater_id]
      count = connection.execute(SqlHelper.sanitize_sql(cards_sql, *sql_params)).count
      sql = [%{INSERT INTO works (#{work_columns.join(', ')}) 
         (#{cards_sql})},
        *sql_params
      ]
      ObjectiveSnapshotProcessor.enqueue(objective_id, @project.id)
      connection.execute(SqlHelper.sanitize_sql(*sql))
      count
    end

    def destroy_works
      Work.delete_all(works_condition)
    end

    def update_attribute(plan_id, attr_name, attr_value)
      quoted_attr_name = quote_column_name(attr_name)
      attr_cond = "(#{quoted_attr_name} <> ? OR #{quoted_attr_name} IS NULL)"
      conditions = ["plan_id = ? AND #{attr_cond} AND #{works_condition}", plan_id, attr_value]
      sanitized_sql = SqlHelper.sanitize_sql(*conditions)
      Work.bulk_update(attr_name, attr_value, sanitized_sql)
    end

    private

    def work_next_seq_sql
      connection.next_sequence_value_sql(Work.sequence_name)
    end

    def works_condition
      "project_id = #{@project.id} AND card_number IN (SELECT #{quote_column_name('number')} FROM #{@project.cards_table} WHERE id #{@card_id_criteria.to_sql})"
    end

    def quote_column_name(name)
      connection.quote_column_name(name)
    end
    def connection
      Work.connection
    end
  end

end
