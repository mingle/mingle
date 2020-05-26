# encoding : utf-8

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

require File.expand_path(File.dirname(__FILE__) + '/../../../acceptance/acceptance_test_helper')

# Tags: scenario, user, mingle-admin
class Scenario32SignUpFirstUserTest < ActiveSupport::TestCase 

  BLANK = ''
  VALID_LOGIN = 'mefoo'
  VALID_EMAIL = 'me@foo.com'
  VALID_NAME = 'me@name.com'
  VALID_PASSWORD = 'password1.'
  ANOTHER_VALID_PASSWORD = 'pw0rd.'
  ANOTHER_VALID_EMAIL = 'newmail@foo.com'

  LOGIN_BLANK = "Sign-in name can't be blank"
  LOGIN_INVALID = "Sign-in name is invalid"
  LOGIN_TOO_SHORT = "Sign-in name is too short (minimum is 3 characters)"
  LOGIN_TOO_LONG = "Sign-in name is too long (maximum is 255 characters)"
  NAME_BLANK = "Display name can't be blank"
  EMAIL_ALREADY_TAKEN = 'Email has already been taken'
  EMAIL_TOO_SHORT = 'Email is too short (minimum is 3 characters)'
  EMAIL_TOO_LONG = 'Email is too long (maximum is 255 characters)'
  EMAIL_INVALID = 'Email is invalid'
  PASSWORD_TOO_SHORT = 'Password is too short (minimum is 5 characters)'
  PASSWORD_TOO_LONG = 'Password is too long (maximum is 40 characters)'
  PASSWORD_BLANK = "Password can't be blank"
  PASSWORD_CONFIRM_BLANK = "Password confirmation can't be blank"
  PASSWORD_DOES_NOT_MATCH_CONFIRM = "Password doesn't match confirmation"
  PASSWORD_NEEDS_DIGIT = "Password needs at least one digit"
  PASSWORD_NEEDS_NON_CHARACTER_SYMBOL = "Password needs at least one non-character symbol (e.g. \".\", \",\" or \"-\")"
  does_not_work_on_ie
  
  def setup
    destroy_all_records(:destroy_users => true, :destroy_projects => true)
    ActiveSupport::TestCase.close_selenium_sessions
    @browser = selenium_session
    logout
    navigate_to_all_projects_page
    @browser.click_and_wait 'next'
    @browser.assert_location '/install/signup'
  end

  # Login field tests
  def assert_login_can_not_be_blank
    fill_in_and_submit_signup_user_fields(BLANK, VALID_EMAIL, VALID_PASSWORD, VALID_PASSWORD)
    assert_error_message_on_signup(LOGIN_BLANK)
  end

  def test_login_maximum
    too_long_login = 'a'*256
    fill_in_and_submit_signup_user_fields(too_long_login, VALID_EMAIL, VALID_PASSWORD, VALID_PASSWORD)
    assert_error_message_on_signup(LOGIN_TOO_LONG)

    longest_allowed_login = 'a'*255
    fill_in_and_submit_signup_user_fields(longest_allowed_login, BLANK, BLANK, BLANK)
    @browser.assert_text_not_present(LOGIN_TOO_LONG)
  end

  def test_login_minimum_one_characters
    two_character_login = 'P'
    fill_in_and_submit_signup_user_fields(two_character_login, VALID_EMAIL, VALID_PASSWORD, VALID_PASSWORD)
    @browser.assert_text_not_present(LOGIN_TOO_SHORT)
  end

  def test_login_cannot_contain_spaces
    login_with_space = 'foo bar'
    fill_in_and_submit_signup_user_fields(login_with_space, VALID_EMAIL, VALID_PASSWORD, VALID_PASSWORD)
    assert_error_message_on_signup(LOGIN_INVALID)
  end

  def test_login_cannot_caontain_illegal_characters
    illegal_characters = ['!', '#', '$', '%', '^', '&', '*', '>', '<', ':', '\'环境', '/', "\"", "\'", '~', '`']
    illegal_characters.each do |illegal_character|
      login_with_illegal_character = 'foo' + illegal_character
      fill_in_and_submit_signup_user_fields(login_with_illegal_character, BLANK, BLANK, BLANK)
      assert_error_message_on_signup(LOGIN_INVALID)
    end
  end
    
  def test_name_can_not_be_blank
    fill_in_and_submit_signup_user_fields(VALID_LOGIN, VALID_EMAIL, VALID_PASSWORD, VALID_PASSWORD, BLANK)
    assert_error_message_on_signup(NAME_BLANK)
  end
  
  def test_email_maximum_255_characters
    email_user = 'a' * (256 - '@example.com'.length)
    fill_in_and_submit_signup_user_fields(VALID_LOGIN, "#{email_user}@example.com", VALID_PASSWORD, VALID_PASSWORD)
    assert_error_message_on_signup(EMAIL_TOO_LONG)
    
    email_user = 'a' * (255 - '@example.com'.length)
    fill_in_and_submit_signup_user_fields(VALID_LOGIN, "#{email_user}@example.com", BLANK, BLANK)
    @browser.assert_text_not_present(EMAIL_TOO_LONG)
  end
  
  def test_email_must_be_valid
    email_without_extension = 'email@addy'
    fill_in_and_submit_signup_user_fields(VALID_LOGIN, email_without_extension, VALID_PASSWORD, VALID_PASSWORD)
    assert_error_message_on_signup(EMAIL_INVALID)
    
    email_without_at_symbol = 'emailaddy.com'
    fill_in_and_submit_signup_user_fields(VALID_LOGIN, email_without_at_symbol, VALID_PASSWORD, VALID_PASSWORD)
    @browser.assert_text_present(EMAIL_INVALID)
  end
  
  def test_email_minimum_three_characters
    fill_in_and_submit_signup_user_fields(VALID_LOGIN, 'fo', VALID_PASSWORD, VALID_PASSWORD)
    assert_error_message_on_signup(EMAIL_TOO_SHORT)
    
    fill_in_and_submit_signup_user_fields(VALID_LOGIN, 'foo', VALID_PASSWORD, VALID_PASSWORD)
    @browser.assert_text_not_present(EMAIL_TOO_SHORT)
  end
  
  # password field tests
  def test_neither_password_nor_password_confirmation_can_be_blank
    fill_in_and_submit_signup_user_fields(VALID_LOGIN, VALID_EMAIL, BLANK, VALID_PASSWORD)
    assert_error_message_on_signup(PASSWORD_BLANK)
    
    fill_in_and_submit_signup_user_fields(VALID_LOGIN, VALID_EMAIL, VALID_PASSWORD, BLANK)
    @browser.assert_text_present(PASSWORD_CONFIRM_BLANK)
    @browser.assert_text_present(PASSWORD_DOES_NOT_MATCH_CONFIRM)
  end
  
  def test_password_fields_maximum_forty_characters 
    forty_one_character_password = 'reginaldthewonderdog@fourfourfourfourfo1!' #41 characters
    fill_in_and_submit_signup_user_fields(VALID_LOGIN, VALID_EMAIL, forty_one_character_password, forty_one_character_password)
    assert_error_message_on_signup(PASSWORD_TOO_LONG)
    
    forty_character_password = 'reginaldthewonderdogfourfourfourfourfo1!' #40 characters
    fill_in_and_submit_signup_user_fields(VALID_LOGIN, VALID_EMAIL, forty_character_password, forty_character_password)
    @browser.assert_text_not_present(PASSWORD_TOO_LONG)
  end
  
  def test_password_minimum_five_characters
    four_character_password = 'ab3!'
    fill_in_and_submit_signup_user_fields(VALID_LOGIN, VALID_EMAIL, four_character_password, four_character_password)
    assert_error_message_on_signup(PASSWORD_TOO_SHORT)
    
    five_character_password = 'two34!'
    fill_in_and_submit_signup_user_fields(VALID_LOGIN, VALID_EMAIL, five_character_password, five_character_password)
    @browser.assert_text_not_present(PASSWORD_TOO_SHORT)
  end
  
  def test_password_needs_at_least_one_digit
    password_without_digit = 'FOO!'
    fill_in_and_submit_signup_user_fields(VALID_LOGIN, VALID_EMAIL, password_without_digit, password_without_digit)
    assert_error_message_on_signup(PASSWORD_NEEDS_DIGIT)
  end
  
  def test_password_needs_at_least_one_punctuation
    password_without_punctuation = '1bar'
    fill_in_and_submit_signup_user_fields(VALID_LOGIN, VALID_EMAIL, password_without_punctuation, password_without_punctuation)
    assert_error_message_on_signup(PASSWORD_NEEDS_NON_CHARACTER_SYMBOL)
  end
  
  def fill_in_and_submit_signup_user_fields(login, email, password, password_confirmation, name=VALID_NAME)
    @browser.type('user_login', login)
    @browser.type('user_email', email)
    @browser.type('user_name', name)
    @browser.type('user_password', password)
    @browser.type('user_password_confirmation', password_confirmation)
    @browser.click_and_wait "name=commit"
  end
  
  def assert_error_message_on_signup(error)
    if(@browser.is_element_present(class_locator('field_error')))
      @browser.assert_text_present(error)
    else
      raise "no error thrown on page... when expected an error."
    end
  end
  
end
