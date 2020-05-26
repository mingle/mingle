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

class TagsController < ProjectAdminController

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  allow :get_access_for => [ :index, :list, :new, :edit, :confirm_delete ], :redirect_to => {:action => :list}

  privileges UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER => ["new", "edit", "destroy", "create", "update", "confirm_delete"]

  def index
    list
    render :action => 'list'
  end

  def list
    @tags = @project.tags.used.smart_sort_by(&:name)
    respond_to do |format|
      format.html
      format.json do
        render :layout => false
      end
    end
  end

  def new
    set_rollback_only
    @tag =  Tag.new
  end

  def create
    tag_name = params[:tag][:name].strip
    @tag = @project.tags.deleted.case_insensitive_find_by_tag_name(tag_name) || @project.tags.build(:name => tag_name)
    if @tag.save
      flash[:notice] = 'Tag was successfully created.'
      redirect_to :action => 'list'
    else
      handle_error @tag.errors.full_messages.join(', '), 'new'
    end
  end

  def edit
    @tag = @project.tags.find(params[:id])
  end

  def update
    @tag = @project.tags.find(params[:id])
    if @tag.update_attributes(params[:tag])
      flash[:notice] = 'Tag was successfully updated.'
      redirect_to :action => 'list'
    else
      handle_error @tag.errors.full_messages.join(', '), 'edit'
    end
  end

  def update_color
    @tag = @project.tags.find_or_create(:name => params[:name])
    if @tag.update_attributes(:color => params[:color])
      render :json => {:event => @project.last_event_id, :tagId => @tag.id}, :status => :ok
    else
      render :json => {:errors => @tag.errors.full_messages }
    end
  end

  def destroy
    tag = @project.tags.find(params[:id])
    tag.safe_delete
    flash[:notice] = "Tag #{tag.name.bold} was successfully deleted."
    redirect_to :action => 'list'
  end

  def confirm_delete
    @tag = @project.tags.find(params[:id])
  end

  def always_show_sidebar_actions_list
    ['list', 'new']
  end

  private

  def handle_error(error_message, render_action)
    set_rollback_only
    flash.now[:error] = error_message
    render :action => render_action
  end
end
