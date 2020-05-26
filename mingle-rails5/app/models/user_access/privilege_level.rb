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

module UserAccess
  class PrivilegeLevel < Struct.new(:rank)
    module UserExt
      def privilege_level(deliverable=nil)
        return MINGLE_ADMIN if self.admin?
        return PROJECT_ADMIN if !deliverable && self.admin_in_any_project?
        return REGISTERED_USER if !deliverable || !deliverable.member?(self)
        return LIGHT_READONLY_TEAM_MEMBER if light?
        deliverable.role_for(self).try(:privilege_level) || REGISTERED_USER
      end
      
      def license_invalid_privilege_level(deliverable=nil)
        return LIGHT_READONLY_TEAM_MEMBER if deliverable && (self.admin? || deliverable.member?(self))
        REGISTERED_USER
      end
    end

    module ReadOnlyApiUserExt
      def privilege_level(deliverable=nil)
        READONLY_TEAM_MEMBER
      end
      alias_method :license_invalid_privilege_level, :privilege_level

    end

    module AdminApiUserExt
      def privilege_level(deliverable=nil)
        MINGLE_ADMIN
      end
      alias_method :license_invalid_privilege_level, :privilege_level

    end

    module AnonymousUserExt
      def privilege_level(deliverable=nil)
        ANONYMOUS
      end
      alias_method :license_invalid_privilege_level, :privilege_level
    end

    include Comparable

    MINGLE_ADMIN = PrivilegeLevel.new(6)
    PROJECT_ADMIN = PrivilegeLevel.new(5)
    FULL_TEAM_MEMBER = PrivilegeLevel.new(4)
    READONLY_TEAM_MEMBER = PrivilegeLevel.new(3)
    LIGHT_READONLY_TEAM_MEMBER = PrivilegeLevel.new(2)
    REGISTERED_USER = PrivilegeLevel.new(1)
    ANONYMOUS = PrivilegeLevel.new(0)

    @action_minimum_privilege_levels = {}
    def self.action_minimum_privilege_levels
      @action_minimum_privilege_levels
    end

    def self.find_minimum_privilege_level_for(action)
      if privilege_level = @action_minimum_privilege_levels[action]
        privilege_level
      else
        action.planner_action? ? PrivilegeLevel::FULL_TEAM_MEMBER : PrivilegeLevel::ANONYMOUS
      end
    end

    def self.map_minimum_privilege_level(action, privilege_level)
      action = PrivilegeAction.create(action)
      if @action_minimum_privilege_levels[action].nil? || @action_minimum_privilege_levels[action] > privilege_level
        @action_minimum_privilege_levels[action] = privilege_level
      end
    end

    def <=>(another)
      self.rank <=> another.rank
    end
  end
end
