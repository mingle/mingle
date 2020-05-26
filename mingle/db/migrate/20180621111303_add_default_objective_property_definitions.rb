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

class AddDefaultObjectivePropertyDefinitions < ActiveRecord::Migration
  class << self
    alias_method :c, :quote_column_name
    alias_method :t, :safe_table_name
    def up
      program_ids = execute sanitize_sql("SELECT #{c('id')} FROM #{t('deliverables')} where #{c('type')} = 'Program'")
      program_ids.each do |program_id_hash|
        program_id = program_id_hash['id']
        execute sanitize_sql("INSERT INTO #{t('objective_property_definitions')} (id, name, program_id, type, created_at, updated_at)
                              VALUES (#{ActiveRecord::Base.connection.next_id_sql("#{ActiveRecord::Base.table_name_prefix}objective_property_definitions")} ,?, ?, ?, ?, ?)",
                             'size', program_id, 'ManagedNumber', Clock.now, Clock.now)
        execute sanitize_sql("INSERT INTO #{t('objective_property_definitions')} (id, name, program_id, type, created_at, updated_at)
                              VALUES (#{ActiveRecord::Base.connection.next_id_sql("#{ActiveRecord::Base.table_name_prefix}objective_property_definitions")} ,?, ?, ?, ?, ?)",
                             'value', program_id, 'ManagedNumber', Clock.now, Clock.now)

        size_id = execute(sanitize_sql("SELECT id FROM #{t('objective_property_definitions')} WHERE name = 'size' AND #{c('program_id')} = ?", program_id)).first['id']
        value_id = execute(sanitize_sql("SELECT id FROM #{t('objective_property_definitions')} WHERE name = 'value' AND #{c('program_id')} = ?", program_id)).first['id']
        objective_type_id = execute(sanitize_sql("SELECT id FROM #{t('objective_types')} WHERE name = 'Objective' AND #{c('program_id')} = ?", program_id)).first['id']

        execute sanitize_sql("INSERT INTO #{t('objective_property_mappings')} (id, #{c('objective_property_definition_id')}, objective_type_id)
                              VALUES (#{ActiveRecord::Base.connection.next_id_sql("#{ActiveRecord::Base.table_name_prefix}objective_property_mappings")}, ?, ?)", size_id, objective_type_id)

        execute sanitize_sql("INSERT INTO #{t('objective_property_mappings')} (id, #{c('objective_property_definition_id')}, objective_type_id)
                              VALUES (#{ActiveRecord::Base.connection.next_id_sql("#{ActiveRecord::Base.table_name_prefix}objective_property_mappings")}, ?, ?)", value_id, objective_type_id)


      end
    end

    def down
      execute sanitize_sql("DELETE FROM #{t('objective_property_mappings')}")
      execute sanitize_sql("DELETE FROM #{t('objective_property_definitions')}")
    end
  end
end
