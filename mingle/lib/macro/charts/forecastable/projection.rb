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
  module Forecastable
    class Projection
      def self.create(current_scope, current_completion, forecast_point, x)
        return nil if x < current_scope[0]
        return nil if x == current_scope[0] && x == current_completion[0] && current_scope[1] == current_completion[1]
        return nil if x > forecast_point[0]

        scope_projection_y = Line.new(current_scope, forecast_point).y(x)
        completion_projection_y = Line.new(current_completion, forecast_point).y(x)
        new(current_scope, current_completion, [x, scope_projection_y], [x, completion_projection_y], x)
      end

      attr_reader :x
      def initialize(current_scope, current_completion, scope_projection, completion_projection, x)
        @current_scope, @current_completion, @scope_projection, @completion_projection, @x = current_scope, current_completion, scope_projection, completion_projection, x
      end

      def scope_projection_segment
        [@current_scope, @scope_projection]
      end
      def completion_projection_segment
        [@current_completion, @completion_projection]
      end
      
      def gap
        {
          :end_point => @scope_projection,
          :start_point => @completion_projection,
          :label => (y(@scope_projection) - y(@completion_projection)).round.to_s,
          :label_position => [@x, (y(@scope_projection) + y(@completion_projection))/2]
        }
      end

      private
      def y(point)
        point[1]
      end
    end
  end
end
