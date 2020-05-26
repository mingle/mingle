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

class RatioBarChart < Chart
  include EasyCharts::Style
  include EasyCharts::ChartSizeHelper
  include EasyCharts::Chart

  def self.chart_type
    'ratio-bar-chart'
  end

  parameter :totals,              :required => true,        :example => "SELECT property, aggregate WHERE condition"
  parameter :restrict_ratio_with, :required => true,        :computable => true, :compatible_types => [:string], :example => "condition"
  parameter :color,               :default => "LightBlue",  :computable => true, :compatible_types => [:string], :type => SimpleParameterInput::COLOR_PALETTE, :initial_value => '#FF0000'
  parameter :x_title,             :computable => true, :compatible_types => [:string], :default => ''
  parameter :y_title,             :computable => true, :compatible_types => [:string], :default => ''
  parameter :three_d, :default => false, :computable => true, :compatible_types => [:string], :type => ParameterRadioButton.new(%w(true false)), :initial_value => false
  parameter :title,               :computable => true, :compatible_types => [:string], :default => ''
  parameter :show_guide_lines,    :default => true, :compatible_types => [:string]
  parameter :chart_size,          :default => Sizes::DEFAULT, :computable => true, :compatible_types =>[:string], :values => Sizes::ALL

  include ChartStyle::Parameters
  parameter :project

  attr_reader :region_data, :region_mql

  def initialize(*args)
    super
    @totals = CardQuery.parse(totals, card_query_options)
    @totals.cast_numeric_columns = true
    @region_data = {}
    @region_mql = { 'conditions' => {}, 'project_identifier' => ''}
    columns_count = @totals.columns.size
    raise "A two-dimensional (two columns) query must be supplied for the totals. The totals contains #{'columns'.enumerate(columns_count)}" unless columns_count == 2
    @ratios = @totals.restrict_with(restrict_ratio_with, :cast_numeric_columns => true)

    @color = Chart.color(color)

    extract_data(@ratios, @ratios.values_as_pairs)

    if @ratios.columns.first.respond_to?(:numeric?) && @totals.columns.first.numeric?
      property_definition = @totals.columns.first.property_definition
      set_unique_labels(property_definition.project, unique_numeric_values_for(property_definition))
    end

    replace_nil_labels

    self.chart_width = self.chart_width.to_i if self.chart_width.is_a?(String)
    self.chart_height = self.chart_height.to_i if self.chart_height.is_a?(String)
    self.label_font_angle = self.label_font_angle.to_i if self.label_font_angle.is_a?(String)
    update_chart_size if default_dimensions?
  end

  def can_be_cached?
    @totals.can_be_cached?
  end

  def totals_data
    @totals_data ||= @totals.values_as_pairs.collect do |pair|
      unless pair.first.blank?
        first = pair.first.respond_to?(:strip) ? pair.first.strip : pair.first
        [first, pair.last]
      end
    end.compact
  end

  def ratios_data
    @ratios_data ||= @ratios.values_as_coords.inject({}) do |result, pair|
      unless pair.first.blank?
        first = pair.first.respond_to?(:strip) ? pair.first.strip : pair.first
        result[first] = pair.last
      end
      result
    end
  end

  def labels
    first_column = @totals.columns.first
    x_labels = if first_column.respond_to?(:numeric?) && first_column.numeric?
      unique_numeric_values_for(first_column.property_definition).compact
    else
      totals_data.collect { |d| project.to_num_maintain_precision(d.first) }
    end
    x_labels.map(&:to_s)
  end

  def unique_numeric_values_for(prop_def)
    super.compact.select { |v| totals_data.collect {|pair| BigDecimal.new(pair.first)}.include?(BigDecimal.new(v)) }
  end

  def data
    totals_data.collect do |label, total|
      if total == 0
        0
      else
        (((ratios_data[label] || 0).to_f / total.to_f) * 100).to_i
      end
    end
  end

  def do_generate(renderers)
    renderer = renderers.ratio_bar_chart_renderer(chart_width, chart_height)
    renderer.add_titles_to_axes(x_title, y_title)
    renderer.set_title(title)
    renderer.set_region_mql(region_mql)
    renderer.add_bars(data, color)
    renderer.set_region_data(region_data)
    renderer.set_x_axis_labels(labels, font, label_font_angle)
    renderer.show_guide_lines if show_guide_lines
    renderer.make_chart
  end
end


private
def chart_id(position)
  "ratiobarchart-#{source}-#{content_provider.id}-#{position}"
end


Macro.register(RatioBarChart.chart_type, RatioBarChart)
