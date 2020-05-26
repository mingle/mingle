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

module CardJson

  def card_snapshot
    return {:Number => number} if card.nil?
    data = {
      :Type => card_type.name,
      :Number => number,
      :Name => name,
      :"&rank" => (respond_to?(:rank) ? rank : card.rank).to_s("F"),
      :"&tags" => tags.map(&:name),
      :"&displayedUserProperties" => user_properties[0..2].map(&:name)
    }

    prop_defs_for_card_type.each do |definition|
      next if definition.aggregated?

      value = if definition.is_a?(UserPropertyDefinition)
        user = definition.value(self)
        user ? PushableNotificationEmitter::serialize_user(user) : nil
      else
        self[definition.column_name]
      end

      sort_position = definition.sort_position(self[definition.column_name])
      data[definition.name.to_sym] = [value, definition.data_type, sort_position]
    end

    data
  end

  def prop_defs_for_card_type
    card_type.property_type_mappings.map(&:property_definition)
  end

end
