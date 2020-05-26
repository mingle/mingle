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

class GroupsController < ProjectAdminController
  allow :get_access_for => [:index, :show, :list_members_available_for_add],
        :put_access_for => [:update],
        :delete_access_for => [:destroy]
  privileges UserAccess::PrivilegeLevel::PROJECT_ADMIN => ['create', 'destroy', 'update', 'list_members_available_for_add']

  helper :team

  def always_show_sidebar?
    true
  end

  def index
    respond_to do |format|
      format.html { render :index }
      format.xml { render_model_xml @project.user_defined_groups, :root => "groups" }
    end
  end

  def show
    @group = @project.user_defined_groups.find(params[:id])
    @users = @group.users.paginate(:all, :page => params[:page], :order => 'LOWER(users.name)', :per_page => PAGINATION_PER_PAGE_SIZE)
    respond_to do |format|
      format.html { render :show }
      format.xml { render_model_xml @group }
    end
  end

  def list_members_available_for_add
    @group = Group.find(params[:id])
    @search = ManageUsersSearch.new params[:search], User.current.display_preference(session).read_preference(:show_deactived_users)
    @users = @project.users.search(@search.query, params[:page])
    flash.now[:info] = @search.result_message(@users, 'team members') unless @search.blank?
    render :template => 'groups/add_to_group', :locals => {:available_members_listing_partial => 'members_available_for_add'}
  end

  def confirm_delete
    @group = @project.user_defined_groups.find(params[:id])
    destroy if @group.unused?
  end

  def create
    @group = @project.user_defined_groups.new(params[:group])

    if @group.save
      redirect_to :action => :index
    else
      set_rollback_only
      flash.now[:error] = @group.errors.full_messages
      render :action => :index
    end
  end

  def update
    @group = @project.user_defined_groups.find(params[:id])
    @group.name = params[:name]
    render :update do |page|
      if @group.save
        page.replace "group_name_form", :partial => 'group_name_form'
      else
        flash.now[:error] = @group.errors.full_messages
        page << "InlineTextEditor.activeInstance.onFailedUpdate()"
      end

      page.refresh_flash
    end
  end

  def destroy
    group = @project.user_defined_groups.find(params[:id])
    group.destroy
    redirect_to :action => :index
  end
end
