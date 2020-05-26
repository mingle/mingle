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

module EasyCharts
  class PieChartMacroParams
    attr_reader :data, :project, :chart_size, :title, :label_type, :legend_position

    def initialize(data_mql, params)
      @data = data_mql
      @project = params[:project]
      set_chart_size(params)
      @title = params[:title]
      @label_type = params['label-type']
      @legend_position = params['legend-position']
    end

    class << self
      def from(macro_params)
        macro_params[:project] ||= Project.current.identifier
        begin
          data_mql = nil
          project = Project.accessible_projects_without_templates_for(User.current).find {|p| p.identifier == macro_params[:project] }
          return self.new(data_mql, macro_params) if project.nil?
          project.with_active_project do
            data_mql = ChartMql.from(CardQuery.parse(macro_params[:data]))
          end
        rescue EasyCharts::InvalidChartMqlException, CardQuery::Column::PropertyNotExistError =>  e
          Rails.logger.debug(e.message)
        end

        self.new(data_mql, macro_params)
      end

      def partial_name
        '_pie_chart_macro_params'
      end
    end

    def supported_in_easy_charts?
      @data.present?  && @has_defined_chart_size
    end

    private

    def set_chart_size(params)
      if %w(small medium large).include? params['chart-size']
        @chart_size = params['chart-size']
        @has_defined_chart_size = true
      elsif params['chart-height'].present? && params['chart-width'].present?
        size = {chart_height: params['chart-height'].to_i, chart_width: params['chart-width'].to_i}
        @chart_size = Style::Sizes::CHART_SIZES['pie-chart'].key(size)
        @has_defined_chart_size = @chart_size.present?
      else
        @has_defined_chart_size = !(@chart_size || params[:radius] || params['chart-width'] || params['chart-height'])
      end
    end
  end
end
