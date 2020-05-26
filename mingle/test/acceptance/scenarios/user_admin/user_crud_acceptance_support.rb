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

module UserCrudAcceptanceSupport

  BLANK = ''
  VALID_LOGIN = 'mefoo'
  VALID_LOGIN_UPCASED = 'MEFOO'
  ANOTHER_VALID_LOGIN = 'chester'
  VALID_EMAIL = 'me@foo.com'
  VALID_NAME = 'just me'
  VALID_NAME_WITH_HTML = VALID_NAME + '<h2>boo</h2>'
  VALID_PASSWORD = 'password1.'
  ANOTHER_VALID_PASSWORD = 'pw0rd.'
  ANOTHER_VALID_EMAIL = 'newmail@foo.com'

  SIGN_IN_SUCCESSFUL = 'Sign in successful'
  SIGN_IN_NAME_ALREADY_TAKEN = 'Sign-in name has already been taken'
  LOGIN_ALREADY_TAKEN = 'Login has already been taken'
  EMAIL_ALREADY_TAKEN = 'Email has already been taken'
  EMAIL_TOO_SHORT = 'Email is too short (minimum is 3 characters)'
  EMAIL_TOO_LONG = 'Email is too long (maximum is 255 characters)'
  EMAIL_INVALID = 'Email is invalid'
  PASSWORD_TOO_SHORT = 'Password is too short (minimum is 5 characters)'
  PASSWORD_CONFIRM_BLANK = "Password confirmation can't be blank"
  PASSWORD_BLANK = "Password can't be blank"
  PASSWORD_DOESNT_MATCH_CONFIRM = "Password doesn't match confirmation"

  def assert_user_password_change_save_validations
    click_change_password_button
    @browser.assert_text_present PASSWORD_BLANK
    @browser.assert_text_present PASSWORD_CONFIRM_BLANK
  end

  def assert_user_profile_create_validations
    @browser.type 'user_email', 'first@email.com'
    click_create_profile_button
    @browser.assert_text_present EMAIL_ALREADY_TAKEN

    @browser.type 'user_email', 'to'
    click_create_profile_button
    @browser.assert_text_present EMAIL_TOO_SHORT

    @browser.type 'user_email', 'to@'
    click_create_profile_button
    @browser.assert_text_present EMAIL_INVALID
    @browser.assert_text_not_present EMAIL_TOO_SHORT

    email_user = 'a' * (256 - '@example.com'.length)
    @browser.type 'user_email', "#{email_user}@example.com" #256 characters
    click_create_profile_button
    @browser.assert_text_present EMAIL_TOO_LONG

    email_user = 'a' * (255 - '@example.com'.length)
    @browser.type 'user_email', "#{email_user}@example.com" #255 characters
    click_create_profile_button
    @browser.assert_text_not_present EMAIL_INVALID
    @browser.assert_text_not_present EMAIL_TOO_SHORT
  end

  def assert_user_profile_save_validations
    @browser.type 'user_email', 'first@email.com'
    click_save_profile_button
    @browser.assert_text_present EMAIL_ALREADY_TAKEN

    @browser.type 'user_email', 'to'
    click_save_profile_button
    @browser.assert_text_present EMAIL_TOO_SHORT

    @browser.type 'user_email', 'to@'
    click_save_profile_button
    @browser.assert_text_present EMAIL_INVALID
    @browser.assert_text_not_present EMAIL_TOO_SHORT

    email_user = 'a' * (256 - '@example.com'.length)
    @browser.type 'user_email', "#{email_user}@example.com" #256 characters
    click_save_profile_button
    @browser.assert_text_present EMAIL_TOO_LONG

    email_user = 'a' * (255 - '@example.com'.length)
    @browser.type 'user_email', "#{email_user}@example.com" #255 characters
    click_save_profile_button
    @browser.assert_text_not_present EMAIL_INVALID
    @browser.assert_text_not_present EMAIL_TOO_SHORT
  end

  def assert_redirected_to_user_management_page
    @browser.assert_text_present "Users"
  end

end
