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

module UserDisplayPreferenceHelper

  def initially_shown_preference(preference_name, default = false)
    preference_name ? user_preference(preference_name) : default
  end

  def user_preference(visibility_preference)
    User.current.display_preference(session).read_preference(visibility_preference)
  end

  def set_user_preference(visibility_preference, value)
    User.current.display_preference(session).update_preference(visibility_preference, value)
  end

  def remember_hide_call(preference_name)
    update_user_preference(preference_name, false)
  end

  def remember_show_call(preference_name)
    update_user_preference(preference_name, true)
  end

  def update_user_preference(preference_name, preferred_visibility)
    remote_function(:url => {:controller => 'user_display_preference', :action => 'update_user_display_preference',
                             :user_display_preference => {preference_name => preferred_visibility}})
  end

  def display_export_notice?
    return false unless MingleConfiguration.saas?
    current_user_pref = user_preference(:preferences)
    current_month = Date.today.strftime("%B")
    if current_user_pref
      retirement_banner_display_pref = current_user_pref[:last_displayed_retirement_banner_on]
      if (retirement_banner_display_pref.nil? || (retirement_banner_display_pref != current_month))
        update_retirement_banner_display_preference(current_user_pref)
        return true
      end
    end
    return false
  end

  def update_retirement_banner_display_preference(current_user_pref)
     set_user_preference(:preferences, current_user_pref.merge!({last_displayed_retirement_banner_on: Date.today.strftime("%B")}))
  end

  private
  def first_day_of_month?(day)
    return day.to_i == 1
  end
end
