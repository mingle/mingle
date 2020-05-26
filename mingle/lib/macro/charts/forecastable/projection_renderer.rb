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

module Charts
  module Forecastable
    class ProjectionRenderer
      BLUE = 0x0076BA
      NO_LEGEND = 2
      delegate :gap, :scope_projection_segment, :completion_projection_segment, :to => :@projection
      delegate :add_arbitrary_line, :dash_line_color, :add_label, :to => :@renderer
      def initialize(projection, renderer)
        @projection, @renderer = projection, renderer
      end

      def render(scope_color, completion_color)
        add_gap
        add_arbitrary_line(scope_projection_segment, dash_line_color(scope_color))
        add_arbitrary_line(completion_projection_segment, dash_line_color(completion_color))
      end

      def add_gap
        line_layer = add_arbitrary_line([gap[:start_point], gap[:end_point]], BLUE, "the gap", 2)
        line_layer.setLegendOrder(NO_LEGEND)

        add_label(gap[:label_position][0], gap[:label_position][1], gap[:label], Chart::HTML_COLORS["Black"])
      end
    end
  end
end
