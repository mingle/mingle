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

class PersonalFavoritesController < ProjectApplicationController
  verify :method => :post

  privileges UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER => [ "create" ]

  def create
    @project.favorites.personal(User.current).find_or_create_by_favorited_id_and_favorited_type(params[:favorite][:favorited_id], params[:favorite][:favorited_type])

    respond_to do |format|
      format.js do
        render :update do |page|
          page.replace 'favorite_list_div', :partial => 'shared/favorite_listing', :locals => { :favorites => @project.favorites.personal(User.current), :allow_view_creation => false }
          page.remove 'add_current_page_to_my_favorite_link'
        end
      end
    end
  end

  def destroy
    @favorite = @project.favorites.find(params[:id])
    raise_user_access_error unless @favorite.user_id == User.current.id || User.current.admin?
    favorited_name = @favorite.favorited.name
    @favorite.destroy
    flash.now[:notice] = "Personal favorite #{favorited_name.bold} was successfully deleted."
    respond_to do |format|
      format.js do
        render :update do |page|
          page.remove dom_id(@favorite.favorited)
          page.refresh_flash
          page.subscriptions_counter.no_subscriptions_check
        end
      end
    end
  end
end

