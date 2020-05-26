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

module Api
  class ProgramMembershipsController < PlannerApplicationController
    privileges UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER => ["index"]
    privileges UserAccess::PrivilegeLevel::PROJECT_ADMIN => [:bulk_remove, :create, :bulk_update]

    def create
      user = User.find_by_login(params[:user_login])
      begin
        @program.add_member(user, params[:role])
        new_user = {id: user.id, name: user.name, login: user.login, email: user.email, role: @program.role_for(user).to_param, is_team_member: @program.member?(user), light_user: user.light, projects: projects_for_user(user).join(', '), activated: user.activated}
        render json: new_user, status: :ok
      rescue => e
        render json: 'Cannot add user:Invalid role', status: :unprocessable_entity
      end
    end

    def bulk_remove
      @members = User.all.where(login: params[:members_login])
      if !@members.include?(User.current) || User.current.admin?
        @members.each do |member|
          @program.remove_member(member)
        end
        message = "#{@members.size > 1 ? "#{@members.size} members have" : "#{@members.first.name} has"} been removed from this program."
        render json: message, status: :ok
      else
        render json: 'Cannot remove yourself from program.', status: :unprocessable_entity
      end
    end

    def bulk_update
      members = @program.members_for_login(params[:members_login])
      (head(:unprocessable_entity) and return) unless members.count == params[:members_login].count
      @program.change_members_role(members.map(&:member_id), params[:role])
      message = if members.count > 1
                  "#{members.count} members role have been updated to #{MembershipRole[params[:role]].name}."
                else
                  "#{members.first.member.name} role has been updated to #{MembershipRole[params[:role]].name}."
                end
      render json: {message: message}
    end

    private

    def projects_for_user(user)
      all_projects_for_user = user.project_names
      projects_for_program = @program.projects_associated
      all_projects_for_user.keep_if {|project| projects_for_program.include? project}
    end
  end
end
