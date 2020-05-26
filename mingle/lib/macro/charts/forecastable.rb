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

require 'macro/charts/forecastable/projection'
require 'macro/charts/forecastable/projection_renderer'
require 'macro/charts/forecastable/line'

module Charts
  module Forecastable
    FORECAST_POINT_COLOR = Chart::HTML_COLORS["DarkGray"]
    FORECAST_FOR_NO_SCOPE_CHANGE = 'Forecast For No Scope Change'
    FORECAST_FOR_50_PERCENT_INCREASE_IN_COPE = 'Forecast For 50% Increase in Remaining Scope'
    FORECAST_FOR_150_PERCENT_INCREASE_IN_COPE = 'Forecast For 150% Increase in Remaining Scope'
    TRANSLATE_DATA_LABEL_BY_30_0 = 'translate-label-by--30-0'
    UNCHANGED_SCOPE = 'Unchanged Scope'
    LEFTOVER_SCOPE = 'Leftover Scope'

    def forecast_p90
      forecast(2.5, velocity, scope_series_values)
    end
    def forecast_p50
      forecast(1.5, velocity, scope_series_values)
    end
    def forecast_p10
      forecast(1, velocity, scope_series_values)
    end

    # returns [passed_days + time_to_reach, end_scope] == [x, y] location on the chart
    def forecast(scope_multiplier, velocity, scope_series_values)
      log("-------------forecast logging start------------------------------")
      log("start date: #{@x_axis_start_date} ---- all the following numbers are based on this date (0 at x-axis)")
      log("risk multiplier: #{scope_multiplier}")
      log("Velocity caculation data (included today if today is before the end date): #{velocity.data.inspect}")
      log("   linear regression: (y = w1 * x + w0; x = (y - w0)/w1): #{velocity.linear_f.inspect}")
      log("   slope: #{velocity.linear_f['w1']}")
      
      log("scope series values (included today if today is before the end date): #{scope_series_values.inspect}")
      
      time_to_reach, end_scope = velocity.forecast(scope_series_values, scope_multiplier)      
      x = (scope_series_values.size - 1) + time_to_reach 
      y = end_scope
      
      log("result: x (days): #{x}, y (scope): #{end_scope}")
      
      [x, y]
    end

    def forecast?(scope_series, completion_series, velocity)
      scope_series && completion_series && velocity && !(velocity.invalid?)
    end

    DASHED_LINE_SERIES_CLASS = 'mingle-chart-dashed-line-series'

    def render_forecast(renderer)
      _x_axis_values = x_axis_values
      coordinate_of_scope_series = last_coordinate_of_series(scope_series)
      coordinate_of_completion_series = last_coordinate_of_series(completion_series)
      result = forecast_in_chart(coordinate_of_scope_series, coordinate_of_completion_series, _x_axis_values, @x_axis_start_date, @mark_target_release_date, forecast_p10, forecast_p50, forecast_p90)
      result.each do |item|
        case item[0]
          when :projection
            projection, _ = *item[1]
            target_date_in_epoch_milliseconds = @mark_target_release_date.to_epoch_milliseconds
            renderer.set_fix_date_guide_line(target_date_in_epoch_milliseconds, project.format_date(@mark_target_release_date))
            if projection
              label = 'Difference between total scope and completed scope'
              renderer.add_line([projection.gap[:start_point].last, projection.gap[:end_point].last], Chart::HTML_COLORS["Blue"], label, true)
              renderer.set_data_class(label, 'thick-line-series')
              renderer.set_x_values([target_date_in_epoch_milliseconds, target_date_in_epoch_milliseconds], x_axis_label_name_for(label), label)
              renderer.hide_tooltip(label)

              renderer.add_line([projection.gap[:label_position].last], Chart::HTML_COLORS["Black"], LEFTOVER_SCOPE, true)
              renderer.set_x_values([target_date_in_epoch_milliseconds], x_axis_label_name_for(LEFTOVER_SCOPE), LEFTOVER_SCOPE)
              renderer.set_data_labels(LEFTOVER_SCOPE, projection.gap[:label])
              renderer.set_data_class(LEFTOVER_SCOPE, 'translate-label-by-10-10')
              renderer.hide_tooltip(LEFTOVER_SCOPE)
            end
          when :arbitrary_line
            point1_cord, point2_cord, color, label = *item[1]
            renderer.add_line([point1_cord[:y], point2_cord[:y]], send(color), label)
            renderer.set_data_class(label, DASHED_LINE_SERIES_CLASS)
            renderer.set_legend_style(label, :dashed)
            renderer.set_x_values([point1_cord[:x], point2_cord[:x]].map(&:to_epoch_milliseconds), x_axis_label_name_for(label), label)
            renderer.hide_tooltip(label)
          when :forecast_point
            point_cord, options = *item[1]
            render_forecast_point(renderer,point_cord, options)
        end
      end
      add_hidden_series_to_show_all_x_values(renderer, _x_axis_values)
    end

    def target_release_date_line(renderer, mark_x, label, label_position)
      mark_color = renderer.dash_line_color(Chart::HTML_COLORS["DimGray"])

      xmark = renderer.add_mark(mark_x, mark_color, '')
      xmark.setLineWidth(2)

      renderer.add_label(mark_x, label_position, label, Chart::HTML_COLORS["Black"])
    end

    def scope_color
      color_for_series(scope_series)
    end
    def completion_color
      color_for_series(completion_series)
    end

    private
    def x_axis_label_name_for(name)
      "_$xFor #{name}"
    end

    def add_hidden_series_to_show_all_x_values(renderer, x_axis_values)
      # C3 does not render X value when there is no corresponding Y value
      # Until C3 has support for this we need to add a hidden series so that C3 renderers all X values
      start_date = [Date.today, @x_axis_end_date].min
      x_values_for_hidden_series = (start_date..(x_axis_values.last + 4.days))
      label = Time.now.milliseconds.to_s
      renderer.add_line([0] * x_values_for_hidden_series.count, Charts::C3Renderers::ColorPalette::Colors::TRANSPARENT, label, true)
      renderer.set_x_values(x_values_for_hidden_series.map(&:to_epoch_milliseconds), x_axis_label_name_for(label), label )
    end

    def time_to_target(mark_target_release_date)
      (mark_target_release_date - @x_axis_start_date).to_f
    end

    def forecast_date_for(forecast)
      @x_axis_start_date + forecast.first
    end

    def render_forecast_point(renderer,cord, options)
      renderer.add_line([cord[:y]], scope_color, options[:label])
      renderer.set_data_symbol(options[:symbol])
      renderer.set_x_values([cord[:x].to_epoch_milliseconds], x_axis_label_name_for(options[:label]), options[:label])
      renderer.set_data_labels(options[:label], project.format_date(cord[:x]))
      renderer.set_forecasts_guide_line(cord[:y], scope_color) if options[:show_guide_line]
      renderer.set_data_class(options[:label], options[:class_name])
    end

    def forecast_in_chart(current_scope, current_completion, x_axis_values, x_axis_start_date, mark_target_release_date, p10, p50, p90)
      forecast_line_start = x_axis_values[completion_series_values.length - 1]
      result = []
      if mark_target_release_date
        days_to_target = (mark_target_release_date - x_axis_start_date).to_f
        projection = Projection.create(current_scope, current_completion, p10, days_to_target)
        result << [:projection, [projection]]
        if days_to_target > p10[0]
          result << [:forecast_point, [{x: forecast_date_for(p10), y: p10.last }, {label: FORECAST_FOR_NO_SCOPE_CHANGE, symbol: 'square', show_guide_line: false, class_name: TRANSLATE_DATA_LABEL_BY_30_0}]]
          result << [:arbitrary_line, [{x: forecast_line_start, y: completion_series_values.last},{x: forecast_date_for(p10), y: p10.last}, :completion_color, "Linear (#{completion_series})"]]
          result << [:arbitrary_line, [{x: forecast_line_start, y: scope_series_values.last}, {x: forecast_date_for(p10), y: scope_series_values.last}, :scope_color, UNCHANGED_SCOPE]]
        elsif days_to_target < p10[0] && need_forecast_line?(mark_target_release_date)
          result << [:arbitrary_line, [{x: forecast_line_start, y: completion_series_values.last},{x: mark_target_release_date, y: projection.completion_projection_segment.last.last}, :completion_color, "Linear (#{completion_series})"]]
          result << [:arbitrary_line, [{x: forecast_line_start, y: scope_series_values.last}, {x: mark_target_release_date, y: projection.scope_projection_segment.last.last}, :scope_color, UNCHANGED_SCOPE]]
        end
      else
        result << [:forecast_point, [{x: forecast_date_for(p10), y: p10.last }, {label: FORECAST_FOR_NO_SCOPE_CHANGE, symbol: 'square', show_guide_line: false, class_name: TRANSLATE_DATA_LABEL_BY_30_0}]]
        result << [:forecast_point, [{x: forecast_date_for(p50), y: p50.last }, {label: FORECAST_FOR_50_PERCENT_INCREASE_IN_COPE, symbol: 'triangle-up', show_guide_line: true, class_name: TRANSLATE_DATA_LABEL_BY_30_0}]]
        result << [:forecast_point, [{x: forecast_date_for(p90), y: p90.last }, {label: FORECAST_FOR_150_PERCENT_INCREASE_IN_COPE, symbol: 'circle', show_guide_line: true, class_name: TRANSLATE_DATA_LABEL_BY_30_0}]]
        result << [:arbitrary_line, [{x: forecast_line_start, y: completion_series_values.last},{x: forecast_date_for(p90), y: p90.last}, :completion_color, "Linear (#{completion_series})"]]
        result << [:arbitrary_line, [{x: forecast_line_start, y: scope_series_values.last}, {x: forecast_date_for(p10), y: scope_series_values.last}, :scope_color, UNCHANGED_SCOPE]]
      end
      result.compact
    end

    def need_forecast_line?(mark_target_release_date)
      (@x_axis_end_date < mark_target_release_date || (@x_axis_end_date > Date.today && mark_target_release_date > Date.today))
    end

  end
end
