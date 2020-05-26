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

class FavoritesController < ProjectAdminController
  allow :get_access_for => [:index, :list, :show, :manage_favorites_and_tabs], :put_access_for => [:rename], :redirect_to => { :action => :list }
  privileges UserAccess::PrivilegeLevel::PROJECT_ADMIN =>['move_to_team_favorite', 'move_to_tab', 'remove_tab', 'delete' , 'manage_favorites_and_tabs'], UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER=>['remove_team_favorite', 'rename']

  def index
    list
  end

  def list
    #todo should we just use real favorites instead of get favorited list?
    @favorites = @project.favorites.of_team.include_favorited.collect(&:favorited).smart_sort_by(&:name)
    @tab_views = @project.tabs.include_favorited.collect(&:favorited).smart_sort_by(&:name)
    respond_to do |format|
      format.html do
        render :template => 'favorites/list'
      end
      format.xml do
        render_model_xml @project.favorites_and_tabs.of_team, :root => "favorites"
      end
    end
  end

  def rename
    @favorite = @project.favorites_and_tabs.find(params[:id])
    return render(:json => { :message => "Could not find favorite." }.to_json, :status => :not_found) unless @favorite

    new_name = params[:new_name].trim

    view = @favorite.favorited
    view.name = new_name
     begin
      view.save!
      render :json => {:id => view.reload.id }.to_json, :status => :ok
     rescue StandardError => e
      render :status => :unprocessable_entity, :text => view.errors.full_messages.join("\n")
    end
  end

  def show
    @favorite = @project.favorites_and_tabs.find(params[:id])
    redirect_to @favorite.to_params
  end

  def manage_favorites_and_tabs
    list
  end

  def delete
    delete_favorite
    redirect_to :action => 'list'
  end

  def move_to_team_favorite
    move_to { |favorite| favorite.adjust({:tab => false, :favorite => true}) }
  end

  def move_to_tab
    move_to { |favorite| favorite.adjust({:tab => true, :favorite => false}) }
  end

  def remove_tab
    favorite = @project.favorites_and_tabs.of_pages.find_by_id(params[:id])
    favorite.destroy
    redirect_to :action => 'list'
  end
  alias :remove_team_favorite :remove_tab

  def always_show_sidebar_actions_list
    ['list', 'manage_favorites_and_tabs']
  end

  private

  def delete_favorite
    @favorite = @project.favorites_and_tabs.find_by_id(params[:id])
    # todo: should move to into model validator?
    raise_user_access_error if !@project.admin?(User.current) && ( @favorite.user_id.nil? || @favorite.user_id != User.current.id )
    was_favorite = @favorite.favorite?
    view = @favorite.favorited
    view.destroy
    flash[:notice] = "#{was_favorite ? 'Team favorite' : 'Tab'} #{view.name.bold} was successfully deleted."
  end

  def move_to
    favorite = @project.favorites_and_tabs.find_by_id(params[:id])
    yield favorite
    favorite.save
    #clear all tab data in session. Bug 820.
    session["project-#{@project.id}"] = {}
    redirect_to :action => 'list'
  end

end
