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

class CumulativeFlowGraph < StackBarChart

  parameter :conditions,    :default => '',     :computable => true, :compatible_types => [:string], :example => 'type = card_type', :initially_shown => true
  parameter :cumulative,    :default => true,  :computable => true, :compatible_types => [:string]
  parameter :x_label_start,                     :computable => true
  parameter :x_label_end,                       :computable => true
  parameter :x_label_step,                      :computable => true, :compatible_types => [:numeric]
  parameter :x_title,                           :computable => true, :compatible_types => [:string]
  parameter :y_title,                           :computable => true, :compatible_types => [:string]
  parameter :labels,        :default => '',                                                        :example => "SELECT DISTINCT property",                 :initially_shown => true
  parameter :x_labels_tree, :default => '',     :computable => true, :compatible_types => [:string]
  parameter :three_d,       :default => false,  :computable => true, :compatible_types => [:string], :type => ParameterRadioButton.new(['true', 'false']), :initial_value => false
  parameter :data_point_symbol, :default => 'none', :computable => true, :compatible_types => [:string], :type => ParameterRadioButton.new(['none', 'square', 'diamond']), :initial_value => 'none'
  parameter :data_labels, :default => false, :computable => true, :compatible_types => [:string], :type => ParameterRadioButton.new(['true', 'false']), :initial_value => false
  include ChartStyle::Parameters, ChartStyle::ParametersForLegend
  parameter :project

  parameter :series,   :required => true, :list_of => Series
  attr_reader :region_data, :region_mql
  parameter :title,               :computable => true, :compatible_types => [:string], :default => ''
  parameter :show_guide_lines,    :default => true, :compatible_types => [:string]
  parameter :legend_position,     :default => LegendPosition::DEFAULT, :computable => true, :compatible_types =>[:string], :values => LegendPosition::ALL
  parameter :chart_size,          :default => Sizes::DEFAULT, :computable => true, :compatible_types =>[:string], :values => Sizes::ALL

  def self.chart_type
    'cumulative-flow-graph'
  end

  def chart_type
    'area'
  end

  private
  def chart_id(position)
    "#{self.class.chart_type}-#{source}-#{content_provider.id}-#{position}"
  end

  def renderer(renderers)
    renderers.cumulative_flow_graph_renderer(chart_width, chart_height)
  end

  def add_line_series(renderer)
    line_series.each do |series|
      color = series.color
      color = renderer.dash_line_color(color) if series.line_style == 'dash'
      series_renderer = renderer.add_line(series_data_for_plot(series.label), color, series.label)
      series_renderer.set_data_symbol(series.data_point_symbol) if series.data_point_symbol
      series_renderer.set_data_label_format if series.set_data_label_format?
      series_renderer.set_3d if three_d
      series_renderer.set_line_width(3)
    end
  end

  def add_area_series(renderer)
    area_series.each do |series|
      layer = renderer.add_area_layer
      layer.add_data_set(series_data_for_plot(series.label), series.color, series.label)
      layer.set_data_symbol(series.data_point_symbol) if series.data_point_symbol
      layer.set_data_label_format if series.set_data_label_format?
    end
  end
end

Macro.register(CumulativeFlowGraph.chart_type, CumulativeFlowGraph)

