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
  class UsersController < ApplicationController
    def index
      conditions = {activated: true}
      conditions[:light] = false if params[:exclude_light_users] && params[:exclude_light_users].to_s == 'true'
      render json: User.where(conditions).select(:id, :name, :login, :email, :light)
    end


    def projects
      if params[:program_id].blank?
        projects = User.find_by_login(params[:user_login]).project_names
        render json: {userLogin: params[:user_login], projects: projects}
      else
        projects_for_program = Program.find_by_identifier(params[:program_id]).projects_associated
        user_projects = User.find_by_login(params[:user_login]).project_names
        user_projects.keep_if{|project| projects_for_program.include? project}

        render json: {userLogin: params[:user_login], projects: user_projects}
      end
    end
  end
end
