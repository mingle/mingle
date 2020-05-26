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

#Copyright 2009 ThoughtWorks, Inc.  All rights reserved.

module CrossProjectRollup

  class GroupBy
    include Mql
    
    def initialize(projects, macro_parameters)
      @projects         = projects
      @macro_parameters = macro_parameters
      @property         = macro_parameters['rows']
      @conditions       = macro_parameters['rows-conditions']
    end
    
    def get_data
      row_heads = @projects.map do |project|
        project.execute_mql build_mql(:select_distinct  => true,
                                      :select_columns   => @property,
                                      :where_conditions => @conditions)
      end.flatten.map(&:values).flatten
      sort_with_nil_at_end(normalize_data_across_projects(row_heads))
    end
    
    def sort_row_heads(property_definition, row_heads)
      property_definition.managed_text? ? sort_managed_text_values(property_definition, row_heads) : row_heads.sort
    end
    
    private
    
    def group_by_property
      @group_by_property ||= GroupByProperty.new(@projects, @property)
    end
    
    def normalize_data_across_projects(row_heads)
      row_heads.map { |row_head| group_by_property.value(row_head) }.uniq
    end
    
    def sort_with_nil_at_end(row_heads)
      nil_row = row_heads.delete(group_by_property.value(nil))
      sorted_row_heads = sort_row_heads(property_definition, row_heads)
      sorted_row_heads << nil_row if nil_row
      sorted_row_heads
    end
    
    def property_definition
      @projects.first.property_definitions.detect { |definition| definition.name.downcase == @property.downcase }
    end
    
    def sort_managed_text_values(property_definition, row_heads)
      property_values = property_definition.values.map { |value| group_by_property.value(value.display_value) }
      known_row_head_values, unknown_row_head_values = row_heads.partition { |value| property_values.include?(value) }
      
      unused_values = property_values - known_row_head_values
      sorted_known_heads = property_values - unused_values
      sorted_known_heads + unknown_row_head_values.sort
    end
  end
end
