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

class StackBarChart < Chart
  include EasyCharts::Style
  include EasyCharts::ChartSizeHelper
  include EasyCharts::Chart
  include SeriesChartInteractivity

  def self.chart_type
    'stacked-bar-chart'
  end

  parameter :conditions,    :default => '',     :computable => true, :compatible_types => [:string], :example => 'type = card_type',                       :initially_shown => true
  parameter :cumulative,    :default => false,  :computable => true, :compatible_types => [:string],                                                       :initially_shown => true, :type => ParameterRadioButton.new(['true', 'false']), :initial_value => true
  parameter :x_label_start,                     :computable => true
  parameter :x_label_end,                       :computable => true
  parameter :x_label_step,                      :computable => true, :compatible_types => [:numeric]
  parameter :x_title,                           :computable => true, :compatible_types => [:string]
  parameter :y_title,                           :computable => true, :compatible_types => [:string]
  parameter :labels,        :default => '',                                                        :example => "SELECT DISTINCT property",                 :initially_shown => true
  parameter :x_labels_tree, :default => '',     :computable => true, :compatible_types => [:string]
  parameter :three_d,       :default => false,  :computable => true, :compatible_types => [:string], :type => ParameterRadioButton.new(['true', 'false']), :initial_value => false
  include ChartStyle::Parameters, ChartStyle::ParametersForLegend
  parameter :project

  parameter :series,   :required => true, :list_of => Series
  attr_reader :region_data, :region_mql
  parameter :title,               :computable => true, :compatible_types => [:string], :default => ''
  parameter :show_guide_lines,    :default => true, :compatible_types => [:string]
  parameter :legend_position,     :default => LegendPosition::DEFAULT, :computable => true, :compatible_types =>[:string], :values => LegendPosition::ALL
  parameter :chart_size,          :default => Sizes::DEFAULT, :computable => true, :compatible_types =>[:string], :values => Sizes::ALL

  def initialize(*args)
    super
    Series.make_series_labels_unique(series)
    load_series
    load_x_axis_labels
    load_x_label_step
    load_x_label_start_and_x_label_end
    load_series_values
    self.chart_width = self.chart_width.to_i if self.chart_width.is_a?(String)
    self.chart_height = self.chart_height.to_i if self.chart_height.is_a?(String)
    self.label_font_angle = self.label_font_angle.to_i if self.label_font_angle.is_a?(String)
    @region_data = {}
    @series_label = []
    @region_mql = { 'conditions' => {}, 'project_identifier' => ''}

    update_chart_size if default_dimensions?
  end

  def load_series
    self.series = normal_series + series_overlay_bottom + [total_series].compact + series_overlay_top
  end

  def load_series_values
    self.series.each { |series| series.load_values }
  end

  def load_x_axis_labels
    if labels.blank?
      @x_axis_property_def = (total_series || series.first).query.columns.first.property_definition
      if card_label_property?
        if x_labels_tree.blank?
          @x_axis_labels = CardXAxisLabels.new(@x_axis_property_def, card_query_options)
        else
          @x_axis_labels = CardXAxisLabelsFromTree.new(@x_axis_property_def, card_query_options, :from_tree => x_labels_tree)
        end
      elsif date_label_property?
        @x_axis_labels = DateXAxisLabels.new(@x_axis_property_def, :date_format => project.date_format, :x_label_start => x_label_start, :x_label_end => x_label_end)
      else
        @x_axis_labels = StackBarChartXAxisLabels.new(@x_axis_property_def)
      end
    else
      labels_query = CardQuery.parse(labels, card_query_options).restrict_with(conditions, :cast_numeric_columns => true).order_and_group_by_first_column_if_necessary
      @x_axis_property_def = labels_query.columns.first.property_definition
      if card_label_property?
        if x_labels_tree.blank?
          @x_axis_labels = StackBarChartXAxisLabelsCardPropertyDefintion.new(@x_axis_property_def, :labels_query => labels_query)
        else
          @x_axis_labels = StackBarChartXAxisLabelsFromTree.new(@x_axis_property_def, :from_tree => x_labels_tree, :labels_query => labels_query)
        end
      elsif date_label_property?
        @x_axis_labels = DateXAxisLabels.new(@x_axis_property_def, :date_format => project.date_format, :x_label_start => x_label_start, :x_label_end => x_label_end, :labels_query => labels_query)
      else
        @x_axis_labels = StackBarChartXAxisLabels.new(@x_axis_property_def, :labels_query => labels_query)
      end
    end
  end

  def load_x_label_step
    @x_label_step = @x_label_step.to_i if @x_label_step.is_a?(String)
    @x_label_step ||= date_label_property? ? 5 : 1
  end

  def load_x_label_start_and_x_label_end
    start_value = @x_axis_property_def.label_value_for_charting(x_label_start)
    end_value = @x_axis_property_def.label_value_for_charting(x_label_end)

    @start_index = (start_value && x_axis_values.include?(start_value.to_s)) ? x_axis_values.index(start_value.to_s) : 0
    @end_index = (end_value && x_axis_values.include?(end_value.to_s)) ? x_axis_values.index(end_value.to_s) : (x_axis_values.nil? ? 0 : -1)
  end

  def x_axis_labels
    @x_axis_labels
  end

  def x_axis_values
    @x_axis_labels.labels
  end

  def series_by_label
    result = {}
    series.each { |s| result[s.label] = s }
    result
  end

  def can_be_cached?
    series.all?(&:can_be_cached?)
  end

  def total_series
    series.find { |s| s.combine == 'total' }
  end

  def series_overlay_bottom
    series.select { |s| s.combine == 'overlay-bottom' }
  end

  def series_overlay_top
    series.select { |s| s.combine == 'overlay-top' }
  end

  def normal_series
    series - (series_overlay_top + series_overlay_bottom + [total_series].compact)
  end

  def bar_series
    series.select { |s| s.layer_type == 'bar' }
  end

  def line_series
    series.select { |s| s.layer_type == 'line' }
  end

  def area_series
    series.select { |s| s.layer_type == 'area' }
  end

  def chart_type
    'bar'
  end

  def do_generate(renderers)
    extract_region_data
    extract_region_mql
    renderer = renderer(renderers)

    renderer.add_legend(plot_width, plot_x_offset, legend_offset, legend_top_offset, legend_max_width)
    renderer.add_titles_to_axes(x_title || @x_axis_property_def.name, y_title || (series.present? && series.first.query.columns.last.aggregate_name) || '')

    # Clean up borders
    renderer.set_axes_colors(0xF1F1F1, renderer.transparent_color)
    renderer.set_x_axis_labels(labels_for_plot, font, label_font_angle)
    renderer.set_x_axis_label_step(@x_label_step)
    # Add line layers
    add_line_series(renderer)

    # Add a stacked bar layer
    bars = renderer.add_bars
    bars.set_bar_gap(0.15)
    bars.set_3d if three_d
    bars.set_border_color(renderer.transparent_color)

    # Add the data sets to the bar layer
    bar_series.each do |series|
      bars.add_data_set(series_data_for_plot(series.label), series.color, series.label)
    end
    # Add the data sets to the bar layer
    add_area_series(renderer)

    renderer.set_region_data(region_data)
    renderer.set_region_mql(region_mql)
    renderer.set_title(title)
    renderer.show_guide_lines if show_guide_lines
    renderer.set_legend_position(legend_position)
    renderer.make_chart
  end

  def labels_for_plot
    filter_for_display(x_axis_values).collect do |label|
      (label || PropertyValue::NOT_SET).to_s
    end
  end

  def series_data_for_plot(label)
    filter_for_display(series_by_label[label].values)
  end

  def generate
    generate_chart(::C3Renderers)
  end

  protected
  def renderer(renderers)
    renderers.stack_bar_chart_renderer(chart_width, chart_height, font, plot_x_offset, plot_y_offset, plot_width, plot_height)
  end

  def add_area_series(renderer)
    if three_d
      area_series.reverse.each do |series|
        layer = renderer.add_area_layer
        layer.set_3d
        layer.add_data_set(series_data_for_plot(series.label), series.color, series.label)
      end
    else
      layer = renderer.add_area_layer
      area_series.each do |series|
        layer.add_data_set(series_data_for_plot(series.label), series.color, series.label)
      end
    end
  end

  def add_line_series(renderer)
    line_series.each do |series|
      series_renderer = renderer.add_line(series_data_for_plot(series.label), series.color, series.label)
      series_renderer.set_3d if three_d
      series_renderer.set_line_width(3)
    end
  end

  private
  def chart_id(position)
    "stacked-bar-chart-#{source}-#{content_provider.id}-#{position}"
  end

  def card_label_property?
    PropertyType::CardType === @x_axis_property_def.property_type
  end

  def filter_for_display(array)
    array.nil? ? [] : array[@start_index..@end_index]
  end

  def date_label_property?
    @x_axis_property_def.is_a?(DatePropertyDefinition)
  end

  def parse_date(str)
    Date.parse(str).strftime(project.date_format) rescue nil
  end

  def replace_nil_labels(hash)
    hash.keys.each do |k|
      unless k
        @region_mql['conditions'][PropertyValue::NOT_SET] = @region_mql['conditions'].delete(k)
      end
    end
  end
end

Macro.register('stack-bar-chart', StackBarChart)
Macro.register('stacked-bar-chart', StackBarChart)
