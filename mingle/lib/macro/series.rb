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

class Series
  include Macro::ParameterSupport

  TREND_IGNORE_NONE = 'none'
  TREND_IGNORE_ZEROES_AT_END = 'zeroes-at-end'
  TREND_IGNORE_ZEROES_AT_END_AND_LAST_VALUE = "#{TREND_IGNORE_ZEROES_AT_END}-and-last-value"
  TREND_SCOPE_ALL = 'all'
  TREND_SCOPE_DEFAULT = TREND_SCOPE_ALL
  DATA_POINT_SYMBOLS = %w(none circle square diamond)

  parameter "data",              :computable => true,         :example => "SELECT property, aggregate WHERE condition", :required => true
  parameter "label",             :computable => true, :compatible_types => [:string], :example => "Series", :initially_shown => true, default: 'Series'
  parameter "color",             :computable => true, :compatible_types => [:string], :initially_shown => true, :type => SimpleParameterInput::COLOR_PALETTE, :initial_value => '#FF0000'
  parameter "type",              :computable => true, :compatible_types => [:string], :initially_shown => false, :type => ParameterRadioButton.new(['line', 'area', 'bar'], [Chart::Style::LINE_CHART_ICON, Chart::Style::AREA_CHART_ICON, Chart::Style::BAR_CHART_ICON]), :initial_value => 'bar'
  parameter "project",           :computable => true, :compatible_types => [:string]
  parameter "combine",           :computable => true, :compatible_types => [:string], :initially_shown => true, :type => ParameterRadioButton.new(['total', 'overlay-top', 'overlay-bottom']), :initial_value => 'overlay-bottom'
  parameter "hidden",            :computable => true, :compatible_types => [:string], :type => ParameterRadioButton.new(['true', 'false']), :initial_value => false
  parameter "data_point_symbol", :computable => true, :compatible_types => [:string], :type => ParameterRadioButton.new(['none', 'square', 'diamond'], [nil, Chart::Style::SQUARE_POINT_ICON, Chart::Style::DIAMOND_POINT_ICON]), :initial_value => 'none'
  parameter "data_labels",       :computable => true, :compatible_types => [:string], :type => ParameterRadioButton.new(['true', 'false']), :initial_value => true
  parameter "down_from",         :computable => true
  parameter "line_width",        :computable => true, :compatible_types => [:numeric]
  parameter "line_style",        :computable => true, :compatible_types => [:string], :type => ParameterRadioButton.new(['solid', 'dash'], [Chart::Style::SOLID_LINE_STYLE_ICON, Chart::Style::DASHED_LINE_STYLE_ICON]), :initial_value => 'solid'
  parameter "trend",             :computable => true, :compatible_types => [:string], :initially_shown => true, :type => ParameterRadioButton.new(['true', 'false']), :initial_value => true
  parameter "trend_scope",       :computable => true, :compatible_types => [:string]
  parameter "trend_ignore",      :computable => true, :compatible_types => [:string], :type => ParameterRadioButton.new([Series::TREND_IGNORE_NONE, Series::TREND_IGNORE_ZEROES_AT_END, Series::TREND_IGNORE_ZEROES_AT_END_AND_LAST_VALUE]), :initial_value => Series::TREND_IGNORE_ZEROES_AT_END_AND_LAST_VALUE
  parameter "trend_line_color",  :computable => true, :compatible_types => [:string], :type => SimpleParameterInput::COLOR_PALETTE, :initial_value => '#FF0000'
  parameter "trend_line_style",  :computable => true, :compatible_types => [:string], :type => ParameterRadioButton.new(['solid', 'dash'], [Chart::Style::SOLID_LINE_STYLE_ICON, Chart::Style::DASHED_LINE_STYLE_ICON]), :initial_value => 'dash', :default => 'dash'
  parameter "trend_line_width",  :computable => true, :compatible_types => [:numeric], :initially_shown => true, :example => 2

  module Errors

    def no_project_found(specified_project)
      RuntimeError.new("There is no project with identifier #{specified_project.bold}")
    end

    def user_not_member_of_project(specified_project)
      RuntimeError.new("This content contains data for one or more projects of which you are not a member. To see this content you must be a member of the following project: #{specified_project.bold}")
    end

    def value_of_total_less_than_sum_of_overlay(data_specification, label)
      RuntimeError.new("The value of the total conditions #{data_specification.bold} is less than sum value of the overlay conditions for label #{label.bold}.")
    end

    def property_and_aggregate_not_specified_in_series_data_parameter
      RuntimeError.new("Property name and aggregate must be specified in the series data parameter: #{parameter.bold}")
    end

    def property_not_specified_in_series_data_parameter(parameter)
      RuntimeError.new("A property name must be specified in the series data parameter: #{parameter.bold}")
    end

    def aggregate_not_specified_in_series_data_parameter(parameter)
      RuntimeError.new("An aggregate must be specified in the series data parameter: #{parameter.bold}")
    end

    def down_from_requires_cumulative_to_be_true
      RuntimeError.new("Parameter #{'down-from'.bold} can only be specified when the chart's #{'cumulative'.bold} property is set to true.")
    end

    def incorrect_line_style
      RuntimeError.new("Parameter #{'line-style'.bold} must be one of: #{'dash'.bold}, #{'solid'.bold}. The default value is solid.")
    end

    def incorrect_trend_parameter
      RuntimeError.new("Parameter #{'trend'.bold} must be one of: #{'true'.bold}, #{'false'.bold}. The default value is false.")
    end

    def incorrect_trend_line_style_parameter
      RuntimeError.new("Parameter #{'trend-line-style'.bold} must be one of: #{'dash'.bold}, #{'solid'.bold}. The default value is dash.")
    end

    def incorrect_trend_ignore_parameter
      RuntimeError.new("Parameter #{'trend-ignore'.bold} must be one of: #{TREND_IGNORE_NONE.bold}, #{TREND_IGNORE_ZEROES_AT_END.bold}, #{TREND_IGNORE_ZEROES_AT_END_AND_LAST_VALUE.bold}. The default value is #{TREND_IGNORE_ZEROES_AT_END_AND_LAST_VALUE}.")
    end

    def incorrect_trend_scope_parameter
      RuntimeError.new("Parameter #{'trend-scope'.bold} must be one of: #{TREND_SCOPE_ALL.bold}, any #{'integer'.bold} value greater than 0. The default value is #{TREND_SCOPE_ALL}.")
    end

    def incorrect_data_point_symbol_parameter
      RuntimeError.new("Parameter #{'data-point-symbol'.bold} must be one of: #{'none'.bold}, #{'circle'.bold}, #{'square'.bold}, #{'diamond'.bold}. The default value is none.")
    end

    def incorrect_data_labels_parameter
      RuntimeError.new("Parameter #{'data-labels'.bold} must be one of: #{'true'.bold}, #{'false'.bold}. The default value is false.")
    end

    module_function :no_project_found, :user_not_member_of_project, :value_of_total_less_than_sum_of_overlay,
                    :property_and_aggregate_not_specified_in_series_data_parameter,
                    :property_not_specified_in_series_data_parameter, :aggregate_not_specified_in_series_data_parameter,
                    :down_from_requires_cumulative_to_be_true, :incorrect_line_style, :incorrect_trend_parameter, :incorrect_trend_line_style_parameter,
                    :incorrect_trend_ignore_parameter, :incorrect_trend_scope_parameter, :incorrect_data_point_symbol_parameter, :incorrect_data_labels_parameter

  end

  class ProjectScopedWrapper
    instance_methods.each { |m| undef_method m unless m =~ /(^__|^nil\?$|^send$|proxy_|^object_id$)/ }

    def initialize(project, object)
      @project = project
      @object = object
    end

    def method_missing(method_id, *args)
      @project.with_active_project do
        @object.send(method_id, *args)
      end
    end
  end

  class << self
    def parameter_definitions_for_data_series_chart
      parameter_definitions.reject { |pd| %w{combine hidden}.include? pd.name.to_s.downcase }
    end

    def parameter_definitions_for_stack_bar_chart
      parameter_definitions.reject do |pd|
        name = pd.name.to_s.downcase
        %w{down_from data_point_symbol data_labels line_width line_style}.include?(name) || name =~ /^trend*/
      end
    end

    def make_series_labels_unique(series)
      labels = series.map(&:label)
      labels.duplicates.each do |duplicate_label|
        duplicate_series = series.select { |s| s.label == duplicate_label }
        duplicate_series.each do |s|
          s.label = "#{s.label} (#{next_available_index(duplicate_label, labels)})"
          labels = series.map(&:label)
        end
      end
    end

    private

    def next_available_index(duplicate_label, labels)
      i = 1
      i += 1 while labels.include?("#{duplicate_label} (#{i})")
      i
    end
  end

  attr_accessor :color, :layer_type
  attr_reader :values_as_coords, :query

  def initialize(chart, specification, card_query_options = {})
    initialize_parameters_from(chart, specification, card_query_options)
    @chart = chart
    @card_query_options = card_query_options.clone

    specified_project = project

    self.project = specified_project ? Project.find_by_identifier(specified_project) : Project.current

    raise Series::Errors.no_project_found(specified_project) unless @project
    raise Series::Errors.user_not_member_of_project(specified_project) unless User.current.accessible?(@project)

    @project.with_active_project { |project| load_chart_data }
  end

  def project
    @project
  end

  def can_be_cached?
    @query.can_be_cached?
  end

  def values
    @values ||= load_values
  end

  def load_values
    x_axis_values = @chart.x_axis_labels.reformat_values_from(
                                    :another_project => @chart.project,
                                    :x_labels_tree => @chart.x_labels_tree,
                                    :series_project => x_axis_property_definition.project)
    @uncumulated_data = x_axis_values.collect { |x_axis_value| (@values_as_coords.find_by_numeric_key(x_axis_value) || 0) }
    @values = combine_data(cumulate(@uncumulated_data))
    @values = values.collect{|value| @down_from_value - value} if @down_from_value
    @values
  end

  def x_axis_property_definition
    ProjectScopedWrapper.new(@project, @query.columns.first.property_definition)
  end

  def trend_data
    values if @values.nil? #
    start_index, end_index = start_and_end_index
    y_values = filter_trend_data(values, trend_data_count: values.size)[start_index..end_index]
    return [] unless y_values.size > 1
    x_values = 1.upto(values.size).to_a
    coefficients = LinearRegression.linear_f(x_values[start_index..end_index], y_values)
    trend_values = x_values.map do |x_value|
      val = coefficients['w1'] * x_value + coefficients['w0']
      val.round(4)
    end
    trend_values
  end

  def combine_data(cumulated_series_values)
    if combine == 'total'
      cumulated_series_values.each_with_index do |val, index|
        offset_by =
          (@chart.series_overlay_bottom.collect{|s| s.values[index]}.sum || 0) +
            (@chart.series_overlay_top.collect{|s| s.values[index]}.sum || 0)
        cumulated_series_values[index] -= offset_by

        raise Series::Errors.value_of_total_less_than_sum_of_overlay(data, @chart.x_axis_values[index]) if cumulated_series_values[index] < 0
      end
    end

    cumulated_series_values
  end

  def cumulate(data)
    return data unless @chart.cumulative?

    previous = 0
    data.collect do |i|
      previous += i
    end
  end

  def color_undefined?
    @color == -1
  end

  def line?
    @layer_type == 'line'
  end

  def area?
    @layer_type == 'area'
  end

  def bar?
    @layer_type == 'bar'
  end

  def trend_line_color
    @trend_line_color == -1 ? @color : @trend_line_color
  end

  def down_from?
    @down_from_value
  end

  def down_from_mql
   CardQuery::MqlGeneration.new(@down_from_query.conditions)
  end

  def down_from_data
    @down_from_data
  end

  def set_data_label_format?
    @data_labels
  end

  def label
    @label.to_s
  end

  def load_chart_data
    @query = CardQuery.parse(data, @card_query_options).restrict_with(@chart.conditions, :cast_numeric_columns => true)
    raise Series::Errors.property_and_aggregate_not_specified_in_series_data_parameter(data) if @query.columns.blank?
    raise Series::Errors.property_not_specified_in_series_data_parameter(data) if @query.columns.select{|c|c.is_a?(CardQuery::Column)}.blank?
    raise Series::Errors.aggregate_not_specified_in_series_data_parameter(data) if @query.columns.select{|c|c.is_a?(CardQuery::AggregateFunction)}.blank?
    @values_as_coords = @query.values_as_coords
    load_down_from(down_from)
    self.label = label
    self.color = color_value
    @layer_type = type ? (type).to_s.downcase : @chart.chart_type
    load_data_point_symbol(data_point_symbol) if @chart.respond_to?(:data_point_symbol)
    load_data_labels(data_labels) if @chart.respond_to?(:data_labels)
    load_line_width(line_width) if @chart.respond_to?(:line_width)
    load_line_style(line_style) if @chart.respond_to?(:line_style)
    if @chart.respond_to?(:trend)
      load_trend(trend)
      if @trend
        load_trend_line_color(trend_line_color)
        load_trend_line_style(trend_line_style)
        load_trend_line_width(trend_line_width)
        load_trend_ignore(trend_ignore)
        load_trend_scope(trend_scope)
      end
    end
  end

  def load_down_from(specified_down_from)
    if specified?(specified_down_from) && !@chart.cumulative?
      raise Series::Errors.down_from_requires_cumulative_to_be_true
    end
    if specified?(specified_down_from)
      @down_from_query = CardQuery.parse(specified_down_from, @card_query_options).restrict_with(@chart.conditions)
      columns = [CardQuery::CardNameColumn.new, CardQuery::CardNumberColumn.new, CardQuery::CardOrderColumn.new('updated_at')]
      @down_from_data = CardQuery.new(
          conditions: @down_from_query.conditions,
          columns: columns,
          order_by: [CardQuery::CardOrderColumn.new('updated_at')]
      ).values
      @down_from_value = @down_from_query.single_value.to_s.to_num
    end
  end

  def load_line_style(specified_style)
    if not_specified?(specified_style)
      @line_style = @chart.line_style
    else
      @line_style = specified_style.to_s.downcase
    end
    raise Series::Errors.incorrect_line_style unless ['dash', 'solid'].include?(@line_style)
  end

  def load_line_width(specified_width)
    if specified?(specified_width) && specified_width.to_i > 0
      @line_width = specified_width.to_i
    else
      @line_width = @chart.line_width
    end
  end

  def load_trend(specified_value)
    if not_specified?(specified_value)
      @trend = @chart.trend
    else
      stringified_value = specified_value.to_s.downcase
      unless ['true', 'false'].include?(stringified_value)
        raise Series::Errors.incorrect_trend_parameter
      end
      @trend = stringified_value == 'true' ? true : false
    end
  end

  def load_trend_line_style(specified_style)
    if not_specified?(specified_style)
      @trend_line_style = @chart.trend_line_style
    else
      @trend_line_style = specified_style.to_s.downcase
    end
    unless ['dash', 'solid'].include?(@trend_line_style)
      raise Series::Errors.incorrect_trend_line_style_parameter
    end
  end

  def load_trend_line_color(specified_color)
    @trend_line_color =  Chart.color(specified_color)
    @trend_line_color = Chart.color(@chart.trend_line_color) if @trend_line_color == -1
  end

  def load_trend_line_width(specified_width)
    if specified?(specified_width) && specified_width.to_i > 0
      @trend_line_width = specified_width.to_i
    else
      @trend_line_width = @chart.trend_line_width
    end
  end

  def load_trend_ignore(specified_value)
    if not_specified?(specified_value)
      @trend_ignore = @chart.trend_ignore
    else
      @trend_ignore = specified_value.to_s.downcase
      unless [TREND_IGNORE_NONE, TREND_IGNORE_ZEROES_AT_END, TREND_IGNORE_ZEROES_AT_END_AND_LAST_VALUE].include?(@trend_ignore)
        raise Series::Errors.incorrect_trend_ignore_parameter
      end
    end
  end

  def load_trend_scope(specified_value)
    if not_specified?(specified_value)
      @trend_scope = @chart.trend_scope
    else
      @trend_scope = specified_value.to_s.downcase
      unless @trend_scope == TREND_SCOPE_ALL || (@trend_scope.to_i > 0 && @trend_scope.to_i == @trend_scope.to_f)
        raise Series::Errors.incorrect_trend_scope_parameter
      end
    end
  end

  def load_data_point_symbol(specified_symbol)
    @data_point_symbol = specified_symbol.blank? ?  @chart.data_point_symbol : specified_symbol.to_s.downcase
    raise Series::Errors.incorrect_data_point_symbol_parameter unless (@data_point_symbol.blank? || DATA_POINT_SYMBOLS.include?(@data_point_symbol))
  end

  def load_data_labels(specified_value)
    if not_specified?(specified_value)
      @data_labels = @chart.data_labels
    else
      stringified_value = specified_value.to_s.downcase
      unless ['true', 'false'].include?(stringified_value)
        raise Series::Errors.incorrect_data_labels_parameter
      end
      @data_labels = stringified_value == 'true' ? true : false
    end
  end

  def specified?(value)
    !value.nil?
  end

  def not_specified?(value)
    value.blank?
  end

  def to_hash
    Hash[*self.class.parameters_definitions.map { |param_def| [param_def.name, self.send(param_def.name)] }.flatten]
  end

  def ==(other)
    has_same_number_of_parameters = (self.class.parameter_definitions.size == other.class.parameter_definitions.size)
    has_all_the_same_parameter_values = self.class.parameter_definitions.all? do |parameter_definition|
      self.send(parameter_definition.name) == other.send(parameter_definition.name)
    end
    has_same_number_of_parameters && has_all_the_same_parameter_values
  end

  def inspect
    to_s
  end

  def to_s
    self.class.parameter_definitions.collect do |pd|
      "#{pd.name}: #{self.send(pd.name)}" unless self.send(pd.name).blank?
    end.compact.join("\n")
  end

  def color_value
    hidden ? Charts::C3Renderers::ColorPalette::Colors::TRANSPARENT : color.strip
  end

  private

  def start_and_end_index
    start_index = 0
    end_index = values.size - 1

    if [TREND_IGNORE_ZEROES_AT_END, TREND_IGNORE_ZEROES_AT_END_AND_LAST_VALUE].include?(@trend_ignore)
      end_index -= 1 while @uncumulated_data[end_index] == 0
    end
    end_index -= 1 if @trend_ignore == TREND_IGNORE_ZEROES_AT_END_AND_LAST_VALUE

    start_index = (end_index - @trend_scope.to_i + 1) if @trend_scope.to_i > 0
    start_index = 0 if start_index < 0
    return start_index, end_index
  end

  def filter_trend_data(data, options = {})
    start_index, end_index = start_and_end_index
    options[:default_trend_value] ||= 0
    options[:trend_data_count]  ||= end_index.next
    trend_data = [ options[:default_trend_value] ] * options[:trend_data_count]
    start_index.upto(end_index) {|i| trend_data[i] = data[i]}
    trend_data
  end
end
