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

class SetNumericProjectVariablesToProjectPrecision < ActiveRecord::Migration
  class ProjectVariable20091021173849 < ActiveRecord::Base
    set_table_name "#{ActiveRecord::Base.table_name_prefix}project_variables"
    NUMERIC_DATA_TYPE = 'NumericType'
  end
  
  class Project20091021173849 < ActiveRecord::Base
    set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
    
    def card_table_name
      ActiveRecord::Base.connection.db_specific_table_name("#{identifier}_cards")
    end
    
    def execute(sql)
      ActiveRecord::Base.connection.execute(sql)
    end
    
    def update_project_variables
      execute <<-SQL
        UPDATE #{ProjectVariable20091021173849.quoted_table_name}
        SET value = #{connection.as_padded_number('value', self.precision)}
        WHERE #{connection.value_out_of_precision('value', self.precision)}
              AND data_type = #{connection.quote(ProjectVariable20091021173849::NUMERIC_DATA_TYPE)}
              AND project_id = #{self.id}
      SQL
    end
  end
  
  def self.up
    Project20091021173849.all.each { |project| project.update_project_variables }
  end
  
  def self.down
  end
end
