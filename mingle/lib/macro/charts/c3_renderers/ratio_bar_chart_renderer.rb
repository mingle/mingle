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
    class RatioBarChartRenderer < XYChartRenderer
      MIN_RATIO=0
      MAX_RATIO=100

      def initialize(chart_width, chart_height)
        super(chart_width, chart_height)
        @chart_options.merge!(ratio_bar_chart_options)
        @chart_options[:axis][:y][:padding] = {top: 5, bottom: 0}
        @chart_options[:axis][:y][:min] = MIN_RATIO
        @chart_options[:axis][:y][:max] = MAX_RATIO
        @chart_options[:axis][:y][:tick] = {format: ''}
      end

      def add_bars(data, color)
        color = ColorPalette.hex_color_string(color)
        @chart_options[:data][:columns] << data.unshift('data')
        @chart_options[:data][:colors] = {data: color}
      end

      private

      def type
        'bar'
      end

      def ratio_bar_chart_options
        {
            tooltip: {grouped: false},
            legend: {hide: true}
        }
      end

    end
  end
end
