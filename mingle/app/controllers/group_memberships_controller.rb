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

class GroupMembershipsController < ProjectApplicationController
  allow :post_access_for => [:update, :add]
  privileges UserAccess::PrivilegeLevel::PROJECT_ADMIN => ['update', 'add']
  helper :team

  def update
    @users = @project.users.find(params[:selected_users])
    message_parts = [remove_group_memberships, add_group_memberships].compact
    flash[:notice] = "#{affected_members_message} #{'has'.plural(params[:selected_users].size)} been #{(message_parts).join(' and ')}." if message_parts.any?
    redirect_to :back
  end

  def add
    group = Group.find(params[:group])
    user = @project.users.find(params[:selected_membership])
    group.add_member(user)
    respond_to do |format|
      format.js do
        render :update do |page|
          flash.now[:notice] = "#{user.name.bold} has been added to #{group.name.bold}."
          page.refresh_flash
          page.replace user.html_id, :partial => 'groups/available_user', :locals => {:user => user, :group =>  group}
        end
      end
    end
  end

  private

  def find_groups(ids)
    @project.user_defined_groups.find(ids)
  end

  def remove_group_memberships
    return unless params[:removes]
    affected_groups = find_groups(params[:removes]).select { |group| group.any_is_member?(@users) }
    affected_groups.map { |group| group.remove_members_in(@users) }
    "removed from #{affected_groups.uniq.collect {|group| group.name.bold }.join(", ")}" if affected_groups.any?
  end

  def add_group_memberships
    return unless params[:adds]
    affected_groups = find_groups(params[:adds]).reject { |group| group.all_are_members?(@users) }
    affected_groups.map { |group| group.add_members_in(@users) }
    "added to #{affected_groups.uniq.collect {|group| group.name.bold }.join(", ")}" if affected_groups.any?
  end

  def affected_members_message
    selection_count = params[:selected_users].size
    if selection_count > 1
      "#{selection_count} #{'members'.plural(selection_count)}"
    else
      @project.users.find(params[:selected_users].first).name.bold
    end
  end
end
