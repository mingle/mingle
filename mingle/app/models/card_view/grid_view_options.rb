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

  module GridViewOptions
    attr_reader :color_by, :grid_sort_by, :color_by_property_definition, :lane_property_definition, :row_property_definition, :rank_is_on, :group_by_param

    def init_options(params)
      @color_by = params[:color_by]
      @color_by_property_definition = @project.find_property_definition_or_nil(@color_by)
      @grid_sort_by = params[:grid_sort_by]

      if params[:aggregate_type]
        @column_aggregate_type = params[:aggregate_type][:column]
        @row_aggregate_type = params[:aggregate_type][:row]
      end

      if params[:aggregate_property]
        @column_aggregate_property = params[:aggregate_property][:column]
        @row_aggregate_property = params[:aggregate_property][:row]
      end

      @rank_is_on = (params[:rank_is_on].blank? || params[:rank_is_on] == true || params[:rank_is_on] == "true") && @grid_sort_by.blank? && @view.grid?
      @group_by_param = GroupByParam.new(params[:group_by])
      @lane_property_definition, @row_property_definition = @group_by_param.property_definitions(@project)

      if @lane_property_definition
        @lanes_specified = params.has_key?(:lanes)
        @lanes_param = RoundtripJoinableArray.from_str(params[:lanes] || "")
      end

      if @row_property_definition
        @rows_specified = params.has_key?(:rows)
        @rows_param = RoundtripJoinableArray.from_str(params[:rows] || "")
      end
    end

    def property_for(dimension)
      if dimension == :lane
        lane_property_definition
      elsif dimension == :row
        row_property_definition
      end
    end

    def column_aggregate_by
      Aggregate.column_from_params(@project, to_params)
    end

    def row_aggregate_by
      Aggregate.row_from_params(@project, to_params)
    end

    def aggregate_property
      @column_aggregate_property
    end

    def aggregate_type
      @column_aggregate_type
    end

    def to_params
      ({}).tap do |params|
        params[:group_by] = @group_by_param.param_value if @group_by_param.param_value
        params[:color_by] = @color_by if @color_by

        params[:aggregate_type] = {} if @column_aggregate_type || @row_aggregate_type
        params[:aggregate_type][:column] = @column_aggregate_type if @column_aggregate_type
        params[:aggregate_type][:row]  = @row_aggregate_type if @row_aggregate_type

        params[:aggregate_property] = {} if @column_aggregate_property || @row_aggregate_property
        params[:aggregate_property][:column] = @column_aggregate_property if @column_aggregate_property
        params[:aggregate_property][:row] = @row_aggregate_property if @row_aggregate_property

        params[:grid_sort_by] = @grid_sort_by if @grid_sort_by
        params[:lanes] = @lanes_param.to_s if @lanes_specified
        params[:rows] = @rows_param.to_s if @rows_specified
        params[:rank_is_on] = false if rank_explicitly_disabled?
      end
    end

    def rank_explicitly_disabled?
      !rank_is_on && grid_sort_by.blank? && @view.grid?
    end

    def group_by_transition_only_lane_property_definition?
      @lane_property_definition && @lane_property_definition.transition_only?
    end

    def rename_property(old_name, new_name)
      @group_by_param.rename_property(old_name, new_name)
      @color_by = new_name if @color_by.ignore_case_equal?(old_name)
      @grid_sort_by = new_name if @grid_sort_by.ignore_case_equal?(old_name)
      @column_aggregate_property = new_name if @column_aggregate_property.ignore_case_equal?(old_name)
      @row_aggregate_property = new_name if @row_aggregate_property.ignore_case_equal?(old_name)
    end

    # returning whether the view get updated
    def rename_property_value(property_name, old_value, new_value)
      if @group_by_param.lane_property_name.ignore_case_equal?(property_name) && @lanes_param.ignore_case_include?(old_value)
        @lanes_param.ignore_case_delete!(old_value)
        @lanes_param.push(new_value)
      end
    end

    def uses?(property_definition)
      [@color_by, @column_aggregate_property, @row_aggregate_property, @grid_sort_by].any?{|candidate| candidate.ignore_case_equal?(property_definition.name)} || @group_by_param.uses?(property_definition)
    end

    def uses_card_type?(card_type)
      @group_by_param.uses_property_value?(Project.card_type_definition.name, card_type.name, self)
    end

    def uses_property_value?(property_name, value)
      @group_by_param.uses_property_value?(property_name, value, self)
    end

  end
end
