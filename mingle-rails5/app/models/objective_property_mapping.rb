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

class ObjectivePropertyMapping < ApplicationRecord
  self.table_name = "obj_prop_mappings"
  belongs_to :objective_type
  belongs_to :objective_property_definition, foreign_key: 'obj_prop_def_id'

  class << self
    def create_property_mappings(properties, objective_type)
      ObjectivePropertyMapping.create(obj_prop_def_id: properties[:size].id, objective_type_id: objective_type.id)
      ObjectivePropertyMapping.create(obj_prop_def_id: properties[:value].id, objective_type_id: objective_type.id)
    end
  end
end
