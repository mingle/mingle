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

module LoginAndUserProfileAction

  # login

  def go_to_profile_page
    @browser.click_and_wait profile_link
  end

  def go_to_profile_page_for_user(user)
    @browser.click_and_wait profile_link
  end

  def navigate_to_login_page
    @browser.open('/profile/login')
  end

  def login_as(login, password=MINGLE_TEST_DEFAULT_PASSWORD)
    retryable(:tries => 3, :sleep => 0.1) do
      navigate_to_login_page
      @browser.wait_for_element_present('name=commit')
      @browser.type LoginAndUserProfilePageId::USERNAME_TEXTBOX, login
      @browser.type LoginAndUserProfilePageId::PASSWORD_TEXTBOX, password
      @browser.click_and_wait LoginAndUserProfilePageId::LOGIN_SUBMIT_BUTTON
      User.current = User.find_by_login(login)
    end
  end

  alias :ensure_browser_logged_in_as :login_as

  def fake_now(year, month, day, hour = 12, login_again = true)
    @browser.open("/_class_method_call?class=Clock&method=fake_now&year=#{year}&month=#{month}&day=#{day}&hour=#{hour}")
    @browser.assert_text_present "Clock.fake_now called"
    # test clock should same with app, we have test data created in test process
    Clock.fake_now(:year => year, :month => month, :day => day, :hour => hour)
    login_as_current_user if login_again
  end

  def login_as_current_user
    login_as(User.current.login)
  end


  def login_as_admin_user
    login_as('admin')
  end

  def login_as_proj_admin_user
    login_as('proj_admin')
  end

  def login_as_read_only_user
    login_as('read_only_user')
  end

  def login_as_project_member
    login_as('member')
  end

  def login_as_user_bob
    login_as('bob')
  end

  def login_as_light_user
    login_as_admin_user
    navigate_to_user_management_page
    check_light_user_check_box_for(users(:longbob))
    login_as 'longbob', 'longtest'
  end



  def login_as_non_project_member
    login_as('existingbob')
  end

  def login_as_user_with_html
    login_as('user_with_html')
  end

  def login_as_admin_not_on_team
    login_as('admin_not_on_project')
  end

  def as_user(login, password=MINGLE_TEST_DEFAULT_PASSWORD)
    raise "Nothing to be done" unless block_given?
    login_as(login, password)
    yield
  ensure
    logout
  end

  def as_admin
    as_user('admin') { yield }
  end

  def as_anon_user
    logout if (User.current && !User.current.anonymous?)
    yield
  end

  def as_proj_admin
    as_user('proj_admin') { yield }
  end

  def as_read_only_user
    as_user('read_only_user') { yield }
  end

  def as_project_member
    as_user('member') { yield }
  end

  def login_as_user_bob
    as_user('bob') { yield }
  end

  def as_non_project_member
    as_user('existingbob') { yield }
  end

  def as_user_with_html
    as_user('user_with_html') { yield }
  end

  def as_admin_not_on_project
    as_user('admin_not_on_project') { yield }
  end

  def log_back_in(login, password=MINGLE_TEST_DEFAULT_PASSWORD)
    login_as(login, password)
  end

  def logout
    if defined?(@browser) && @browser
      unless User.current.anonymous?
        @browser.wait_for_all_ajax_finished
      end
      @browser.open('/profile/logout')
    end
    User.current = nil
  end

  def recover_password_for(user_name)
    navigate_to_login_page
    @browser.click_and_wait LoginAndUserProfilePageId::FORGOT_PASSWORD_LINK
    @browser.type(LoginAndUserProfilePageId::USERNAME_TEXTBOX_ON_FORGOT_PASSWORD, user_name)
    @browser.click_and_wait LoginAndUserProfilePageId::RECOVER_PASSWORD_LINK
  end

  def click_sign_in_link
    @browser.click_and_wait LoginAndUserProfilePageId::SIGN_IN_LINK
  end

  def click_forgotten_password_link
    @browser.click_and_wait LoginAndUserProfilePageId::FORGOT_PASSWORD_LINK
  end

  def change_user_type_to(new_type)
    @browser.click(user_type_set_id(new_type))
  end

  def add_new_user(email, password, options={})
    complete_new_user_fields(email, password, options)
    click_create_profile_button
    @browser.wait_for_element_visible RegisterMinglePageId::NOTICE_ID
    user_login = options[:login] || email.gsub(/@.*/, '').gsub(/\W/, '')
    new_user = User.find_by_login(user_login)
  end

  def click_new_user_link
    @browser.wait_for_element_present LoginAndUserProfilePageId::NEW_USER_LINK
    @browser.click_and_wait LoginAndUserProfilePageId::NEW_USER_LINK
  end


  def complete_new_user_fields(email, password, options={})
    @browser.wait_for_element_present LoginAndUserProfilePageId::PASSWORD_CONFIRMATION_TEXTBOX

    # remove domain part from email and remove non-word characters and use as login
    user_login = options[:login] || email.gsub(/@.*/, '').gsub(/\W/, '')
    user_display_name = options[:display_name] || email
    @browser.type LoginAndUserProfilePageId::USERNAME_TEXTBOX, user_login
    @browser.type LoginAndUserProfilePageId::EMAIL_TEXTBOX, email
    type_full_name_in_user_profile(user_display_name)
    @browser.type LoginAndUserProfilePageId::PASSWORD_TEXTBOX, password
    @browser.type LoginAndUserProfilePageId::PASSWORD_CONFIRMATION_TEXTBOX, password
    # it is up to the calling method to click the correct submit button, as it varies
  end

  def edit_user_profile_details(user, options={})
    user = User.find_by_login(user) unless user.respond_to?(:login)
    user_login = options[:user_login] || user.login
    user_name = options[:user_name] || user.name
    email = options[:email] || user.email

    open_edit_profile_for(user)
    type_user_sign_in_name(user_login)
    type_full_name_in_user_profile(user_name)
    type_user_email_address(email)
    click_save_profile_button
    User.current = User.find_by_login(user_login)
  end

  # set current_password to nil if it's admin changes another user's
  # password, because there is no current password need to be set
  def change_password_for(user, new_password, current_password=MINGLE_TEST_DEFAULT_PASSWORD)
    @browser.open("/users/change_password/#{user.id}")
    click_change_password_button
    if current_password
      @browser.type(LoginAndUserProfilePageId::CURRENT_PASSWORD_TEXTBOX, current_password)
    end
    @browser.type(LoginAndUserProfilePageId::PASSWORD_TEXTBOX, new_password)
    @browser.type(LoginAndUserProfilePageId::PASSWORD_CONFIRMATION_TEXTBOX, new_password)
    @browser.click_and_wait save_button_on_user_profile_id
  end

  def type_user_sign_in_name(user_login_name)
    @browser.type(LoginAndUserProfilePageId::USERNAME_TEXTBOX, user_login_name)
  end

  def type_user_email_address(user_email)
    @browser.type(LoginAndUserProfilePageId::EMAIL_TEXTBOX, user_email)
  end

  def click_edit_profile
    @browser.click_and_wait edit_profile_link
  end

  def click_show_profile_for(user)
    user = User.find_by_login(user) unless user.respond_to?(:login)
    @browser.click_and_wait show_profile_id(user)
  end

  def click_change_password_for(user)
    if (@browser.get_location.include?('users/list'))
      @browser.click_and_wait change_password_link(user)
    elsif (@browser.get_location.include?('profile/show'))
      @browser.click_and_wait change_password_link(user)
    end
  end

  def open_edit_profile_for(user)
    if User.current.admin?
      @browser.open("/users/edit_profile/#{user.id}")
    else
      @browser.open("/profile/edit_profile/#{user.id}")
    end
  end

  def open_change_password_page_for(user_id)
    @browser.open("/users/change_password/#{user_id}")
  end

  def open_show_profile_for(user)
    if User.current.admin?
      @browser.open "/users/show/#{user.id}"
    else
      @browser.open "/profile/show/#{user.id}"
    end
  end


  def active_user(user)
    navigate_to_user_management_page
    unless @browser.get_text(toggle_user_activation_checkbox(user)) == "(deactivate)"
      @browser.click_and_wait(toggle_user_activation_checkbox(user))
      @browser.assert_text_present("#{user.name} is now activated")
    end
  end

  def grant_mingle_admin_to_user(user)
    navigate_to_user_management_page
    unless @browser.is_checked(admin_user_checkbox(user))
      @browser.click_and_wait(admin_user_checkbox(user))
      @browser.assert_text_present("#{user.name} is now an administrator.")
    end
  end

  def revoke_mingle_admin_for_user(user)
    navigate_to_user_management_page
    if @browser.is_checked(admin_user_checkbox(user))
      @browser.click_and_wait(admin_user_checkbox(user))
      @browser.assert_text_present("#{user.name} is not an administrator.")
    end
  end

  def edit_user_display_name_to(new_display_name)
    @browser.click_and_wait profile_css_locator
    @browser.click_and_wait edit_user_css_locator
    @browser.type(LoginAndUserProfilePageId::USER_DISPLAY_NAME, new_display_name)
    click_save_profile_button
  end

  def after_user_update_messages_have_been_processed
    bridge_messages MurmursPublisher::QUEUE, FullTextSearch::IndexingMurmursProcessor::QUEUE
    FullTextSearch.run_once
  end

  def deactive_user(user)
    navigate_to_user_management_page
    unless @browser.get_text(toggle_user_activation_checkbox(user)) == "(activate)"
      @browser.click_and_wait(toggle_user_activation_checkbox(user))
      @browser.assert_text_present("#{user.name} is now deactivated")
    end
  end

  def toggle_activation_for(user)
    navigate_to_user_management_page
    @browser.click_and_wait(toggle_user_activation_checkbox(user))
  end

  def check_administrator_check_box_for(user)
    @browser.click_and_wait admin_user_checkbox(user)
  end

  def check_light_user_check_box_for(user)
    @browser.click_and_wait light_user_checkbox(user)
  end

  def type_svn_user_name_in_profile(svn_user_name)
    @browser.type(LoginAndUserProfilePageId::VERSION_CONTROL_USER_NAME_TEXTBOX, svn_user_name)
  end

  def click_create_profile_button
    @browser.click_and_wait LoginAndUserProfilePageId::CREATE_PROFILE_LINK
  end

  def click_save_profile_button
    @browser.click_and_wait LoginAndUserProfilePageId::SAVE_PROFILE_LINK
  end

  def click_change_password_button
    @browser.click_and_wait LoginAndUserProfilePageId::CHANGE_PASSWORD_BUTTON_ID
  end

  def click_cancel_button
    @browser.click_and_wait LoginAndUserProfilePageId::CANCEL_LINK
  end

  def type_full_name_in_user_profile(name)
    @browser.type(LoginAndUserProfilePageId::USER_DISPLAY_NAME, name)
  end

  def delete_users(*users)
    @browser.wait_for_element_present("css=#delete_users")
    users.each do |user|
      @browser.click delete_user_id(user)
    end
    @browser.wait_for_element_not_present "css=##{LoginAndUserProfilePageId::DELETE_USER_BUTTON}[disabled]"
    @browser.click "css=input[value='Delete User(s)']"
    @browser.wait_for_element_visible RegisterMinglePageId::NOTICE_ID
  end


  def create_new_users(logins_and_names)
    logins_and_names.collect do |login_and_name|
      User.create({:password => MINGLE_TEST_DEFAULT_PASSWORD, :password_confirmation => MINGLE_TEST_DEFAULT_PASSWORD}.merge(login_and_name))
    end
  end

  def destroy_users_by_logins(*user_logins)
    user_logins.each do |login|
      User.find_by_login(login).destroy
    end
  end

  def click_user_display_name(user)
    @browser.click_and_wait(user_display_name_link(user))
  end

  def click_next_page_link_on_users_list
    @browser.click_and_wait next_page_link_on_users_page
  end

  def click_previous_link_on_users_list
    @browser.click_and_wait prev_page_link_on_users_page
  end

  def click_last_login_column
    @browser.with_ajax_wait{@browser.click LoginAndUserProfilePageId::LAST_LOGIN_COLUMN_ID}
  end

  def open_tab_on_profile_page(tab_name)
    @browser.with_ajax_wait{@browser.click(tab_link_on_profile_page(tab_name))}
  end

  def delete_personal_favorite(favorite_order)
    @browser.with_ajax_wait do
      @browser.click(personal_favorite_delete_link(favorite_order))
    end
    @browser.assert_confirmation 'Are you sure?'
  end


end
