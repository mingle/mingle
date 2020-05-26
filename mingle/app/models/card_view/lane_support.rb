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

module CardView

  module LaneSupport
    def group_by_row_property(visible_values)
      row_property_definition = @group.row_property_definition
      return [UngroupedCell.new(self)] unless row_property_definition
      cards_group_by_row_property_value = self.cards.group_by do |card|
        # property_value#db_identifier is the key used to find related cards
        # and it is different with property_definition#db_identifier(card) which
        # is depend on property value type, and property_value#db_identifier
        # is always string type
        row_property_definition.property_value_on(card).db_identifier
      end


      visible_values.collect do |value|
        Cell.new(self, value, cards_group_by_row_property_value[value.db_identifier])
      end
    end

    def aggregate_value
      Aggregate.value(@project, @group.to_params, :column, cards)
    end
  end

end
