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

class DailyHistorySeries
  include Macro::ParameterSupport

  DEFAULT_LABEL = 'All'

  parameter "conditions", :initially_shown => true, :example => "type = card_type"
  parameter "label",      :computable => true,      :compatible_types => [:string], :initially_shown => true
  parameter "color",      :computable => true,      :compatible_types => [:string], :initially_shown => true, :type => SimpleParameterInput::COLOR_PALETTE, :initial_value => '#FF0000'
  parameter "line_width", :computable => true,      :compatible_types => [:numeric]

  def initialize(chart, specification, card_query_options = {})
    @chart = chart
    @parameters = specification || {}
    @content_provider = card_query_options[:content_provider]
    initialize_parameters_from(chart, specification, card_query_options)
    self.color = Chart.color(color)

    validate!
  end

  def validate!
    raise 'Project parameter is not allowed for the daily history chart' if @parameters['project']
  end

  def mql_query(as_of)
    @chart.restricted_series_conditions_as_of(as_of, conditions)
  end

  def value_at(as_of)
    mql_query(as_of).single_values.first
  end

  def color_undefined?
    @color == -1
  end

  def line_width
    @line_width || @chart.line_width
  end

  def label
    (@label || @conditions || DEFAULT_LABEL).to_s
  end
end
