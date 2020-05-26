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

module CardView
  module VisibilitySupport

    def visibles(dimension)
      if dimension == :all
        (lanes + rows).select(&:visible)
      else
        method_name = dimension.to_s.pluralize.to_sym
        send(method_name).select(&:visible)
      end
    end

    def show_dimension_params(dimension, identifier)
      dimension = dimension.to_s.pluralize.to_sym
      d_params = RoundtripJoinableArray.from_array(visibles(dimension).map(&:identifier) + [identifier])
      new_view_params_with(dimension => d_params.to_s)
    end

    def hide_dimension_params(dimension, identifier)
      dimension = dimension.to_s.pluralize.to_sym
      d_params = RoundtripJoinableArray.from_array(visibles(dimension).map(&:identifier) - [identifier])
      new_view_params_with(dimension => d_params.to_s)
    end

    def new_view_params_with(params)
      @view.to_params.merge(self.to_params).merge(params)
    end

  end
end
