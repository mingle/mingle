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

class ProgramMembershipsController < PlannerApplicationController

  privileges UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER => ["index"]

  def index
    @projects_for_program = @program.projects
    @projects_members = Project.group_users_by_deliverable
    @users = @program.member_roles.includes(:member).map { |member_role|
      member_details = { name: member_role.member.name,
                         login: member_role.member.login,
                         email: member_role.member.email,
                         role: MembershipRole[member_role.permission].to_param,
                         activated: member_role.member.activated
      } unless member_role.member.nil?
      member_details.merge!(projects: projects_for_member(member_role).join(', ')) if params[:get_with_projects] && !member_role.member.nil?
      member_details
    }.compact
    @roles = MembershipRole::PROGRAM_ROLES.map{|role| {id: role.id, name: role.name} }
  end

  private

  def projects_for_member(member_role)
    projects = []
    @projects_for_program.each do | project|
      if  !@projects_members[project.id].nil?  && @projects_members[project.id].include?(member_role.member_id)
        projects << project.name
      end
    end
    projects
  end

end
