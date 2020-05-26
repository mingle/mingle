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

    class Cell
      attr_reader :lane
      delegate :header_card, :to => :@property_value
      def initialize(lane, property_value, cards)
        @lane = lane
        @property_value = property_value
        @cards = cards
      end

      def header
        @property_value.abbreviated_grid_view_display_value
      end

      def cards
        @cards || []
      end

      def url_identifier
        @property_value.url_identifier
      end

      def db_identifier
        @property_value.db_identifier
      end

      def identifier
        @property_value.lane_identifier
      end

      def html_id
        [@lane.html_id, 'row', Digest::MD5::new.update(@property_value.db_identifier.to_s)].join('_')
      end
    end

  end

end
