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

class Project
  module MyWorkProjectSupport

    def ownership_properties
      Cache.get(KeySegments::UserOwnershipProperties.new(self).to_s) do
        user_property_definitions_with_hidden.reject(&:hidden?).map(&:name)
      end
    end

    def card_type_colors
      Cache.get(KeySegments::ProjectCardTypeColors.new(self).to_s) do
        card_types.inject({}) { |r, ct| r[ct.name] = (ct.color || "transparent"); r }
      end
    end

  end
end
