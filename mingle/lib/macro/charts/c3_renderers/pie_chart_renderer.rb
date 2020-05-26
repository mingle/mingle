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
    class PieChartRenderer < BaseRenderer

      def add_text(text)
        @chart_options[:title] = {:text => text}
      end

      # Approx scaling of height based on radius.
      def set_radius(radius)
        @chart_options[:size] = { :height => (radius * 2.1)} if radius && radius > 0
      end

      def set_data(data)
        @chart_options[:data][:columns] = data
      end

      def set_label_type(label_type)
        @chart_options[:label_type] = label_type
      end
      private

      def type
        'pie'
      end
    end
  end
end
