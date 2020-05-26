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

require 'macro/parameter_definition'

require 'macro/macro'

require 'macro/parameter_radio_button'
require 'macro/simple_parameter_input'

require 'macro/project_macro'
require 'macro/project_variable_macro'
require 'macro/two_columns_macro'
require 'macro/left_column_macro'
require 'macro/right_column_macro'
require 'macro/dashboard_panel_macro'
require 'macro/dashboard_half_panel_macro'
require 'macro/chart_caching'
require 'macro/async_macro'
require 'macro/table_macro'
require 'macro/pivot_table_macro'
require 'macro/value_macro'
require 'macro/panel_heading'
require 'macro/panel_content'
require 'macro/iframe_macro'

require 'macro/charts/series_chart_interactivity.rb'
require 'macro/easy_charts/chart_condition'
require 'macro/easy_charts/chart_mql'
require 'macro/easy_charts/pie_chart_macro_params'
require 'macro/easy_charts/macro_params'
require 'macro/easy_charts/style'
require 'macro/easy_charts/chart_size_helper'
require 'macro/easy_charts/chart'
require 'macro/chart'
require 'macro/series'
require 'macro/data_series_chart'
require 'macro/x_axis_labels'
require 'macro/ratio_bar_chart'
require 'macro/stack_bar_chart'
require 'macro/cumulative_flow_graph'
require 'macro/daily_history_series'

require 'macro/charts/forecastable.rb'

require 'macro/charts/c3_renderers/base_renderer'
require 'macro/charts/c3_renderers/color_palette'
require 'macro/charts/c3_renderers/xy_chart_renderer'
require 'macro/charts/c3_renderers/series_chart_renderer'
require 'macro/charts/c3_renderers/pie_chart_renderer'
require 'macro/charts/c3_renderers/ratio_bar_chart_renderer'
require 'macro/charts/c3_renderers/stacked_bar_chart_renderer'
require 'macro/charts/c3_renderers/data_series_chart_renderer'
require 'macro/charts/c3_renderers/cumulative_flow_graph_renderer'
require 'macro/charts/c3_renderers/daily_history_chart_renderer'
require 'macro/c3_renderers'
require 'macro/param_definition_section'

require 'macro/daily_history_chart'
require 'macro/daily_history_cache'
require 'macro/property_selection'
require 'macro/pie_chart'

require 'macro/text_chart_renderers'

Dir.glob(File.join(Rails.root, "lib", "macro", "model_loaders", "*.rb")).each do |file|
  require file
end
