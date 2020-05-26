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

  class ApiUser
    include UserAccess::PrivilegeLevel::ReadOnlyApiUserExt
    include UserAccess::AnonymousLoginAccess

    def activated?
      true
    end

    def system?
      false
    end

    def anonymous?
      false
    end

    def api_user?
      true
    end

    def admin?
      false
    end

    def project_admin?
      false
    end

    def projects
      []
    end

    def login
      nil
    end

    def personal_views_for(project)
      []
    end

    def accessible_projects
      Project.all.reject(&:hidden?)
    end

    def accessible_templates
      accessible_projects.select(&:template?)
    end

    def all_accessible?(projects)
      projects.all?{|p| accessible_projects.include?(p)}
    end

    def accessible?(project)
      true
    end

    def display_preference(store={})
      store['user_display_preference'] ||= {}
      UserDisplayPreference.for_anonymous_user(store['user_display_preference'])
    end
  end

  class AdminApiUser < ApiUser
    include UserAccess::PrivilegeLevel::AdminApiUserExt
    def admin?
      true
    end

    def project_admin?
      true
    end
  end
end
