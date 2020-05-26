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

class UserDisplayPreferenceController < ApplicationController

  def update_user_display_preference
    prefs = User.current.display_preference(session)
    new_prefs = params[:user_display_preference]
    prefs.update_preferences(new_prefs)
    render :nothing => true
  end

  def update_show_deactived_users
    prefs = User.current.display_preference(session)
    prefs.update_preference(:show_deactived_users, params[:search][:show_deactivated])
    redirection_params = params.merge(:controller => 'users', :action => 'index', :escape => false)
    render(:update) { |page| page.redirect_to(redirection_params) }
  end

  def update_holiday_effects_preference
    User.current.display_preference(session).update_preference(:i_hate_holidays, params[:holiday])
    render :nothing => true
  end

  def update_user_project_preference
    user_project_preference = params[:user_project_preference]

    if !params[:project_id].nil? && !user_project_preference.nil?
      User.current.display_preference(session).update_project_preference(Project.find_by_id(params[:project_id]), user_project_preference[:preference],parse_value(user_project_preference[:value]))
      render nothing: true
    else
      render nothing: true ,status: 401
    end
  end

  private
  def parse_value value
    return true if value == 'true'
    return false if value == 'false'
    value
  end

end
