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

 class DailyHistoryChart < Chart
  include Charts::Forecastable
  include EasyCharts::Style
  include EasyCharts::ChartSizeHelper
  include EasyCharts::Chart
  def self.process_asynch
    # saas env may need this for a while
  end

  def self.process(options={})
    DailyHistoryChartProcessor.run_once(options)
  end

  def self.chart_type
    'daily-history-chart'
  end

  parameter :aggregate,         :required => true,        :example => "SUM ('numeric property name')"
  parameter :start_date,        :required => true,        :computable => true, :compatible_types => [:date]
  parameter :end_date,          :required => true,        :computable => true, :compatible_types => [:date]
  parameter :chart_conditions,  :initially_shown => true, :example => "type = card_type"
  parameter :series,            :required => true,        :list_of => ::DailyHistorySeries
  parameter :x_title,                                     :computable => true, :compatible_types => [:string]
  parameter :y_title,                                     :computable => true, :compatible_types => [:string]
  parameter :line_width,                                  :computable => true, :compatible_types => [:numeric]
  parameter :x_labels_step,     :default => 1,            :computable => true, :compatible_types => [:numeric]

  parameter :scope_series
  parameter :completion_series
  parameter :target_release_date,                         :computable => true, :compatible_types => [:date]
  parameter :show_guide_lines,   :default => true,        :compatible_types => [:string], :easy_charts => true
  parameter :chart_size, :default => Sizes::DEFAULT, :computable => true, :compatible_types => [:string], :easy_charts => true, :values => Sizes::ALL
  parameter :title, :computable => true, :compatible_types => [:string], :default => ''
  parameter :legend_position, :default => LegendPosition::DEFAULT, :computable => true, :compatible_types => [:string], :easy_charts => true, :values => LegendPosition::ALL

  include ChartStyle::Parameters
  include ChartStyle::ParametersForLegend

  convert_parameter :x_axis_start_date, :from => :start_date, :as => :date
  convert_parameter :x_axis_end_date, :from => :end_date, :as => :date
  convert_parameter :mark_target_release_date, :from => :target_release_date, :as => :date

  validate :no_project_parameter, :message => "#{'Project'.bold} parameter is not allowed for the daily history chart", :block => true
  validate :start_date_must_be_before_end_date, :message => "#{'start-date'.bold} must be before #{'end-date'.bold}.", :if => :using_this_card_in_defaults?
  validate :start_date_must_be_before_target_release_date, :message => "#{'start-date'.bold} must be before #{'target-release-date'.bold}.", :if => :using_this_card_in_defaults?
  validate :chart_conditions_aggregate_and_series_conditions
  validate :x_labels_step_should_be_a_number, :message => "#{'x-labels-step'.bold} must be a number"
  validate :x_labels_step_should_bigger_than_zero, :message => "#{'x-labels-step'.bold} must bigger than zero"
  validate :scope_exists
  validate :completion_exists
  validate :burn_up_chart_with_target_release_date, :message =>"'scope-series' and 'completion-series' are required to show burnup chart with target-release-date."
  validate :start_date_and_end_date_range, :message => "#{'start-date'.bold} and #{'end-date'.bold} are more than 5 years apart."
  validate :start_date_and_target_release_date_range, :message => "#{'start-date'.bold} and #{'target-release-date'.bold} are more than 5 years apart."

  def initialize(*args)
    super
    self.chart_width = self.chart_width.to_i if self.chart_width.is_a?(String)
    self.chart_height = self.chart_height.to_i if self.chart_height.is_a?(String)
    self.label_font_angle = self.label_font_angle.to_i if self.label_font_angle.is_a?(String)
    update_chart_size if default_dimensions?
  end

  def chart_callback(params)
    return super if preview_mode?
    chart_id = chart_id(params[:position])
    chart_id += '-preview' if params[:preview]
    output = "<div id='#{chart_id}' class='#{chart_class} #{evaluate_chart_size}' style='margin: 0 auto'></div>"
    output << %Q{
    <script type="text/javascript">
      var dataUrl = '#{view_helper.url_for(params.merge({:action => 'chart_data', escape: false}))}'
      var bindTo = '##{chart_id}'
      ChartRenderer.renderChart('#{chart_name}', dataUrl, bindTo);
    </script>}
    output
  end

  def publish
    DailyHistoryChartProcessor.send_message(project, @context[:content_provider], @raw_content)
  end

  def generate_cache_data(start_time = Clock.now, timeout = 30)
    return if ready?
    cached_data_dates.each do |date|
      if Clock.now - start_time >= timeout
        Rails.logger.info "*****Cache Timed Out. Publishing a message. Cache data created/fetched until #{date}****"
        publish
        break
      end

      Rails.logger.debug { "[daily history chart] processing #{date}"}
      cache.save(date) do
        values = self.series.collect do |series|
          series.value_at(date) || 0
        end
        Rails.logger.debug { "[daily history chart] query data from database for #{date}: #{values.inspect}"}
        values
      end
    end
  end

  def ready?
    @x_axis_start_date <= project.today && cache.cached_data_count == cached_data_dates.size
  end

  def progress
    [cache.cached_data_count, cached_data_dates.size]
  end

  def restricted_series_conditions_as_of(as_of, series_conditions)
    base_mql_query(as_of).restrict_with(series_conditions)
  end

  def data_symbol
    @x_axis_start_date == project.today ? 'diamond' : 'none'
  end

  def setup_canvas_and_axes(renderers)
    renderer = renderers.daily_history_chart_renderer(c3_chart_width, chart_height, font, plot_x_offset, plot_y_offset, plot_width, plot_height)
    renderer.add_legend(plot_width, plot_x_offset, legend_offset, legend_top_offset, legend_max_width)
    renderer.add_titles_to_axes(x_title || "Date", y_title || aggregate_title)
    _x_axis_values = x_axis_values
    renderer.set_x_axis_labels(_x_axis_values, font, label_font_angle, {type: 'timeseries', format: project.date_format})
    renderer.set_x_axis_label_step(x_labels_step)
    renderer
  end

  def do_generate(renderers)
    publish if(!preview_mode? && !ready?)
    renderer = setup_canvas_and_axes(renderers)
    renderer.set_message(message) if (preview_mode? || !ready?)
    ensure_colors_for_all_series(renderer)
    renderer.set_x_values(x_axis_values.map(&:to_epoch_milliseconds), '_$xForAll', *line_series.map(&:label))
    if forecast?(scope_series, completion_series, velocity)
      if ready? && !preview_mode?
        render_forecast(renderer)
      end
    else
      if show_completion_unknown_legend?
        renderer.add_legend_key('Completion Unknown', @x_axis_end_date.to_epoch_milliseconds, '_$xFor Completion Unknown')
        add_hidden_series_to_show_all_x_values(renderer, x_axis_values)
      end
    end
    draw_lines(renderer, series_values)
    renderer.show_guide_lines if show_guide_lines
    renderer.set_title(title)
    renderer.set_legend_position(legend_position)
    renderer.make_chart#_to_file('/tmp/test.png').tap{|f| %x[open '/tmp/test.png']}
  end

  def forecast_series_line?(series)
    completion_series &&  scope_series && [completion_series.downcase, scope_series.downcase].include?(series.label.downcase)
  end

  def draw_lines(renderer, values)
    line_series.each_with_index do |series, index|
      series_values = values[index]
      line_layer = renderer.add_line(series_values, series.color, series.label)
      line_layer.set_data_symbol(self.data_symbol)
      line_layer.set_line_width(series.line_width || line_width || 1)
      line_layer.enable_data_labels_on_selected_positions(series.label, series_values.size.pred) if forecast_series_line?(series)
    end
  end

  def series_index(label)
    series.index { |series| series.label.downcase == label.downcase }
  end

  def add_scatter_point(renderer, shape, color, point, size=10, label=nil)
    x = point[0]
    y = point[1]
    date_as_string = project.format_date(@x_axis_start_date + x)
    layer = renderer.add_scatter_layer([x], [y], label || date_as_string, shape, size, color, color)
    renderer.add_point_label(layer, date_as_string, HTML_COLORS["DimGray"])
  end

  def velocity
    Velocity.new(series_values[series_index(completion_series)]) if completion_series
  end

  def log(msg)
    Kernel.logger.info("[DAILY HISTORY CHART FORECAST] #{msg}")
  end

  def x_axis_values
    if forecast?(scope_series, completion_series, velocity) && !@mark_target_release_date
      p90_date = @x_axis_start_date + forecast_p90.first.round.to_i
      p50_date = @x_axis_start_date + forecast_p50.first.round.to_i
      p10_date = @x_axis_start_date + forecast_p10.first.round.to_i
      (@x_axis_start_date..@x_axis_end_date).to_a + [p10_date, p50_date, p90_date]
    elsif @mark_target_release_date
      (@x_axis_start_date..[@x_axis_end_date, @mark_target_release_date].max)
    else
      (@x_axis_start_date..@x_axis_end_date)
    end.to_a
  end

  def line_series
    series
  end

  def todays_values
    series.map do |s|
      [s.label, todays_value(s)]
    end
  end

  def series_values
    results = cached_series_values
    today = project.today
    line_series.each_with_index do |series, index|
      results[index] ||= []
      results[index] << series.value_at(today).to_i if (@x_axis_start_date..@x_axis_end_date).to_a.include?(today)
    end
    results
  end
  memoize :series_values

  def cached_series_values
    data = @context[:content_provider] ? cache.cached_data_values(cached_data_dates) : []
    line_series.collect_with_index do |series, index|
      data.collect { |datum| (datum && datum[index]) || 0 }
    end
  end

  def date_empty?
    (@x_axis_end_date.blank? || @x_axis_start_date.blank?)
  end

  def generate
    generate_chart(::C3Renderers)
  end

  private

  def c3_chart_width
    self.chart_width += 400 if scope_series && completion_series && !parameters.has_key?('chart-width')
    self.chart_width
  end

  def show_completion_unknown_legend?
    project_not_started? && ready?
  end

  def aggregate_title
    CardQuery.parse("Select #{aggregate}").columns.first.aggregate_name
  end

  def scope_series_values
    series_values[series_index(scope_series)]
  end

  def completion_series_values
    series_values[series_index(completion_series)]
  end

  def preview_mode?
    @context && @context[:preview]
  end

  def message
    if preview_mode?
      'Your daily history chart data will display upon inserting the chart'
    else
      'While Mingle is preparing all the data for this chart.'\
      ' Revisit this page later to see the complete chart. We calculate data for each day in your date range.' +
      " There are #{cached_data_dates.size} days in your date range. We have completed the computation for #{cache.cached_data_count} days so far."
    end
  end

  # This method seems to do the opposite of what it's name is.
  # Not sure why end with applying this rule to all cards
  def using_this_card_in_defaults?
    (@parameters["start-date"] !~ /this card/i &&  @parameters["end-date"] !~ /this card/i)
  end

  def project_not_started?
    completion_series && (velocity.invalid?)
  end

  def ensure_colors_for_all_series(renderer)
    color_palette_index = "FFFF0008".to_i(15)
    series.select(&:color_undefined?).each do |series|
      series.color = renderer.get_color(color_palette_index)
      color_palette_index = color_palette_index.next
    end
  end

  def last_coordinate_of_series(label)
    values = series_values[series_index(label)]
    [values.size - 1, values.last]
  end

  def color_for_series(label)
    candidates = series.select { |s| s.label.downcase == label.downcase }
    return nil if candidates.empty?
    candidates.first.color
  end

  def base_mql_query(as_of)
    as_of = Project.current.format_date(as_of) unless as_of.nil?
    if as_of == Project.current.format_date(Project.current.today) || as_of.nil?
      CardQuery.parse("SELECT #{aggregate}", card_query_options).restrict_with(chart_conditions_as_card_query)
    else
      CardQuery.parse("SELECT #{aggregate} AS OF '#{as_of}'", card_query_options).restrict_with(chart_conditions_as_card_query)
    end
  end
  memoize :base_mql_query

  def chart_conditions_as_card_query
    CardQuery.parse(chart_conditions, card_query_options)
  end
  memoize :chart_conditions_as_card_query

  def x_labels_step_should_be_a_number
    x_labels_step.to_s =~ /\d+/
  end

  def x_labels_step_should_bigger_than_zero
    x_labels_step.to_i > 0
  end

  def burn_up_chart_with_target_release_date
    return true unless target_release_date
    return true if series_exists?(scope_series) && series_exists?(completion_series)
    return false
  end

  def start_date_and_target_release_date_range
    return true if !@mark_target_release_date || !@x_axis_start_date
    @mark_target_release_date < @x_axis_start_date.to_time.advance(:years => 5).to_date
  end

  def start_date_and_end_date_range
    return true if !@x_axis_end_date || !@x_axis_start_date
    @x_axis_end_date < @x_axis_start_date.to_time.advance(:years => 5).to_date
  end

  def scope_exists
    series_valid('scope-series', scope_series)
  end

  def completion_exists
    series_valid('completion-series', completion_series)
  end

  def series_valid(param_name, series_label)
    return true if series_label.nil? || series_exists?(series_label)
    raise "#{param_name} #{series_label.bold} does not exist in given series: #{series.map(&:label).map(&:bold).join(", ")}"
  end

  def series_exists?(series_label)
    series_label && series_index(series_label)
  end

  def no_project_parameter
    !@parameters.has_key?('project')
  end

  def start_date_must_be_before_end_date
    return true if !@x_axis_end_date || !@x_axis_start_date
    @x_axis_start_date < @x_axis_end_date
  end

  def start_date_must_be_before_target_release_date
    return true if !@mark_target_release_date || !@x_axis_start_date
    @x_axis_start_date < @mark_target_release_date
  end

  def chart_conditions_aggregate_and_series_conditions
    base_query = base_mql_query(@x_axis_start_date)
    errors = [] + CardQuery::DailyHistoryChartValidations.new(base_query).execute
    result = series.map do |daily_series|
      errors += CardQuery::DailyHistoryChartValidations.new(CardQuery.parse(daily_series.conditions)).execute unless daily_series.conditions.blank?
      daily_series.mql_query(@x_axis_start_date).to_sql
    end
    raise errors.uniq.join(' ') if errors.any?
    result
  end

  def todays_value(series)
    series.value_at(project.today).to_i
  end

  def cache
    DailyHistoryCache.store(project, cache_path)
  end

  def cached_data_dates
    end_date = [@x_axis_end_date, (project.today - 1)].min
    (@x_axis_start_date..end_date).to_a
  end

  def cache_path
    content_provider = @context[:content_provider]
    sub_directory = this_card_values.empty? ? "" : make_one_line(this_card_values).sha1
    @cache_path ||= File.join(project.cache_key.structure_key, project.cache_key.card_key,
      content_provider.class.name, content_provider.id.to_s,
      make_one_line(@raw_content).sha1, sub_directory)
  end

  def make_one_line(string)
    string.gsub(/\n/m, '').gsub(/\r/m, '')
  end

  def this_card_values
    parameter_definitions.collect(&:this_card_property_display_value_resolved).compact.join(',')
  end
end

Macro.register('daily-history-chart', DailyHistoryChart)
