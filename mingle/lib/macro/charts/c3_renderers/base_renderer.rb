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

module Charts
  module C3Renderers
    class BaseRenderer

      def initialize(chart_width, chart_height)
        @chart_options = default_chart_options
        set_dimensions(chart_width, chart_height)
      end

      def set_region_data(region_data)
        @chart_options[:region_data] = region_data
      end

      def set_region_mql(region_mql)
        @chart_options[:region_mql] = region_mql
      end

      def set_title(text)
        @chart_options[:title] = { :text => text }
      end

      def set_legend_position(legend_position)
        @chart_options[:legend][:position]  = legend_position
      end

      def make_chart
        @chart_options.to_json
      end

      private

      def default_chart_options
        {data: {:columns => [],
                :type => type,
                :order => nil},
         legend: {}}
      end

      def set_dimensions(width, height)
        @chart_options[:size] = {:width => width, :height => height}
      end

      def type
        ''
      end

      def self.define_compatibility_methods(*methods)
        methods.each do |method|
          define_method(method.to_sym) {|*_| self}
        end
      end
    end
  end
end
