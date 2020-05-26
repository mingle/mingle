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

module LoginAndUserProfilePageId

  USERNAME_TEXTBOX="user_login"
  PASSWORD_TEXTBOX="user_password"
  CURRENT_PASSWORD_TEXTBOX="current_password"
  USER_DISPLAY_NAME='user_name'
  PASSWORD_CONFIRMATION_TEXTBOX="user_password_confirmation"
  EMAIL_TEXTBOX="user_email"
  LOGIN_SUBMIT_BUTTON="name=commit"
  FORGOT_PASSWORD_LINK='link=Forgotten your password?'
  USERNAME_TEXTBOX_ON_FORGOT_PASSWORD='name=login'
  RECOVER_PASSWORD_LINK='link=Recover password'
  SIGN_IN_LINK='link=Sign in'
  SIGN_OUT_LINK="link=Sign out"
  NEW_USER_LINK="link=New user"
  VERSION_CONTROL_USER_NAME_TEXTBOX='user[version_control_user_name]'
  CREATE_PROFILE_LINK="link=Create this profile"
  SAVE_PROFILE_LINK="link=Save profile"
  CHANGE_PASSWORD_LINK_ID="link=Change password"
  CHANGE_PASSWORD_BUTTON_ID="submit_change_password"
  CANCEL_LINK="link=Cancel"
  DELETE_USER_BUTTON="delete_users"
  LAST_LOGIN_COLUMN_ID="last_login_at"
  CURRENT_USER_ID='current-user'
  EDIT_PROFILE_LINK="edit-profile"
  CHANGE_PASSWORD_ID="change-password"

  def profile_link
    class_locator('profile')
  end

  def profile_css_locator
    css_locator(".profile")
  end

  def edit_user_css_locator
    css_locator("a.edit-user")
  end

  def user_type_set_id(new_type)
    css_locator("input#user_user_type_#{new_type}")
  end

  def save_button_on_user_profile_id
    class_locator('save')
  end

  def edit_profile_link
    css_locator("a#edit-profile")
  end

  def show_profile_id(user)
    css_locator("a#show-profile-#{user.id}")
  end

  def change_password_link(user)
    css_locator("a#change-password-#{user.id}")
  end

  def toggle_user_activation_checkbox(user)
    "#{user.html_id}_toggle_activation"
  end

  def admin_user_checkbox(user)
    "admin-user-#{user.id}"
  end

  def light_user_checkbox(user)
    "light-user-#{user.id}"
  end

  def delete_user_id(user)
    "delete_user_#{user.id}"
  end

  def user_display_name_link(user)
    css_locator("tr#user_#{user.id} a")
  end

  def next_page_link_on_users_page
    class_locator("next_page")
  end

  def prev_page_link_on_users_page
    class_locator("prev_page")
  end

  def tab_link_on_profile_page(tab_name)
    css_locator("li[tab_identifier='#{tab_name}']")
  end

  def personal_favorite_delete_link(favorite_order)
    css_locator("table#global_personal_views a[onclick]",favorite_order-1)
  end

  def profile_for_user_link(user=nil)
    if user
      css_locator("a.profile[title='Profile for #{user.name}']")
    else
      css_locator("a.profile")
    end
  end

  def profile_for_user_name_link(user_name)
    css_locator("a.profile[title='Profile for #{user_name}']")
  end

end
