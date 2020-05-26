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

class TeamController < ProjectAdminController

  privileges UserAccess::PrivilegeLevel::PROJECT_ADMIN => %w(add_user_to_team destroy enable_auto_enroll list_users_for_add_member set_permission),
  UserAccess::PrivilegeLevel::LIGHT_READONLY_TEAM_MEMBER => %w(show_member_email) ,
  UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER => %w(invite_user invite_suggestions)

  def show_user_selector

  end
end
