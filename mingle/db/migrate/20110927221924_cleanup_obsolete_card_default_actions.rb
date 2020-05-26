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

class CleanupObsoleteCardDefaultActions < ActiveRecord::Migration
  def self.up
    remove_obsolete_card_defaults_sql_template = <<-SQL
      DELETE FROM @transition_actions
       WHERE id IN (
        SELECT @transition_actions.id
          FROM @transition_actions
         INNER JOIN @card_defaults ON @card_defaults.id = @transition_actions.executor_id
         WHERE @transition_actions.executor_type = 'CardDefaults'
         %s
        SELECT @transition_actions.id
          FROM @transition_actions
         INNER JOIN @card_defaults ON @card_defaults.id = @transition_actions.executor_id
         INNER JOIN @card_types ON @card_types.id = @card_defaults.card_type_id
         INNER JOIN @property_type_mappings ON @property_type_mappings.card_type_id = @card_types.id
         INNER JOIN @property_definitions ON @property_definitions.id = @property_type_mappings.property_definition_id
                AND @property_definitions.id = @transition_actions.target_id
         WHERE @transition_actions.executor_type = 'CardDefaults'
        )
    SQL

    minus_keyword = postgresql? ? 'EXCEPT' : 'MINUS'
    remove_obsolete_card_defaults_sql = (remove_obsolete_card_defaults_sql_template % minus_keyword).gsub(/@([\w]+)/) { |table_name| safe_table_name($1) }
    execute(remove_obsolete_card_defaults_sql)
  end

  def self.down
  end
end
