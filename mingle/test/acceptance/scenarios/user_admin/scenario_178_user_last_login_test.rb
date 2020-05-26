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

# Tags: user
class Scenario178UserLastLoginTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @mingle_admin = users(:admin)
    @project_admin = users(:proj_admin)
    @project_member = users(:project_member)
    @read_only_user = users(:read_only_user)

    @project = create_project(:prefix => 'last_login',  :admins => [@mingle_admin, @project_admin], :users => [@project_member], :read_only_users => [@read_only_user], :anonymous_accessible => true)
  end

  # bug #11536
  def test_should_update_login_for_user_whose_session_time_out_but_has_remember_me
    fake_now(2000, 1, 1, 1, false)
    login_and_remember_me(@mingle_admin.login)
    login_time = formatted_time
    navigate_to_user_management_page
    assert_last_login_text_for_user(@mingle_admin, login_time)

    fake_now(2000, 1, 1, 3, false)
    navigate_to_user_management_page
    assert_last_login_text_for_user(@mingle_admin, login_time)

    # session timed out 8 days later
    fake_now(2000, 1, 1+8, 3, false)
    navigate_to_user_management_page
    assert_last_login_text_for_user(@mingle_admin, formatted_time)
  ensure
    @browser.reset_fake
  end

  def test_mingle_admin_can_see_last_login_information
    fake_now(2000, 1, 1, 1, false)

    bob = login_as('bob')
    login_as_admin_user
    navigate_to_user_management_page
    assert_table_column_headers_and_order('users', 'Display name', 'Sign-in name', 'Email', 'Version control user name', 'Light user', 'Administrator', 'Last login', 'Activate/Deactivate')
    assert_last_login_text_for_user(bob, formatted_time)
  end

  def test_deactivated_user_still_displays_last_login
    fake_now(2000, 1, 1, 1, false)
    as_project_member {}
    as_admin do
      toggle_activation_for(@project_member)

      assert_last_login_text_for_user(@project_member, formatted_time)
      toggle_activation_for(@project_member)
    end
  end

  def test_never_logged_in_users_show_blank_in_last_login
    as_admin do
      navigate_to_user_management_page
      assert_last_login_text_for_user(@project_member, '')
    end
  end

  def test_searched_user_also_shows_last_login
    fake_now(2000, 1, 1, 1, false)
    as_read_only_user {}
    as_admin do
      navigate_to_user_management_page
      search_user_in_user_management_page(@read_only_user.name)
      assert_table_column_headers_and_order('users', 'Display name', 'Sign-in name', 'Email', 'Version control user name', 'Light user', 'Administrator', 'Last login', 'Activate/Deactivate')
      assert_last_login_text_for_user(@read_only_user, formatted_time)
    end
  end

  #bug 10599
  def test_deactivated_user_attempt_to_login_does_not_update_last_login
    as_admin do
      toggle_activation_for(@project_member)
    end

    as_project_member {}

    as_admin do
      navigate_to_user_management_page
      assert_last_login_text_for_user(@project_member, '')
      toggle_activation_for(@project_member) #toggling back as some other test run after this could use @project_member
    end
  end

  # bug 10611
  def test_mingle_admin_should_still_see_last_login_when_license_is_violated
    register_limited_license_that_allows_anonymous_users(2, 0)
    login_as_admin_user
    navigate_to_user_management_page
    assert_table_column_headers_and_order('users', 'Display name', 'Sign-in name', 'Email', 'Version control user name', 'Light user', 'Administrator', 'Last login', 'Activate/Deactivate')
    reset_license
  end

  private
  def assert_last_login_text_for_user(user, text)
    if text.blank?
      @browser.assert_element_not_present("css=#user_#{user.id} abbr[class=\"timeago\"]")
    else
      @browser.assert_element_present("css=#user_#{user.id} abbr[class=\"timeago\"][title=\"#{text}\"]")
    end
  end

  def login_and_remember_me(username, password = MINGLE_TEST_DEFAULT_PASSWORD)
    navigate_to_login_page if @browser.get_eval('this.browserbot.getUserWindow().location.href') !~ /login/
    @browser.type "user_login", username
    @browser.type "user_password", password
    @browser.click "remember_me"
    @browser.click_and_wait "name=commit"
  end

  def  formatted_time
    Clock.now.strftime('%a %b %d %H:%M:%S %Z %Y')
  end

end
