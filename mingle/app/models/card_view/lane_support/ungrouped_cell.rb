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

    class UngroupedCell
      attr_reader :header, :cards, :lane
      def initialize(lane)
        @lane = lane
        @cards = lane.cards
      end

      def html_id
        @lane.html_id
      end

      def url_identifier;'';end
      def db_identifier;'';end
      def identifier;'';end
      def header_card(context);nil;end
    end

  end

end
