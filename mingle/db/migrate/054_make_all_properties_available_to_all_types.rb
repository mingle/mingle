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

class MakeAllPropertiesAvailableToAllTypes < ActiveRecord::Migration
  
  def self.up
    project_ids = ActiveRecord::Base.connection.select_all("SELECT id FROM #{safe_table_name('projects')}").map{|record| record['id']}
    project_ids.each do |project_id|
      card_type_ids = ActiveRecord::Base.connection.select_all("SELECT id FROM #{safe_table_name('card_types')} WHERE project_id = #{project_id}").map{|record| record['id']}
      property_definition_ids = ActiveRecord::Base.connection.select_all("SELECT id FROM #{safe_table_name('property_definitions')} WHERE project_id = #{project_id}").map{|record| record['id']}
      card_type_ids.each do |card_type_id|
        property_definition_ids.each do |property_definition_id|
          ActiveRecord::Base.connection.execute("INSERT INTO #{safe_table_name('card_types_property_definitions')} (card_type_id, property_definition_id) values(#{card_type_id}, #{property_definition_id})")
        end
      end
    end
  end

  def self.down
    ActiveRecord::Base.connection.execute("DELETE FROM #{card_types_property_definitions('card_types_property_definitions')}")
  end
end
