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

class MergeBacklogObjectiveToObjectiveTable < ActiveRecord::Migration
  class << self
    alias_method :c, :quote_column_name
    alias_method :t, :safe_table_name
    BACKLOG = "BACKLOG"
    PLANNED = "PLANNED"
    def up
      add_column :objective_versions, :position, :integer
      add_column :objective_versions, :status, :string, default: PLANNED
      add_column :objectives, :position, :integer
      add_column :objectives, :status, :string, default: PLANNED

      update_status('objectives')
      update_status('objective_versions')
      program_ids = select_values sanitize_sql("SELECT DISTINCT #{c('program_id')} FROM #{t('backlog_objectives')}")
      program_ids.each do |program_id|
        insert_backlog_objectives_to_objectives_for_program(program_id)
        insert_backlog_objective_to_versions_for_program(program_id)
      end
    end

    def down
      remove_column :objectives, :position
      remove_column :objective_versions, :position
      remove_column :objectives, :status
      remove_column :objective_versions, :status
    end

    private

    def update_status(table_name)
      execute(sanitize_sql("UPDATE #{t(table_name)} SET #{c('status')} = ?", PLANNED))
    end


    def insert_backlog_objectives_to_objectives_for_program(program_id)
      column_names = %w(name position size value value_statement program_id identifier number status version)
      insert_statement = make_insert_statement(column_names, 'objectives')
      max_objective_number = select_value(sanitize_sql("SELECT max(#{c('number')}) FROM #{t('objectives')} WHERE program_id = ?", program_id)) || 0
      last_number = insert_backlog_objectives_to_objectives(column_names, insert_statement, max_objective_number.to_i, program_id)

      sequence_name = "program_#{program_id}_objective_numbers"
      execute(sanitize_sql("UPDATE #{t('table_sequences')} SET last_value = ? WHERE name = ?", last_number, sequence_name))
    end

    def insert_backlog_objective_to_versions_for_program(program_id)
      column_names = %w(name position size value value_statement program_id number status identifier objective_id version)
      insert_statement = make_insert_statement(column_names, 'objective_versions')
      insert_backlog_objectives_to_objective_versions(column_names, insert_statement,program_id)
    end


    def insert_backlog_objectives_to_objective_versions(column_names, insert_statement, program_id)
      backlog_objectives = execute sanitize_sql("SELECT * FROM #{t('objectives')} WHERE #{c('program_id')} = ? and #{c('status')} = ? ORDER BY #{c('number')}", program_id, BACKLOG)
      backlog_objectives.each do |backlog_objective|
        values = column_names.map {|column_name| backlog_objective[column_name]}
        values[values.size-2]=backlog_objective['id']
        values[values.size-1]=1
        execute sanitize_sql(insert_statement, *(values))
      end
    end


    def insert_backlog_objectives_to_objectives(column_names, insert_statement, max_objective_number, program_id)
      backlog_objectives = execute sanitize_sql("SELECT * FROM #{t('backlog_objectives')} WHERE #{c('program_id')} = ? ORDER BY #{c('number')}", program_id)
      new_number = nil
      backlog_objectives.each do |backlog_objective|
        values = column_names.map {|column_name| backlog_objective[column_name]}
        new_number = max_objective_number + backlog_objective['number'].to_i
        name = values[0]
        values[values.size-4]= unique_identifier(name, 'objectives') # assign identifier
        values[values.size-3]=new_number # assign number
        values[values.size-2]='BACKLOG'  # assign status
        values[values.size-1]=1     # assign version
        execute sanitize_sql(insert_statement, *(values))
      end
      new_number
    end

    def unique_identifier(name, table_name)
      candidate = name.gsub(/[^a-zA-Z0-9]/, '_').downcase
      candidate.uniquify_with_succession(40) do |generated_id|
        results = execute(sanitize_sql("SELECT * FROM #{t(table_name)} WHERE #{c('identifier')} = '#{generated_id}'"))
        results.size > 0
      end
    end

    def make_insert_statement(column_names, table_name)
      quoted_column_names = column_names.map {|column_name| c(column_name)}.join(', ')
      values_placeholder = (['?'] * (column_names.length)).join(', ')
      <<-EOS
      INSERT INTO #{t(table_name)} (#{quoted_column_names}, #{c('id')})
      VALUES (#{values_placeholder}, #{ActiveRecord::Base.connection.next_id_sql(t(table_name))})
      EOS
    end
  end

end

