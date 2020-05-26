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

class AddDefaultObjPropValues < ActiveRecord::Migration
  class << self
    alias_method :c, :quote_column_name
    alias_method :t, :safe_table_name

    def up
      obj_prop_def_ids = execute sanitize_sql("SELECT #{c('id')} FROM #{t('obj_prop_defs')}")
      obj_prop_def_ids.each do |obj_prop_def_id_hash|
        obj_prop_def_id = obj_prop_def_id_hash['id']
        11.times do |value|
          value = value * 10
          execute sanitize_sql(
                      "INSERT INTO #{t('obj_prop_values')} (id, obj_prop_def_id, value, created_at, updated_at)
                            VALUES (#{ActiveRecord::Base.connection.next_id_sql("#{ActiveRecord::Base.table_name_prefix}obj_prop_values")} ,?, ?, ?, ?)",
                      obj_prop_def_id, value, Clock.now, Clock.now
                  )
        end

      end
    end

    def down
      execute sanitize_sql("DELETE FROM #{t('obj_prop_values')}")
    end
  end
end

