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
    class DailyHistoryChartRenderer < DataSeriesChartRenderer

      def initialize(chart_width, chart_height)
        super(chart_width, chart_height)
        @chart_options[:axis][:y][:padding][:bottom] = 0
      end

      def set_message(message)
        @chart_options[:message] = message
      end

      def set_zoom(value)
        @chart_options[:zoom] = {enabled: value}
      end

      def set_legend_style(label, style)
        @chart_options[:legends_style] ||= {}
        @chart_options[:legends_style][label] = {style: style}
      end


      def set_x_values(x_values, x_label, *series_labels)
        @chart_options[:data][:xs] ||= {}
        series_labels.each{|series_label| @chart_options[:data][:xs][series_label] = x_label}
        @chart_options[:data][:columns] ||= []
        @chart_options[:data][:columns] << [x_label] + x_values
      end


      def set_x_axis_labels(labels, _, label_font_angle, options)
        @chart_options[:axis][:x][:type] = options[:type]
        @chart_options[:axis][:x][:tick] = {rotate: label_font_angle, multiline: false, centered: true, format: options[:format]}
      end

      def set_forecasts_guide_line(forecast_value, color)
        set_guide_lines({value: forecast_value, color: color, class: 'dashed-guideline'}, :y)
      end

      def set_fix_date_guide_line(value, date)
        set_guide_lines({value: value, date: date, class: 'dashed-guideline'}, :x)
      end

      def set_data_labels(series_name, label)
        @chart_options[:custom_series_labels] ||= {}
        @chart_options[:custom_series_labels][series_name] = label
      end

      def add_line(data, color, label, hide_legend = false)
        super(data, color, label)
        hide_legend(label) if hide_legend
        self
      end

      def set_data_class(label, class_name)
        @chart_options[:data][:classes] ||= {}
        @chart_options[:data][:classes][label] = class_name
      end

      def hide_tooltip(*series)
        series.each do |series_name|
          @chart_options[:series_without_tooltip] ||=[]
          @chart_options[:series_without_tooltip] << series_name
        end
      end

      def enable_data_labels_on_selected_positions(series_name, *indexes)
        @chart_options[:custom_series_labels] ||= {}
        @chart_options[:custom_series_labels][series_name] = {positions: indexes}
      end

      def add_end_point_label(*_); end

      def add_legend_key(label, x_value, x_label)
        @chart_options[:data][:columns] << ([label] + [0])
        @chart_options[:data][:types][label] = 'line'
        @chart_options[:data][:colors][label]  = ColorPalette::Colors::TRANSPARENT
        set_x_values([x_value], x_label, label)
        set_data_class(label,'hidden-series-with-legend')
      end


      private
      ALL_AND_HIDDEN_SERIES_X_LABEL_REGEX = /\A_\$xFor\s*(?:All|\d+\.\d+)\z/

      def x_ticks_count
        x_label_columns = @chart_options[:data][:columns].select{|col| ALL_AND_HIDDEN_SERIES_X_LABEL_REGEX =~ col.first}
        x_label_columns.flatten.uniq.size - x_label_columns.size
      end

      def hide_legend(series_name)
        @chart_options[:legend][:hide] ||= []
        @chart_options[:legend][:hide] << series_name
      end

      def set_guide_lines(data, axis_type)
        @chart_options[:grid] ||= {}
        @chart_options[:grid][axis_type] ||= {}
        @chart_options[:grid][axis_type][:lines] ||= []
        grid_line_data = {value:(data[:value].is_a? Date) ? data[:value] : data[:value] }
        grid_line_data[:text] = data[:date] if data[:date]
        grid_line_data[:position] = 'start' if data[:date]
        grid_line_data[:color] = C3Renderers::ColorPalette.hex_color_string(data[:color]) if data[:color]
        grid_line_data[:class] = data[:class] if data[:class]
        grid_line_data
        @chart_options[:grid][axis_type][:lines] << grid_line_data
      end
    end
  end
end
