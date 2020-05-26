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

class AddNumberSequenceToBacklogObjectives < ActiveRecord::Migration[5.0]
  class << self
    alias_method :c, :quote_column_name
    alias_method :t, :safe_table_name

    def up
      add_column :backlog_objectives, :number, :integer
      programs = select_all sanitize_sql("SELECT #{c('id')} FROM #{t('deliverables')} WHERE #{c('type')} = 'Program'")
      programs.each do |program|
        backlog_objectives = execute sanitize_sql(%Q{
        SELECT #{t('backlog_objectives')}.#{c('id')} FROM #{t('backlog_objectives')}
        JOIN #{t('backlogs')} ON #{t('backlog_objectives')}.#{c('backlog_id')} = #{t('backlogs')}.#{c('id')}
        JOIN #{t('deliverables')} ON #{t('deliverables')}.#{c('id')} = #{t('backlogs')}.#{c('program_id')}
        WHERE #{t('deliverables')}.#{c('id')} = '#{program['id']}'
        ORDER BY #{t('backlog_objectives')}.#{c('id')}})


        populate_values(backlog_objectives)

        create_number_sequence(program['id'], backlog_objectives.count)
      end
      add_index  :backlog_objectives, [:number, :backlog_id], unique: true, name: index_name
    end

    def down
      remove_index  :backlog_objectives, name: index_name
      remove_column :backlog_objectives, :number
      programs = select_all sanitize_sql("SELECT #{c('id')} FROM #{t('deliverables')} WHERE #{c('type')} = 'Program'")
      programs.each do |pgm|
        execute sanitize_sql("DELETE FROM #{t('table_sequences')} WHERE #{c('name')} = '#{sequence_name(pgm['id'])}'")
      end
    end

    def index_name
      "#{ActiveRecord::Base.table_name_prefix}backlog_number_unique"
    end

    def populate_values(backlog_objectives)
      backlog_objectives.each_with_index do |backlog_objective, index|
        execute sanitize_sql("UPDATE #{t('backlog_objectives')} SET #{c('number')} = '#{index + 1}' WHERE #{c('id')} = #{backlog_objective['id']}")
      end
    end

    def create_number_sequence(program_id, last_value)
      table_sequence = select_all sanitize_sql("SELECT id FROM #{t('table_sequences')} WHERE #{c('name')} = '#{sequence_name(program_id)}'")
      if table_sequence.count > 0
        execute sanitize_sql("UPDATE #{t('table_sequences')} SET #{t('last_value')} = '#{last_value}' WHERE #{c('name')} = '#{sequence_name(program_id)}'")
      else
        execute sanitize_sql("INSERT INTO #{t('table_sequences')} (name, last_value, id) VALUES ('#{sequence_name(program_id)}', '#{last_value}', #{ActiveRecord::Base.connection.next_id_sql('table_sequences')})")
      end
    end

    def sequence_name(program_id)
      "backlog_objectives_program_#{program_id}_numbers"
    end
  end
end
