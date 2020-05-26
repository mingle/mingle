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
  module C3Renderers
    class CumulativeFlowGraphRenderer < StackedBarChartRenderer

      def initialize(chart_width, chart_height)
        super(chart_width, chart_height)
        @chart_options.merge!(chart_options)
        @chart_options[:data].merge!({labels: {format: {}}})
      end


      def dash_line_color(color)
        color = ColorPalette.hex_color_string(color) if Numeric === color
        {color: color, style: :dashed}
      end

      def set_data_symbol(symbol_type)
        return if symbol_type.blank? || symbol_type == 'none'
        @chart_options[:point][:symbols][@current_series_label] = symbol_type
      end

      def set_data_label_format
        @chart_options[:data][:labels][:format][@current_series_label] = true
      end

      private

      def chart_options
        {
            tooltip: {grouped: false},
            interaction: {enabled: true},
            legend: {position: 'top-right'},
            point: {show: false, symbols: {}, focus: {expand: {enabled: false}}}
        }
      end

      def type
        'area'
      end
    end

  end
end
