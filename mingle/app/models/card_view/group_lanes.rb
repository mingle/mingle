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

  class GroupLanes
    include GridViewOptions
    include GridViewCards
    include GroupingSupport
    include VisibilitySupport

    attr_reader :lane_property_definition, :row_property_definition, :project

    def self.create(view, params)
      GroupLanes.new(view, params)
    end

    def initialize(view, params)
      @project = view.project
      @view = view
      view.groups = self
      init_options(params)
    end

    def grouped?
      (lane_property_definition || row_property_definition).present?
    end

    def empty?
      lane_property_definition ? lane_property_definition.property_values.empty? : true
    end

    def reset_lanes
      clear_cached_results_for(:lanes)
    end

    def not_set_lane
      lane(PropertyValue::NOT_SET_LANE_IDENTIFIER)
    end

    def supports_direct_manipulation?(dimension)
      property = send(:"#{dimension}_property_definition")
      %w{EnumeratedPropertyDefinition UserPropertyDefinition TreeRelationshipPropertyDefinition CardTypeDefinition}.include?(property.class.name)
    end

    def lane_restriction_query
      return if @lanes_param.blank?
      not_set_lane_params, set_lanes_params = @lanes_param.partition(&:blank?)
      queries = []
      if set_lanes_params.any?
        numbers = lane_property_definition.kind_of?(TreeRelationshipPropertyDefinition) ? "NUMBERS" : ""
        queries << "'#{lane_property_definition.name}' #{numbers} IN (#{set_lanes_params.collect { |l| "'#{l.gsub(/(['"])/, '\\\\\1')}'" }.join(', ')})"
      end
      queries << "'#{lane_property_definition.name}' IS NULL" if not_set_lane_params.any?
      CardQuery.parse(queries.join(' OR '))
    end

  end
end
