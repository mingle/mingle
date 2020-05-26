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

class DataSeriesChart < Chart
  include EasyCharts::Style
  include EasyCharts::ChartSizeHelper
  include EasyCharts::Chart
  include SeriesChartInteractivity

  class DataSeriesChartError < StandardError
    attr_reader :project

    def initialize(message, project=nil)
      @project = project
      super(message)
    end
  end

  def self.chart_type
    'data-series-chart'
  end

  module Errors
    def x_labels_step
      StandardError.new("Parameter #{'x-labels-step'.bold} must be an integer number greater than 0. In most cases the default value is 1. With large date ranges the default value is 7.")
    end

    def cumulative
      StandardError.new("Parameter #{'cumulative'.bold} must be one of: #{'true'.bold}, #{'false'.bold}. The default value is false.")
    end

    def three_d
      StandardError.new("Parameter #{'three-d'.bold} must be one of: #{'true'.bold}, #{'false'.bold}. The default value is false.")
    end

    def show_start_label
      StandardError.new("Parameter #{'show-start-label'.bold} must be one of: #{'true'.bold}, #{'false'.bold}. The default value is false, unless one of the chart's series is a #{'down-from'.bold} series, in which case the default value is true.")
    end

    def chart_type
      StandardError.new("Parameter #{'chart-type'.bold} must be one of: #{'line'.bold}, #{'area'.bold}, #{'bar'.bold}. The default value is line.")
    end

    def x_axis_property_def(x_labels_property, project)
      DataSeriesChartError.new("Parameter #{'x-labels-property'.bold} value #{x_labels_property.bold} is not a valid property name.", project)
    end

    def x_labels_conditions_and_x_label_tree_only_supported_against_relationship_property(x_axis_property_def)
      DataSeriesChartError.new("Parameters #{'x-labels-conditions'.bold} and #{'x-labels-tree'.bold} are only supported when x-labels are driven by a relationship property. Please remove these parameters if you are not charting against a relationship property.", x_axis_property_def.project)
    end

    def invalid_x_label_start(x_labels_start, x_axis_property_def)
      DataSeriesChartError.new("#{x_labels_start.to_s.bold} is not a valid value for the #{'x-labels-start'.bold} parameter because it does not exist for property #{x_axis_property_def.name.bold}.", x_axis_property_def.project)
    end

    def invalid_x_label_end(x_labels_end, x_axis_property_def)
      DataSeriesChartError.new("#{x_labels_end.to_s.bold} is not a valid value for the #{'x-labels-end'.bold} parameter because it does not exist for property #{x_axis_property_def.name.bold}.", x_axis_property_def.project)
    end

    def x_label_start_should_be_less_than_end
      StandardError.new("#{'x-labels-start'.bold} must be a value less than #{'x-labels-end'.bold}.")
    end

    module_function :x_labels_step, :cumulative, :three_d, :show_start_label, :chart_type,
                    :x_axis_property_def, :x_labels_conditions_and_x_label_tree_only_supported_against_relationship_property,
                    :invalid_x_label_start, :invalid_x_label_end, :x_label_start_should_be_less_than_end

  end

  attr_reader :plot_start, :plot_end, :region_data, :region_mql

  private

  DEFAULT_X_LABELS_STEP_FOR_LARGE_DATE_RANGE = 7
  LARGE_DATE_RANGE_SIZE_THRESHOLD = 14
  DEFAULT_X_LABELS_STEP = 1

  public

  parameter :conditions, :default => '', :computable => true, :compatible_types => [:string], :example => 'type = card_type', :initially_shown => true
  parameter :cumulative, :default => false, :computable => true, :compatible_types => [:string], :initially_shown => true, :type => ParameterRadioButton.new(['true', 'false']), :initial_value => true
  parameter :x_labels_start, :computable => true, :initially_shown => true
  parameter :x_labels_end, :computable => true, :initially_shown => true
  parameter :x_labels_step, :computable => true, :compatible_types => [:numeric], :initially_shown => true
  parameter :x_labels_conditions, :default => '', :computable => true, :compatible_types => [:string]
  parameter :show_start_label, :computable => true, :type => ParameterRadioButton.new(['true', 'false']), :initial_value => false
  parameter :x_labels_property, :default => '', :computable => true
  parameter :x_title, :computable => true
  parameter :y_title, :computable => true
  parameter :three_d, :default => false, :computable => true, :compatible_types => [:string], :type => ParameterRadioButton.new(['true', 'false']), :initial_value => false
  parameter :x_labels_tree, :default => '', :computable => true, :compatible_types => [:string]
  parameter :data_point_symbol, :default => 'none', :computable => true, :compatible_types => [:string], :type => ParameterRadioButton.new(['none', 'square', 'diamond'], [nil, ::Chart::Style::SQUARE_POINT_ICON, ::Chart::Style::DIAMOND_POINT_ICON]), :initial_value => 'none'
  parameter :data_labels, :default => false, :computable => true, :compatible_types => [:string], :type => ParameterRadioButton.new(['true', 'false']), :initial_value => false
  include ChartStyle::Parameters
  include ChartStyle::ParametersForLegend
  parameter :start_label, :default => 'Start', :computable => true
  parameter :chart_type, :default => 'line', :computable => true, :compatible_types => [:string], :type => ParameterRadioButton.new(['line', 'area', 'bar'], [::Chart::Style::LINE_CHART_ICON, ::Chart::Style::AREA_CHART_ICON, Chart::Style::BAR_CHART_ICON]), :initial_value => 'line'
  parameter :line_width, :default => 3, :computable => true, :compatible_types => [:numeric]
  parameter :line_style, :default => 'solid', :computable => true, :compatible_types => [:string], :type => ParameterRadioButton.new(['solid', 'dash'], [::Chart::Style::SOLID_LINE_STYLE_ICON, ::Chart::Style::DASHED_LINE_STYLE_ICON]), :initial_value => 'solid'
  parameter :trend, :default => false, :computable => true, :compatible_types => [:string], :type => ParameterRadioButton.new(['true', 'false']), :initial_value => true
  parameter :trend_scope, :default => Series::TREND_SCOPE_ALL, :computable => true, :compatible_types => [:string, :numeric]
  parameter :trend_ignore, :default => Series::TREND_IGNORE_ZEROES_AT_END_AND_LAST_VALUE, :computable => true, :compatible_types => [:string], :type => ParameterRadioButton.new([Series::TREND_IGNORE_NONE, Series::TREND_IGNORE_ZEROES_AT_END, Series::TREND_IGNORE_ZEROES_AT_END_AND_LAST_VALUE]), :initial_value => Series::TREND_IGNORE_ZEROES_AT_END_AND_LAST_VALUE
  parameter :trend_line_color, :default => -1, :computable => true, :compatible_types => [:string], :type => SimpleParameterInput::COLOR_PALETTE, :initial_value => '#FF0000'
  parameter :trend_line_style, :default => 'dash', :computable => true, :compatible_types => [:string], :type => ParameterRadioButton.new(['solid', 'dash'], [::Chart::Style::SOLID_LINE_STYLE_ICON, ::Chart::Style::DASHED_LINE_STYLE_ICON]), :initial_value => 'dash'
  parameter :trend_line_width, :default => 3, :computable => true, :compatible_types => [:numeric]
  parameter :project
  parameter :series, :required => true, :list_of => Series
  parameter :show_guide_lines, :default => true, :compatible_types => [:string], :easy_charts => true
  parameter :title, :computable => true, :compatible_types => [:string], :default => ''
  parameter :legend_position, :default => LegendPosition::DEFAULT, :computable => true, :compatible_types => [:string], :easy_charts => true, :values => LegendPosition::ALL
  parameter :chart_size, :default => Sizes::DEFAULT, :computable => true, :compatible_types => [:string], :easy_charts => true, :values => Sizes::ALL

  def initialize(*args)
    super
    self.chart_width = self.chart_width.to_i if self.chart_width.is_a?(String)
    self.chart_height = self.chart_height.to_i if self.chart_height.is_a?(String)
    self.label_font_angle = self.label_font_angle.to_i if self.label_font_angle.is_a?(String)
    load_cumulative
    load_three_d
    load_chart_type
    load_show_start_label
    load_x_axis_property_def
    @x_axis_values = load_x_labels
    load_plot_start_and_end
    Series.make_series_labels_unique(series)
    @region_data = {}
    @series_label = []
    @region_mql = {'conditions' => {}, 'project_identifier' => {}}
    update_chart_size if default_dimensions?
  end

  def do_generate(renderers)
    extract_region_data
    extract_region_mql

    renderer = renderers.data_series_chart_renderer(chart_width, chart_height, font, plot_x_offset, plot_y_offset, plot_width, plot_height)
    renderer.add_legend(plot_width, plot_x_offset, legend_offset, legend_top_offset, legend_max_width)

    renderer.add_titles_to_axes(x_title || @x_axis_property_def.name, y_title || series.first.query.columns.last.aggregate_name)
    renderer.set_axes_colors(0xF1F1F1, renderer.transparent_color)   # Clean up borders
    renderer.set_x_axis_labels(labels_for_plot, font, label_font_angle)
    renderer.set_x_axis_label_step(_x_labels_step)

    # assign any mising colors in order to allow trend lines to have some color as actual data series
    color_palette_index = "FFFF0008".to_i(15)
    series.select(&:color_undefined?).each do |series|
      series.color = renderer.get_color(color_palette_index)
      color_palette_index = color_palette_index.next
    end

    # add line series
    line_series.each do |series|
      color = series.color
      color = renderer.dash_line_color(color) if series.line_style == 'dash'
      series_renderer = renderer.add_line(series_data_for_plot(series.label), color, series.label)
      series_renderer.set_3d if three_d
      series_renderer.set_data_symbol(series.data_point_symbol)
      series_renderer.set_data_label_format if series.set_data_label_format?
      series_renderer.set_line_width(series.line_width)
    end

    # add trend lines
    series.select(&:trend).each do |series|
      trend_color = series.trend_line_color
      trend_color = renderer.dash_line_color(trend_color) if series.trend_line_style == 'dash'
      trend_layer = renderer.add_trend_line(series_trend_data_for_plot(series.label), trend_color, "#{series.label} Trend")
      trend_layer.set_3d if three_d
      trend_layer.set_line_width(series.trend_line_width)
    end


    # add bar layers
    bars = renderer.add_bars
    bar_series.each do |series|
      bars.add_data_set(series_data_for_plot(series.label), series.color, series.label)
      bars.set_3d if three_d
      bars.set_data_label_format if series.set_data_label_format?
    end

    # add area series
    area_series.each do |series|
      layer = renderer.add_area_layer
      layer.set_3d if three_d
      layer.add_data_set(series_data_for_plot(series.label), series.color, series.label)
      layer.set_data_symbol(series.data_point_symbol)
      layer.set_data_label_format if series.set_data_label_format?
    end

    renderer.set_region_data(region_data)
    renderer.set_region_mql(region_mql)
    renderer.show_guide_lines if show_guide_lines
    renderer.set_title(title)
    renderer.set_legend_position(legend_position)
    renderer.make_chart
  end

  def x_axis_values
    @x_axis_values
  end

  def can_be_cached?
    series.all?(&:can_be_cached?)
  end

  def series_by_label
    result = {}
    series.each {|s| result[s.label] = s}
    result
  end

  def labels_for_plot
    array_for_plot(x_axis_values)
  end

  memoize :labels_for_plot

  def series_data_for_plot(label)
    array_for_plot(series_by_label[label].values)
  end

  memoize :series_data_for_plot

  def x_axis_labels
    @x_axis_labels
  end

  private

  def series_trend_data_for_plot(label)
    values = series_by_label[label].trend_data
    array_for_plot(values)
  end

  memoize :series_trend_data_for_plot

  def card_label_property?
    PropertyType::CardType === @x_axis_property_def.property_type
  end

  def date_label_property?
    @x_axis_property_def.is_a?(DatePropertyDefinition)
  end

  def numeric_label_property?
    @x_axis_property_def.numeric?
  end

  # funky underscore method names allow us to support old-school stack bar chart syntax
  def _x_labels_start
    value = x_labels_start
    if value && date_label_property?
      value = parse_date(value, 'x-labels-start').strftime(project.date_format)
    end
    value ? value.to_s : nil
  end
  memoize :_x_labels_start

  def _x_labels_end
    value = x_labels_end
    if value && date_label_property?
      value = parse_date(value, 'x-labels-end').strftime(project.date_format)
    end
    value ? value.to_s : nil
  end
  memoize :_x_labels_end

  def _x_labels_step
    override = x_labels_step
    if override
      unless override.to_i > 0 && override.to_i == override.to_f
        raise DataSeriesChart::Errors.x_labels_step
      end
      return override.to_i
    end

    if date_label_property? && @x_axis_values.size > LARGE_DATE_RANGE_SIZE_THRESHOLD
      return DEFAULT_X_LABELS_STEP_FOR_LARGE_DATE_RANGE
    else
      return DEFAULT_X_LABELS_STEP
    end
  end

  def array_for_plot(array)
    result = array[plot_start..plot_end]
    result.unshift(array.first) if show_start_label && plot_start > 0
    result
  end

  def bar_series
    series.select{|s| s.layer_type == 'bar'}
  end

  def line_series
    series.select{|s| s.layer_type == 'line'}
  end

  def area_series
    series.select{|s| s.layer_type == 'area'}
  end

  def load_cumulative
    @cumulative = true if @cumulative == 'true'
    @cumulative = false if @cumulative == 'false'
    unless [true, false].include?(@cumulative)
      raise DataSeriesChart::Errors.cumulative
    end
  end

  def load_three_d
    @three_d = true if @three_d == 'true'
    @three_d = false if @three_d == 'false'
    unless [true, false].include?(@three_d)
      raise DataSeriesChart::Errors.three_d
    end
  end

  def load_show_start_label
    if @show_start_label.nil?
      @show_start_label = down_from? ? true : false
    end
    @show_start_label = true if @show_start_label == 'true'
    @show_start_label = false if @show_start_label == 'false'
    unless [true, false].include?(@show_start_label)
      raise DataSeriesChart::Errors.show_start_label
    end
  end

  def load_chart_type
    @chart_type = @chart_type.to_s.downcase
    raise DataSeriesChart::Errors.chart_type unless ['line', 'bar', 'area'].include?(@chart_type)
  end

  def load_x_axis_property_def
    @x_axis_property_def = x_labels_property.blank? ? series.first.x_axis_property_definition : project.find_property_definition(x_labels_property, with_hidden: true)
  rescue Exception => e
    raise DataSeriesChart::Errors.x_axis_property_def(x_labels_property, project)
  end

  def load_x_labels
    if (!x_labels_conditions.blank? || !x_labels_tree.blank?) && !card_label_property?
      raise DataSeriesChart::Errors.x_labels_conditions_and_x_label_tree_only_supported_against_relationship_property(@x_axis_property_def)
    end

    @x_axis_labels = if @x_axis_property_def.numeric? && !@x_axis_property_def.respond_to?(:enumeration_values)
      FreeNumericXAxisLabels.new(@x_axis_property_def)
    elsif card_label_property?
      if x_labels_tree.blank?
        CardXAxisLabels.new(@x_axis_property_def, card_query_options, :x_labels_conditions => x_labels_conditions)
      else
        CardXAxisLabelsFromTree.new(@x_axis_property_def, card_query_options, :x_labels_conditions => x_labels_conditions, :from_tree => x_labels_tree)
      end
    elsif date_label_property?
      DateXAxisLabels.new(@x_axis_property_def, :date_format => project.date_format, :x_label_start => _x_labels_start, :x_label_end => _x_labels_end)
    else
      XAxisLabels.new(@x_axis_property_def)
    end

    @x_axis_labels.prepend_artificial_start_label(show_start_label, start_label)
    @x_axis_labels.labels
  end

  def load_plot_start_and_end
    start_value = get_single_label_value_with_validation(_x_labels_start) { raise invalid_x_label_start_error }
    end_value = get_single_label_value_with_validation(_x_labels_end) { raise invalid_x_label_end_error }
    return @plot_end = @plot_start = 0 if @x_axis_values.blank?

    @plot_start = _x_labels_start ? @x_axis_values.index(start_value.to_s) : 0
    @plot_end = _x_labels_end ? @x_axis_values.index(end_value.to_s) : @x_axis_values.size - 1
    raise DataSeriesChart::Errors.x_label_start_should_be_less_than_end if @plot_start > @plot_end
  end

  def get_single_label_value_with_validation(x_axis_label, &exception_block)
    begin
      value = @x_axis_labels.label_value_for_input_value(x_axis_label, project)
      if x_axis_label && !@x_axis_values.empty? && !@x_axis_values.include?(value.to_s)
        exception_block.call
      end
      value
    rescue PropertyDefinition::InvalidValueException
      exception_block.call
    end
  end

  def invalid_x_label_start_error
    DataSeriesChart::Errors.invalid_x_label_start(_x_labels_start, @x_axis_property_def)
  end

  def invalid_x_label_end_error
    DataSeriesChart::Errors.invalid_x_label_end(_x_labels_end, @x_axis_property_def)
  end

  def down_from?
    series.any?(&:down_from?)
  end

end

Macro.register('data-series-chart', DataSeriesChart)

