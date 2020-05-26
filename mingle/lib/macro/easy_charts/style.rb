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

module EasyCharts
  module Style
    module LegendPosition
      DEFAULT = 'right'
      ALL = %w(right bottom)
    end

    module LabelTypes
      DEFAULT = 'percentage'
      ALL = %w(percentage whole-number)
    end

    module Sizes
      DEFAULT_HEIGHT = 300
      DEFAULT_WIDTH = 440
      DEFAULT = 'medium'
      ALL = %w(small medium large)

      def for(chart_type)
        CHART_SIZES[CHART_CATEGORY[chart_type]]
      end

      def default_for(chart_type)
        CHART_SIZES[CHART_CATEGORY[chart_type]][DEFAULT]
      end

      def default_width_for(chart_type)
        default_for(chart_type)[:chart_width]
      end

      def default_height_for(chart_type)
        default_for(chart_type)[:chart_height]
      end

      module_function :for, :default_for, :default_width_for, :default_height_for

      private

      CHART_CATEGORY = {
          'pie-chart' => 'pie-chart',
          'ratio-bar-chart' => 'xy-chart',
          'stacked-bar-chart' => 'xy-chart',
          'data-series-chart' => 'xy-chart',
          'daily-history-chart' => 'xy-chart',
          'cumulative-flow-graph' => 'xy-chart',
      }

      CHART_SIZES = {
          'pie-chart' => {
              'small' => {:chart_width => 220, :chart_height => 150},
              'large' => {:chart_width => 880, :chart_height => 600},
              DEFAULT => {:chart_width => DEFAULT_WIDTH, :chart_height => DEFAULT_HEIGHT}
          },
          'xy-chart' => {
              'small' => {:chart_width => 300, :chart_height => 225},
              'large' => {:chart_width => 1200, :chart_height => 900},
              DEFAULT => {:chart_width => 600, :chart_height => 450}
          }
      }
    end
  end
end
