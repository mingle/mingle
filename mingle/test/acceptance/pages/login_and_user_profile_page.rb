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

module LoginAndUserProfilePage
  def assert_not_logged_in
    @browser.assert_element_not_present(LoginAndUserProfilePageId::CURRENT_USER_ID)
  end

  def assert_sign_out_link_present
    @browser.assert_element_present(LoginAndUserProfilePageId::SIGN_OUT_LINK)
  end

  def assert_sign_out_link_not_present
    @browser.assert_element_not_present(LoginAndUserProfilePageId::SIGN_OUT_LINK)
  end

  def assert_profile_link_present_for(user)
    @browser.assert_element_present(profile_for_user_link(user))
  end

  def assert_profile_link_not_present_for(user)
    @browser.assert_element_not_present(profile_for_user_link(user))
  end

  def assert_new_user_link_not_present
    @browser.assert_element_not_present(LoginAndUserProfilePageId::NEW_USER_LINK)
  end

  def assert_new_user_link_present
    @browser.assert_element_present(LoginAndUserProfilePageId::NEW_USER_LINK)
  end

  def assert_user_type_options_present
    @browser.assert_element_present(css_locator("input#user_user_type_light"))
    @browser.assert_element_present(css_locator("input#user_user_type_admin"))
    @browser.assert_element_present(css_locator("input#user_user_type_full"))
  end

  def assert_light_type_checked
    @browser.assert_element_present(css_locator("input#user_user_type_light[checked=checked]"))
  end

  def assert_full_type_checked
    @browser.assert_element_present(css_locator("input#user_user_type_full[checked=checked]"))
  end

  def assert_full_type_disabled
    @browser.assert_element_present(css_locator("input#user_user_type_admin[disabled=disabled]"))
  end

  def assert_admin_type_disabled
    @browser.assert_element_present(css_locator("input#user_user_type_full[disabled=disabled]"))
  end

  def assert_change_password_link_present
     @browser.assert_element_present(LoginAndUserProfilePageId::CHANGE_PASSWORD_LINK_ID)
   end

   def assert_change_password_link_not_present
     @browser.assert_element_not_present(LoginAndUserProfilePageId::CHANGE_PASSWORD_LINK_ID)
   end


   def assert_show_profile_link_present_for(user)
     @browser.assert_element_present("show-profile-#{user.id}")
   end

   #
   def assert_user_profile_is_opened(user)
     @browser.assert_text(LoginAndUserProfilePageId::USERNAME_TEXTBOX, user.login)
   end

   def assert_user_profile_in_full_control_mode
     @browser.assert_element_present(css_locator("div.basic-profile-information"))

     @browser.assert_text(css_locator(".tabs_pane .menu_item.current"), 'Projects')

     @browser.assert_element_present(LoginAndUserProfilePageId::EDIT_PROFILE_LINK)
     @browser.assert_element_present(LoginAndUserProfilePageId::CHANGE_PASSWORD_ID)

     @browser.assert_text_present_in(css_locator(".tabs_pane .tabs_header"), 'My Favorites')
     @browser.assert_text_present_in(css_locator(".tabs_pane .tabs_header"), 'Subscriptions')
   end

   def assert_user_profile_in_show_mode
     @browser.assert_element_present(css_locator("div.basic-profile-information"))
     @browser.assert_text(css_locator(".tabs_pane .menu_item.current"), 'Projects')

     @browser.assert_element_not_present(LoginAndUserProfilePageId::EDIT_PROFILE_LINK)
     @browser.assert_element_not_present(LoginAndUserProfilePageId::CHANGE_PASSWORD_ID)
     @browser.assert_text_not_present_in(css_locator(".tabs_pane .tabs_header"), 'My Favorites')
     @browser.assert_text_not_present_in(css_locator(".tabs_pane .tabs_header"), 'Subscriptions')
   end

   def assert_located_at_login_page
     @browser.assert_location('/profile/login')
   end

   def assert_message_for_wrong_user_and_password
     @browser.assert_element_matches 'error', /Wrong sign-in name or password/
   end

   def assert_personal_favorite_delete_message(favorite_name)
     @browser.assert_text_present("Personal favorite #{favorite_name} was successfully deleted.")
   end

   def assert_number_of_personal_favorites(number)
     @browser.assert_element_present(class_locator('favorite-link', number -1))
     @browser.assert_element_not_present(class_locator('favorite-link', number))
   end

   def assert_personal_favorites_are_not_displayed_on_profile(*personal_favorites)
      personal_favorites.each do |personal_favorite|
      @browser.assert_text_not_present_in('global_personal_views', personal_favorite)
     end
   end
end
