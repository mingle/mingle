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
  class GroupByProperty
    
    NOT_SET_DISPLAY_VALUE = '(not set)'
    
    def initialize(projects, property_name)
      @projects = projects
      @group_by_property = find_property_definition(property_name)
    end
    
    def cross_project_normalize(value)
      if group_by_card_property_definition?
        extract_card_name(value)
      else
        value
      end
    end
    
    def value(value)
      GroupByValue.new display_value(value), cross_project_normalize(value), @group_by_property.numeric?
    end
    
    private
    
    def display_value(value)
      if group_by_card_property_definition?
        extract_card_name(value)
      elsif group_by_user_property_definition?
        user = all_users.detect { |user| user.login == value }
        user ? "#{user.name} (#{user.login})" : value
      else
        value
      end || NOT_SET_DISPLAY_VALUE
    end
    
    def all_users
      @all_users ||= @projects.map(&:team).flatten
    end
    
    def extract_card_name(full_card_name)
      return unless full_card_name
      full_card_name.gsub(/^#[\d]+[ ]/, '')
    end
    
    def group_by_card_property_definition?
      @group_by_property && @group_by_property.card?
    end
    
    def group_by_user_property_definition?
      @group_by_property && @group_by_property.user?
    end
    
    def find_property_definition(property_name)
      return unless property_name
      @projects.first.property_definitions.detect{ |prop_def| prop_def.name.downcase == property_name.downcase }
    end
  end
end
