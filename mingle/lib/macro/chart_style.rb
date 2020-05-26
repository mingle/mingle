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

module ChartStyle

  module Parameters
    def self.included(base)
      base.class_eval do
        parameter :chart_height,      :default => default_chart_height, :computable => true, :compatible_types => [:numeric]
        parameter :chart_width,       :default => default_chart_width, :computable => true, :compatible_types => [:numeric]
        parameter :plot_height,       :default => 220, :computable => true, :compatible_types => [:numeric]
        parameter :plot_width,        :default => 230, :computable => true, :compatible_types => [:numeric]
        parameter :plot_x_offset,     :default => 50,  :computable => true, :compatible_types => [:numeric]
        parameter :plot_y_offset,     :default => 10,  :computable => true, :compatible_types => [:numeric]
        parameter :label_font_angle,  :default => 45,  :computable => true, :compatible_types => [:numeric]
      end
    end
  end

  module ParametersForLegend
    def self.included(base)
      base.class_eval do
        parameter :legend_top_offset, :default => 5,   :computable => true, :compatible_types => [:numeric]
        parameter :legend_offset,     :default => 20,  :computable => true, :compatible_types => [:numeric]
        parameter :legend_max_width,  :default => 120, :computable => true, :compatible_types => [:numeric]
      end
    end
  end
end
