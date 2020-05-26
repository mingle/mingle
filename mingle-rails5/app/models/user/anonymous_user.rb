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

class User
  class AnonymousUser
    # include UserAccess::AnonymousLoginAccess
    # include API::XMLSerializer
    include UserAccess::PrivilegeLevel::AnonymousUserExt
    # serializes_as :complete => [:name, :login]

    def name
      nil
    end

    def id
      nil
    end

    def anonymous?
      true
    end

    def api_user?
      false
    end

    def activated?
      true
    end

    def activation_state
      'activated'
    end

    def admin?
      false
    end

    def light?
      false
    end

    def login
      nil
    end

    def system?
      false
    end

    def member_of?(project)
      false
    end

    def display_preference(store=nil)
      store['user_display_preference'] ||= {}
      UserDisplayPreference.for_anonymous_user(store['user_display_preference'])
    end

    def has_subscribed_history?(project, params)
      false
    end

    def email
      nil
    end

    def accessible_projects
      Project.anonymous_accessible_projects.reject(&:hidden?)
    end

    def accessible_templates
      accessible_projects.select(&:template?)
    end

    def all_accessible?(projects)
      projects.all?{|p| accessible_projects.include?(p)}
    end

    def accessible?(project)
      project.accessible_for?(self)
    end

    def projects
      []
    end

    def personal_views_for(project)
      []
    end

    def has_read_notification?(message)
      true
    end

    def project_admin?
      false
    end

    def recent_users(project)
      return [] unless project
      project.user_prop_values.first(UserDisplayPreference::MAX_RECENT_USER_COUNT)
    end
  end
end
