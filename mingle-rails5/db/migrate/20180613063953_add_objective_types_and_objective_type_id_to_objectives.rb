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

class AddObjectiveTypesAndObjectiveTypeIdToObjectives < ActiveRecord::Migration[5.0]

  class << self
    alias_method :c, :quote_column_name
    alias_method :t, :safe_table_name

    def up
      create_table :objective_types do |t|
        t.references :program, :null => false
        t.text :value_statement
        t.string :name
        t.timestamps
      end
      add_column :objectives, :objective_type_id, :integer
      add_column :objective_versions, :objective_type_id, :integer
      create_default_objective_type
      Objective.reset_column_information
      Objective::Version.reset_column_information
    end

    def create_default_objective_type
      program_ids = select_values sanitize_sql("SELECT #{c('id')} FROM #{t('deliverables')} where #{c('type')} = 'Program'")
      program_ids.each do |program_id|
        execute sanitize_sql("INSERT INTO #{t('objective_types')} (id, name, program_id, value_statement, created_at, updated_at)
                              VALUES (#{ActiveRecord::Base.connection.next_id_sql('objective_types')} ,?, ?, ?, ?, ?)",
                              'Objective', program_id, default_value_statement, Clock.now, Clock.now)
        execute sanitize_sql("UPDATE #{t('objectives')} SET #{c('objective_type_id')} = (SELECT #{c('id')} FROM #{t('objective_types')} WHERE #{c('program_id')} = ?) WHERE #{c('program_id')} = ?", program_id, program_id)
        execute sanitize_sql("UPDATE #{t('objective_versions')} SET #{c('objective_type_id')} = (SELECT #{c('id')} FROM #{t('objective_types')} WHERE #{c('program_id')} = ?) WHERE #{c('program_id')} = ?", program_id, program_id)
      end
    end

    def default_value_statement
      '<h2>Context</h2>
<h3>Business Objective</h3>
<p><span style="color:#A9A9A9">Whose life are we changing?</span></p>
<p><span style="color:#A9A9A9">What problem are we solving?</span></p>
<p><span style="color:#A9A9A9">Why do we care about solving this?</span></p>
<p><span style="color:#A9A9A9">What is the successful outcome?</span></p>
<h3>Behaviours to Target</h3>
<p><span style="color:#A9A9A9">(Example: Customer signup for newsletter, submitting support tickets, etc)</span></p>'
    end

    def down
      drop_table :objective_types
      remove_column :objectives, :objective_type_id
      remove_column :objective_versions, :objective_type_id
    end
  end

end
