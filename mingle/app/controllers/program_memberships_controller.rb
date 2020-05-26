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
  allow :get_access_for => [:index, :list_users_for_add], :delete_access_for => [:bulk_destroy]

  privileges UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER => ["index", "create", "list_users_for_add", "bulk_destroy"],
             UserAccess::PrivilegeLevel::LIGHT_READONLY_TEAM_MEMBER => [:index]

  def index
    @search = ManageUsersSearch.new search_params, User.current.display_preference(session).read_preference(:show_deactived_users)
    @users = @program.users.search(@search.query, params[:page])
  end

  def create
    user = User.find_by_id(params[:user_id])
    if !user.light?
      @program.add_member(user, :program_admin)
    end
    render :update do |page|
      page.replace user.html_id, :partial => 'user_for_add', :locals => { :user => user }
    end
  end

  def list_users_for_add
    @search = ManageUsersSearch.new search_params, User.current.display_preference(session).read_preference(:show_deactived_users)
    @users = User.search(@search.query, params[:page])
  end

  def bulk_destroy
    @users = User.find_all_by_id(params[:user_ids])
    if !@users.include?(User.current) || User.current.admin?
      @users.each do |user|
        @program.remove_member(user)
      end

      num_users = @users.size
      pluralized_member = num_users == 1 ? "member has" : 'members have'
      flash[:notice] = "#{num_users} #{pluralized_member} been removed from the #{@program.name.bold} team successfully."
    else
      flash[:error] = "Cannot remove yourself from program"
    end
    appended_params = params.slice(:page, :search)
    redirect_to program_program_memberships_path(@program, appended_params)
  end

  private

  def search_params
    params[:search].blank? ? {} : params[:search]
  end
end
