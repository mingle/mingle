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
  class GroupByParam
    def initialize(group_by_param_value)
      @value = parse(group_by_param_value)
    end

    def param_value
      @value
    end

    def parse(group_by_param_value)
      return nil if group_by_param_value.blank?
      return {:lane => group_by_param_value} if group_by_param_value.is_a?(String)

      # we need to ensure that when we serialize this to YAML, we use built-in Ruby Hashes
      # to avoid implementation-specific class mappings
      ({}).tap do |result|
        result[:lane] = group_by_param_value[:lane] unless group_by_param_value[:lane].blank?
        result[:row] = group_by_param_value[:row] unless group_by_param_value[:row].blank?
      end
    end

    def rename_property(old_name, new_name)
      return if @value.nil?
      @value.each do |key, name|
        if old_name.ignore_case_equal?(name)
          @value[key] = new_name
        end
      end
    end

    def uses_property_value?(property_name, property_value, group_lanes)
      if property_name.ignore_case_equal?(self.lane_property_name)
        group_lanes.visibles(:lane).any?{|lane| lane.identifier == property_value}
      elsif property_name.ignore_case_equal?(self.row_property_name)
        group_lanes.used_group_by_row_property_values.any?{|row| row.lane_identifier == property_value}
      end
    end

    def uses?(property_definition)
      property_names.compact.any?{|name| property_definition.name.ignore_case_equal?(name)}
    end

    def included_in?(properties)
      property_names.compact.all?{|name| properties.any? {|property| property.name.downcase == name.downcase}}
    end

    def property_definitions(project)
      property_names.collect do |name|
        name.blank? ? nil : project.find_property_definition_including_card_type_def(name)
      end
    end

    def lane_property_name
      property_names[0]
    end

    def row_property_name
      property_names[1]
    end

    def property_names
      @value.blank? ? [] : [@value[:lane], @value[:row]]
    end
  end
end
