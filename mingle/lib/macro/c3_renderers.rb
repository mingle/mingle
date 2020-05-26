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

class C3Renderers
  class << self
    def pie_chart_renderer(chart_width, chart_height)
      Charts::C3Renderers::PieChartRenderer.new(chart_width, chart_height)
    end

    def stack_bar_chart_renderer(chart_width, chart_height, *_)
      Charts::C3Renderers::StackedBarChartRenderer.new(chart_width, chart_height)
    end

    def ratio_bar_chart_renderer(chart_width, chart_height)
      Charts::C3Renderers::RatioBarChartRenderer.new(chart_width, chart_height)
    end

    def data_series_chart_renderer(chart_width, chart_height, *_)
      Charts::C3Renderers::DataSeriesChartRenderer.new(chart_width, chart_height)
    end

    def cumulative_flow_graph_renderer(chart_width, chart_height, *_)
      Charts::C3Renderers::CumulativeFlowGraphRenderer.new(chart_width, chart_height)
    end

    def daily_history_chart_renderer(chart_width, chart_height, *_)
      Charts::C3Renderers::DailyHistoryChartRenderer.new(chart_width, chart_height)
    end

  end
end
