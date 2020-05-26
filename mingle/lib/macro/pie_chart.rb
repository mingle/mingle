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

class PieChart < Chart
  include EasyCharts::Style
  include EasyCharts::ChartSizeHelper
  include EasyCharts::Chart

  def self.chart_type
    'pie-chart'
  end

  parameter :data, :required => true, :computable => true, :compatible_types => [:string], :example => "SELECT property, aggregate WHERE condition"
  parameter :project

  # Set the width of the box to 440, the height to 300; centre the circle at 220 x 150, use a radius of 100
  parameter :chart_width, :default => self.default_chart_width, :computable => true, :compatible_types => [:numeric]
  parameter :chart_height, :default => self.default_chart_height, :computable => true, :compatible_types => [:numeric]
  parameter :radius, :computable => true, :compatible_types => [:numeric]
  parameter :title, :default => '', :computable => true, :compatible_types => [:string]
  parameter :chart_size, :default => Sizes::DEFAULT, :computable => true, :compatible_types =>[:string], :values => Sizes::ALL
  parameter :label_type, :default => LabelTypes::DEFAULT, :computable => true, :compatible_types =>[:string], :values => LabelTypes::ALL
  parameter :legend_position, :default => LegendPosition::DEFAULT, :computable => true, :compatible_types =>[:string], :values => LegendPosition::ALL


  attr_reader :region_data, :region_mql

  def initialize(*args)
    super
    @region_data = {}
    @region_mql = { 'conditions' => {}, 'project_identifier' => ''}

    @data_query = CardQuery.parse(data, card_query_options)

    if @data_query.columns.size < 2
      raise "Must provide a property and an aggregate, e.g. SELECT status, SUM(size)"
    end
    numeric_first_column = @data_query.columns.first.respond_to?(:numeric?) && @data_query.columns.first.numeric?
    property_definition = nil

    if numeric_first_column
      @data_query.cast_numeric_columns = true
      property_definition = @data_query.columns.first.property_definition
      @unique_numeric_labels = unique_numeric_values_for(property_definition)
    end

    self.chart_height = self.chart_height.to_i if self.chart_height.is_a?(String)
    self.chart_width = self.chart_width.to_i if self.chart_width.is_a?(String)

    update_chart_size if default_dimensions?
    @data = @data_query.values_as_pairs
    extract_data

    if numeric_first_column
      project = property_definition.project
      set_unique_labels(project, @unique_numeric_labels)
    end

    replace_nil_labels
  end

  def can_be_cached?
    @data_query.can_be_cached?
  end

  def do_generate(renderers)
    renderer = renderers.pie_chart_renderer(chart_width.to_i, chart_height.to_i)
    if @data.collect(&:first).uniq.size != @data.size && @data_query.columns[1] && !@data_query.columns[1].is_a?(CardQuery::AggregateFunction)
      @data_query.columns[1] = CardQuery::AggregateFunction.new('SUM', @data_query.columns[1])
      renderer.add_text "Did you mean: #{@data_query.to_s}"
    end

    renderer.set_radius(radius.to_i)
    renderer.set_data(data)
    renderer.set_title(title)
    renderer.set_region_data(region_data)
    renderer.set_region_mql(region_mql)
    renderer.set_label_type(label_type)
    renderer.set_legend_position(legend_position)
    renderer.make_chart
  end


end

Macro.register(PieChart.chart_type, PieChart)
