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
    class StackedBarChartRenderer < SeriesChartRenderer

      def initialize(chart_width, chart_height)
        super(chart_width, chart_height)
        @chart_options.merge!(stack_bar_chart_options)
      end
      private

      def add_series(label, data, color, series_type = nil)
        super
        @group << label
      end

      def type
        'bar'
      end

      def stack_bar_chart_options
        {bar: {width: {ratio: 0.85}},
         tooltip: {grouped: false},
         legend: {position: 'top-right'}}
      end
    end
  end
end
