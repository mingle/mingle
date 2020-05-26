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

class MigrateObjPropValuesToObjPropValueMappingsTable < ActiveRecord::Migration
  class << self
    alias_method :c, :quote_column_name
    alias_method :t, :safe_table_name

    def up
      objectives = execute sanitize_sql("SELECT #{c('id')}, #{c('program_id')}, #{c('value')}, #{c('size')} FROM #{t('objectives')}")
      objectives.each do |objective|
        obj_value_prop_def_id = get_obj_prop_def_id(objective['program_id'], 'Value')
        obj_size_prop_def_id = get_obj_prop_def_id(objective['program_id'], 'Size')

        obj_value_prop_value_id = get_obj_prop_value_id(obj_value_prop_def_id, objective['value'])
        obj_size_prop_value_id = get_obj_prop_value_id(obj_size_prop_def_id, objective['size'])

        insert_into_obj_prop_value_mappings(obj_value_prop_value_id, objective['id'])
        insert_into_obj_prop_value_mappings(obj_size_prop_value_id, objective['id'])
      end
    end

    def down
        execute("DELETE FROM #{t('obj_prop_value_mappings')}")
    end

    private
    def get_obj_prop_value_id(obj_prop_def_id, obj_prop_value)
      execute(sanitize_sql("SELECT #{c('id')} FROM #{t('obj_prop_values')}
                                                  WHERE #{c('obj_prop_def_id')} = ? AND #{c('value')} = ?", obj_prop_def_id, obj_prop_value.to_s
              )).first['id']
    end

    def get_obj_prop_def_id(program_id, obj_prop_name)
      execute(sanitize_sql("SELECT #{c('id')} FROM #{t('obj_prop_defs')}
                          WHERE #{c('program_id')} = ? AND #{c('name')} = ?", program_id, obj_prop_name
              )).first['id']
    end

    def insert_into_obj_prop_value_mappings(obj_value_prop_value_id, objective_id)

      execute(sanitize_sql("INSERT INTO #{t('obj_prop_value_mappings')} (id, objective_id, obj_prop_value_id, created_at, updated_at)
                                    VALUES(#{ActiveRecord::Base.connection.next_id_sql("#{ActiveRecord::Base.table_name_prefix}obj_prop_value_mappings")} , ? , ? , ? , ? )",
                           objective_id, obj_value_prop_value_id, Clock.now, Clock.now))
    end
  end
end
