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

class CreateObjectivePropertyDefinitionsAndObjectivePropertyMappings < ActiveRecord::Migration[5.0]
  class << self
    def up
      create_table :objective_property_definitions do |table|
        table.string :name, null: false
        table.references :program
        table.string :type
        table.timestamps
      end
      create_table :objective_property_mappings do |table|
        table.references :objective_property_definition
        table.references :objective_type
      end
      add_index(:objective_property_definitions, [:program_id, :name], :unique => true)
      add_index(:objective_property_mappings, [:objective_property_definition_id, :objective_type_id], :unique => true)
    end

    def down
      drop_table :objective_property_mappings
      drop_table :objective_property_definitions
    end
  end
end
