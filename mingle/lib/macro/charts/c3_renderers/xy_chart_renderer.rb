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
    class XYChartRenderer < BaseRenderer

      LEGEND_POSITION_TRANLATIONS={
          'right' => 'top-right'
      }

      def initialize(chart_width, chart_height)
        super(chart_width, chart_height)
        @chart_options[:axis] = {x: {type: 'category'}, y: {padding: {top: 25}}}
        @step = 1
      end

      def add_titles_to_axes(x_axis_title, y_axis_title)
        @chart_options[:axis][:x][:label] =  { text: x_axis_title, position: 'outer-center'}
        @chart_options[:axis][:y][:label] =  { text: y_axis_title, position: 'outer-middle'}
      end

      def set_x_axis_labels(labels, _, label_font_angle)
        @chart_options[:axis][:x][:categories] = labels
        @chart_options[:axis][:x][:tick] = {rotate: label_font_angle, multiline: false, centered: true}
      end

      def set_x_axis_label_step(step)
        @step = step
      end

      def show_guide_lines
        @chart_options[:grid] ||= {}
        @chart_options[:grid][:y] ||= {}
        @chart_options[:grid][:y][:show] = true

        @chart_options[:grid][:x] ||= {}
        @chart_options[:grid][:x][:show] = false
      end

      def make_chart
        tick_options(:x)[:culling] = {max: max_culling} if (@step > 1 && @chart_options[:data][:columns] && @chart_options[:data][:columns].size > 0)
        super
      end

      def set_legend_position(position)
        @chart_options[:legend][:position] = LEGEND_POSITION_TRANLATIONS[position.to_s] || position
      end

      define_compatibility_methods :set_axes_colors, :set_border_color, :set_3d, :transparent_color

      private

      def tick_options(axis)
        @chart_options[:axis][axis][:tick] ||= {}
      end

      def max_culling
        (x_ticks_count.to_f/@step).ceil
      end

      def x_ticks_count
        @chart_options[:data][:columns].first.size - 1
      end
    end
  end
end
