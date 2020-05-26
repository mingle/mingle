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
    class SeriesChartRenderer < XYChartRenderer

      def initialize(chart_width, chart_height)
        super(chart_width, chart_height)
        @chart_options[:data].merge!(series_chart_options)
        @mode = type.to_sym
        @group = []
      end

      def add_line(data, color, label)
        add_series(label, data, color, :line)
        self
      end

      def add_trend_line(data, trend_color, trend_label)
        @chart_options[:data][:trends].push(trend_label)
        add_line(data, trend_color, trend_label)
      end

      def add_data_set(data, color, label)
        add_series(label, data, color, @mode)
      end

      def add_bars
        @mode = :bar
        self
      end

      def add_area_layer
        @mode = :area
        self
      end

      def make_chart
        @chart_options[:data][:groups] << @group
        super
      end


      define_compatibility_methods :add_legend, :set_line_width, :set_bar_gap

      private

      def add_series(label, data, color, series_type=nil)
        @current_series_label = label
        @chart_options[:data][:columns] << ([label] + data) unless data.empty?
        @chart_options[:data][:types][label] = series_type.to_s if series_type && series_type != type.to_sym
        set_series_color(color)
      end

      def set_series_color(color_options)
        color = color_options
        style = nil
        if Hash === color_options
          color = color_options[:color]
          style = color_options[:style].to_s
        end
        @chart_options[:data][:regions][@current_series_label] = [{style: style}] unless style.blank?
        @chart_options[:data][:colors][@current_series_label] = ColorPalette.hex_color_string(color) unless color.blank?
        hide_series if @chart_options[:data][:colors][@current_series_label] == ColorPalette::Colors::TRANSPARENT
      end

      def hide_series
        @chart_options[:legend][:hide] ||= []
        @chart_options[:legend][:hide] << @current_series_label
      end

      def series_chart_options
        {types: {},
         colors: {},
         groups: [],
         trends: [],
         regions: {}}
      end

    end
  end
end
