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
  class CardsGroup
    def initialize(cards, property_definition)
      @cards, @property_definition = cards, property_definition
    end
    def cards(property_value)
      @map ||= @cards.group_by {|c| key(@property_definition.db_identifier(c))}
      @map[key(property_value.db_identifier)] || []
    end

    private
    def key(db_identifier)
      db_identifier.to_s
    end
  end
end
