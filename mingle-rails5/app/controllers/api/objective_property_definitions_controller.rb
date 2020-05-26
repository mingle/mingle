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

module Api
  class ObjectivePropertyDefinitionsController < PlannerApplicationController

    privileges UserAccess::PrivilegeLevel::PROJECT_ADMIN => [:create]

    def create
      property_definition = @program.objective_property_definitions.create(params.require(:property).permit(:name, :description, :type))

      if property_definition.valid?
        render json: property_definition, only: [:name, :description, :type], status: :ok
      else
        render json: property_definition.errors.full_messages.join("\n"), status: :unprocessable_entity
      end
    end
  end
end
