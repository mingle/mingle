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

class TextChartRenderers
  class << self
    def pie_chart_renderer(chart_width, chart_height)
      TextPieChartRenderer.new(chart_width, chart_height)
    end

    def data_series_chart_renderer(chart_width, chart_height, font, plot_x_offset, plot_y_offset, plot_width, plot_height)
      TextDataSeriesChartRenderer.new
    end

    def stack_bar_chart_renderer(chart_width, chart_height, font, plot_x_offset, plot_y_offset, plot_width, plot_height)
      TextStackBarChartRenderer.new
    end

    def ratio_bar_chart_renderer(chart_width, chart_height)
      TextRatioBarChartRenderer.new(chart_width, chart_height)
    end

    def daily_history_chart_renderer(chart_width, chart_height, font, plot_x_offset, plot_y_offset, plot_width, plot_height)
      TextDailyHistoryChartRenderer.new
    end

  end
end

module TextRenderer
  def transparent_color
    'transparent'
  end

  def calculate_steps
    step = @data[:step].to_i
    if (@data[:step] && step > 1)
      result = []
      @data[:x_labels].split(',').each_with_index do |x_label, index|
        result << x_label if (index % step == 0)
      end
      @data[:x_labels] = result.join(',')
    end
  end

  def make_chart
    calculate_steps
    html = "<dl>"
    @data.each do |key, value|
      html << "<dd>#{key}</dd>"
      html << "<dt id='value_for_#{key}'>#{value.to_s}</dt>"
    end
    html << "</dl>"
    html
  end
end

class TextPieChartRenderer
  include TextRenderer

  def initialize(width, height)
    @data = {
        :pie_width => width,
        :pie_height => height
    }
  end

  def add_text(*args)
    ;
  end

  def set_radius(radius)
    @data[:radius] = radius
  end

  def set_default_fonts(*args)
    ;
  end

  def set_label_layout(*args)
    ;
  end

  def set_label_style(*args)
    ;
  end

  def set_data(data)
    @data[:slice_sizes] = data.collect(&:last).join(', ')
    @data[:slice_labels] = data.collect(&:first).join(', ')
  end

  def set_region_data(data)
    ;
  end

  def set_region_mql(data)
    ;
  end

  def set_title(text)
    ;
  end

  def set_label_type(label_type)
    ;
  end

  def set_legend_position(legend_position)
    ;
  end

end

class TextSeries
  include TextRenderer

  def initialize
    @data = {}
  end

  def add_legend(*args)
    ;
  end

  def add_titles_to_axes(x_title, y_title)
    @data[:x_title] = x_title
    @data[:y_title] = y_title
  end

  def set_axes_colors(x_axis_color, y_axis_color)
    ;
  end

  def set_x_axis_labels(labels, font, label_font_angle,*_)
    @data[:x_labels] = labels.join(",")
  end

  def show_guide_lines
    @data[:grid] = {y: {show: true},
                    x: {show: true}}
  end

  def set_legend_position(position)
    @data[:legend] = {position: position}
  end

  def set_title(title)
    @data[:title] = {text: title}
  end

  def set_x_axis_label_step(step)
    @data[:step] = step
  end

  def add_line(series_data, color, series_label)
    LineRenderer.new(@data, series_data, color, series_label)
  end

  def add_area_layer
    AreaRenderer.new(@data)
  end

  def add_bars
    BarsRenderer.new(@data)
  end

  class SeriesRenderer

    def initialize(data)
      @data = data
    end

    def add_data_set(series_data, color, label)
      @label = label
      @data["data_for_#{label}"] = series_data.join(",")
    end

    def set_3d;
    end

    def set_data_label_format;
      @data["data_labels_enabled_for_#{@label}"] = true
    end

    def set_line_width(width)
      ;
    end

  end

  class LineRenderer < SeriesRenderer

    def initialize(chart_data, series_data, color, series_label)
      super(chart_data)
      @line_label = series_label
      @data["data_for_#{@line_label}"] = series_data.join(",")
    end

    def set_line_width(width)
      @data["line_width_#{@line_label}"] = width
    end

    def set_data_symbol(data_point_symbol)
      @data["data_point_symbol_#{@line_label}"] = data_point_symbol
    end

    def add_end_point_label(*args)
      @data["end_point_label_#{@line_label}"] = args.join(",")
      self
    end

    # really just a hack - belongs to TextBox, but we don't care about this.
    def setAlignment(*args)
      ;
    end
  end

  class TextDailyHistoryChartLineRenderer < LineRenderer
    def enable_data_labels_on_selected_positions(*args) ; end
  end

  class AreaRenderer < SeriesRenderer;
    def set_data_symbol(data_point_symbol)
    end

    def add_end_point_label(*args)
      self
    end
  end

  class BarsRenderer < SeriesRenderer

    def set_bar_gap(gap)
      ;
    end

    def set_border_color(color)
      ;
    end

  end

end

class TextDailyHistoryChartRenderer < TextSeries

  def set_data_symbol(data_point_symbol)
  end

  def set_x_values(x_value, x_label, *series_labels) ; end

  def set_data_labels(series_name, label) ; end

  def get_color(*args) ; end

  def set_data_class(*args) ; end

  def set_forecasts_guide_line(*args) ; end

  def set_message(*args) ; end

  def set_legend_style(*args) ; end

  def hide_tooltip(*args) ; end

  def add_line(series_data, color, series_label, hide_legend=false)
    TextSeries::TextDailyHistoryChartLineRenderer.new(@data, series_data, color,series_label)
  end
end


class TextDataSeriesChartRenderer < TextSeries
  def add_scatter_layer(*args)
    @data["data_for_scatter_layer_#{args[2]}"] = args[0..1].join(",")
  end

  def add_point_label(*args)
    @data["add_point_label_#{args[1]}"] = args[1]
  end

  def add_arbitrary_line(*args)
    @data["data_for_arbitrary_line_#{args[0]}"] = args.join(",")
  end

  def add_legend_key(key, color)
    @data["forecasts"] = key
  end

  def get_color(color_palette_index)
    ;
  end

  def dash_line_color(color)
    ;
  end

  def add_trend_line(trend_data, color, label)
    TrendRenderer.new(@data, trend_data, color, label)
  end

  def add_mark(width, color, label)
    ;
  end

  def set_region_data(bar_data)
    ;
  end

  def set_region_mql(bar_mql)
    ;
  end

  def disable_interactivity
    ;
  end

  def set_progress(_);end

  def show_guide_lines();end

  def set_zoom(_);end


  class TrendRenderer < SeriesRenderer
    def initialize(chart_data, series_data, color, label)
      super(chart_data)
      @trend_label = label
      @data["data_for_#{@trend_label}"] = series_data.join(",")
    end

    def set_line_width(width)
      @data["line_width_#{@trend_label}"] = width
    end
  end

end

class TextStackBarChartRenderer < TextSeries;
  def set_region_data(bar_data)
    ;
  end

  def set_region_mql(bar_mql)
    ;
  end
end

class TextRatioBarChartRenderer < TextSeries

  def initialize(chart_width, chart_height)
    super()
  end

  def add_bars(data, color)
    @data["data"] = data.join(",")
    BarsRenderer.new(@data)
  end

  def set_y_axis_label_format(format)
    ;
  end

  def set_linear_scale(lower_limit, upper_limit)
    ;
  end

  def set_region_data(bar_data)
    ;
  end

  def set_region_mql(bar_mql)
    ;
  end

end
