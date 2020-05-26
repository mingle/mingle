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
  module Chart
    def self.included(base)
      base.send(:include, InstanceMethods)
      base.send(:extend, ClassMethods)
    end
  end

  module ClassMethods
    def default_chart_width
      Style::Sizes.default_width_for(self.chart_type)
    end

    def default_chart_height
      Style::Sizes.default_height_for(self.chart_type)
    end
  end

  module InstanceMethods
    def chart_callback(params)
      chart_id = chart_id(params[:position])
      chart_id += '-preview' if params[:preview]
      output = "<div id='#{chart_id}' class='#{chart_class} #{evaluate_chart_size}' style='margin: 0 auto; width: #{chart_width}px; height: #{chart_height}px'></div>"
      output << %Q{
    <script type="text/javascript">
      var dataUrl = '#{view_helper.url_for(params.merge({:action => 'chart_data', :escape => false}))}'
      var bindTo = '##{chart_id}'
      ChartRenderer.renderChart('#{chart_name}', dataUrl, bindTo);
    </script>}
      output
    end

    def generate
      generate_chart(::C3Renderers)
    end

    private

    def chart_class
      self.class.chart_type
    end

    def chart_name
      chart_class.gsub('-', '_').camelize(:lower)
    end

    def source
      content_provider.class.name.gsub(':', '-')
    end

    def chart_id(position)
      "#{chart_class.gsub('-','')}-#{source}-#{content_provider.id}-#{position}"
    end
  end
end
