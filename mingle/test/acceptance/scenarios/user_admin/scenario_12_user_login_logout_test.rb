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

# Tags: scenario, user, #29, profile
class Scenario12UserLoginLogoutTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_member = users(:project_member)
    @project = create_project(:prefix => 'scenario_12', :users => [@project_member, users(:bob)])
    @another_project = create_project(:prefix => 'scenario_12_another', :users => [users(:project_member), users(:bob)])
    @project_name = @project.identifier
  end

  # bug 1708
  def test_login_trims_leading_and_trailing_whitespace
    logout
    navigate_to_login_page
    @browser.type "user_login", "  bob   "
    @browser.type "user_password", "  #{MINGLE_TEST_DEFAULT_PASSWORD}    "
    @browser.click_and_wait "name=commit"
    assert_notice_message('Sign in successful')
    @browser.assert_text_present "bob@email.com"
  end

  def test_requires_login_when_opening_overview_page_and_not_logged_in
    logout
    navigate_to_login_page
    @browser.assert_text_present 'Sign-in'
    @browser.type "user_login", "bob"
    @browser.type "user_password", MINGLE_TEST_DEFAULT_PASSWORD
    @browser.click_and_wait "name=commit"
    @browser.assert_text_present "bob@email.com"
    @browser.click_and_wait 'link=Sign out'
    @browser.assert_location "/profile/login"
  end

  def test_bad_login
    logout
    navigate_to_login_page
    login_as('non_existing_user', 'password')
    @browser.assert_element_not_present 'current-user'
    @browser.assert_element_matches 'error', /Wrong sign-in name or password/
    @browser.assert_location '/profile/login'
    @browser.assert_value 'user_login', 'non_existing_user'
    @browser.assert_value 'user_password', ''
  end

  # bug 671
  def test_user_entered_username_remains_after_error
    bad_username = "foo@bar.com"
    logout
    navigate_to_login_page
    @browser.assert_text_present 'Sign-in'
    @browser.type "user_login", bad_username
    @browser.type "user_password", MINGLE_TEST_DEFAULT_PASSWORD
    @browser.click_and_wait "name=commit"
    @browser.assert_value "user_login", bad_username
  end

  # bug 1432
  def test_sign_out_and_profile_links_should_not_appear_on_logout_or_login_pages
    login_as_project_member
    assert_sign_out_link_present
    assert_profile_link_present_for(@project_member)
    logout
    assert_sign_out_link_not_present
    assert_profile_link_not_present_for(@project_member)
    assert_sign_out_link_not_present
    assert_profile_link_not_present_for(@project_member)
  end

  # bug 2518
  def test_login_page_does_not_have_sign_in_link
    logout
    navigate_to_login_page
    @browser.assert_element_not_present("link=Sign in")
  end

  # bug 2588
  def test_user_without_any_projects_does_not_get_were_sorry_upon_login
    login_as_non_project_member
    assert_notice_message('Sign in successful')
    navigate_to_all_projects_page
    @browser.assert_element_matches('no-projects', /You are currently not a member of any project./)
  end

  def test_user_can_not_navigate_app_after_logout
    login_as_project_member
    navigate_to_card_list_for @project_name
    logout

    assert_redirected_to_login_when_opening "/"
    assert_redirected_to_login_when_opening "/projects/#{@project_name}/cards"
    assert_redirected_to_login_when_opening "/projects/#{@project_name}/cards/1"
    assert_redirected_to_login_when_opening "/projects/#{@project_name}/cards/list"
    assert_redirected_to_login_when_opening "/projects/#{@project_name}/cards/new"
    assert_redirected_to_login_when_opening "/projects/#{@project_name}/cards_import/import"
    assert_redirected_to_login_when_opening "/projects/#{@project_name}/cards_import/list/"
    assert_redirected_to_login_when_opening "/projects/#{@project_name}"
    assert_redirected_to_login_when_opening "/projects/#{@project_name}/wiki/Overview_Page"
    assert_redirected_to_login_when_opening "/admin/projects/new"
    assert_redirected_to_login_when_opening "/admin/templates"
    assert_redirected_to_login_when_opening "/projects/import"
    assert_redirected_to_login_when_opening "/projects/edit/#{@project.id}"
    assert_redirected_to_login_when_opening "/projects/edit/#{@another_project.id}"
    assert_redirected_to_login_when_opening "/projects/delete/projects/#{@project_name}"
    assert_redirected_to_login_when_opening "/projects/confirm_delete/projects/#{@project_name}"
    assert_redirected_to_login_when_opening "/projects/#{@project_name}/admin/export"
    assert_redirected_to_login_when_opening "/projects/#{@project_name}/admin/export?export_as_template=true"
    assert_redirected_to_login_when_opening "/projects/#{@project_name}/projects/import"
    assert_redirected_to_login_when_opening "/projects/#{@project_name}/property_definitions"
    assert_redirected_to_login_when_opening "/projects/#{@project_name}/property_definitions/new"
    assert_redirected_to_login_when_opening "/projects/#{@project_name}/tags/list"
    assert_redirected_to_login_when_opening "/projects/#{@project_name}/tags/new"
    assert_redirected_to_login_when_opening "/projects/#{@project_name}/favorites/list"
    assert_redirected_to_login_when_opening "/projects/#{@project_name}/transitions/list"
    assert_redirected_to_login_when_opening "/projects/#{@project_name}/transitions/new"
    assert_redirected_to_login_when_opening "/projects/#{@project_name}/wiki/list"
    assert_redirected_to_login_when_opening "/projects/#{@project_name}/team/list"
    assert_redirected_to_login_when_opening "/projects/#{@project_name}/search?=q"
    assert_redirected_to_login_when_opening "/projects/#{@project_name}/history"
    assert_redirected_to_login_when_opening "/users/list"
    assert_redirected_to_login_when_opening "/users/new"
    assert_redirected_to_login_when_opening "/profile/show/1"
    assert_redirected_to_login_when_opening "/profile/edit_profile/1"
    assert_redirected_to_login_when_opening "/profile/change_password/1"
  end

  # bug 4238
  def test_can_cancel_out_of_password_recovery_screen_and_still_login_afterwards
    logout
    click_forgotten_password_link
    click_cancel_button
    login_as_project_member
    assert_notice_message('Sign in successful')
  end

  # bug 4466
  def test_recover_password_link_does_not_throw_error
    recover_password_for('bob')
    assert_notice_message('We have sent an email to the address we have on record. Respond to it within an hour to reactivate your account.')
  end

  def assert_redirected_to_login_when_opening(path)
    @browser.open "#{path}"
    @browser.assert_location ("/profile/login")
  end

  def test_user_login_attempt_more_than_10_times_block_for_a_min
    create_user! :login => 'too_many_attempts_bob'
    logout
    @browser.type "user_login", "too_many_attempts_bob"
    11.times{@browser.click_and_wait "name=commit"}
    assert_warning_message_matches("You have attempted to log in 10 times. Please try again in one minute.")
    @browser.type "user_login", "too_many_attempts_bob"
    @browser.type "user_password", MINGLE_TEST_DEFAULT_PASSWORD
    @browser.click_and_wait "name=commit"
    assert_warning_message_matches("You have attempted to log in 10 times. Please try again in one minute.")
  end

  def test_should_clean_expired_sessions_when_a_new_user_login
    Session.delete_all
    fake_now(2011, 03, 04)
    navigate_to_login_page
    @browser.type "user_login", "bob"
    @browser.type "user_password", MINGLE_TEST_DEFAULT_PASSWORD
    @browser.click_and_wait "name=commit"
    assert_notice_message('Sign in successful')

    assert_equal 1, Session.count

    fake_now(2011, 03, 4+8)
    navigate_to_login_page

    # a get login page action should not trigger clean expired session
    # but a get will create a new session
    assert_equal 2, Session.count

    @browser.type "user_login", "bob"
    @browser.type "user_password", MINGLE_TEST_DEFAULT_PASSWORD
    @browser.click_and_wait "name=commit"
    assert_notice_message('Sign in successful')
    assert_equal 1, Session.count
  ensure
    @browser.reset_fake
  end

end
