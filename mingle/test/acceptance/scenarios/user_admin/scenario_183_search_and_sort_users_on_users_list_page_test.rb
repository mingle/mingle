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
class Scenario183SearchAndSortUsersOnUsersListPageTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project = create_project(:prefix => 'Sce_183')
  end

  # story 5325
  def test_sort_users_by_last_login
    User.create!(:login => "abc", :name => "abc", :password => MINGLE_TEST_DEFAULT_PASSWORD, :password_confirmation => MINGLE_TEST_DEFAULT_PASSWORD)
    login_as('first')
    log_back_in('admin')
    navigate_to_user_management_page
    click_last_login_column

    assert_table_values("users", 1, 1, 'admin')
    assert_table_values("users", 2, 1, 'first')
    #abc is the login of the first user in the 'users never login before' group.
    assert_table_values("users", 3, 1, 'abc')

    click_last_login_column
    assert_table_values("users", 14, 1, 'admin')
    assert_table_values("users", 13, 1, 'first')
    #read_only_user is the login of the last user in the 'users never login before' group.
    assert_table_values("users", 12, 1, 'read_only_user')
  end

  def test_show_or_hide_deactivated_user_should_not_lose_sort_by_on_users_list
    login_as('member')
    log_back_in('first')
    bob = log_back_in('bob')
    log_back_in('admin')

    navigate_to_user_management_page
    click_last_login_column

    assert_table_values("users", 1, 1, 'admin')
    assert_table_values("users", 2, 1, 'bob')
    assert_table_values("users", 3, 1, 'first')
    assert_table_values("users", 4, 1, 'member')

    @browser.click_and_wait("#{bob.html_id}_toggle_activation")
    assert_table_values("users", 1, 1, 'admin')
    assert_table_values("users", 2, 1, 'bob')
    assert_table_values("users", 3, 1, 'first')
    assert_table_values("users", 4, 1, 'member')

    @browser.click_and_wait('show_deactivated_users')
    assert_table_values("users", 1, 1, 'admin')
    assert_table_values("users", 2, 1, 'first')
    assert_table_values("users", 3, 1, 'member')
  end


  def test_navigate_to_other_page_should_not_lose_sort_by_on_users_list
    1.upto(20) do  |i|
      User.create!(:login => "user_#{i}", :name => "user #{i}", :password => MINGLE_TEST_DEFAULT_PASSWORD, :password_confirmation => MINGLE_TEST_DEFAULT_PASSWORD)
    end

    login_as('first')
    log_back_in('admin')
    log_back_in('member')
    log_back_in('admin_with_name_different_than_email_address')

    navigate_to_user_management_page
    click_last_login_column

    assert_table_values("users", 1, 1, 'admin_with_name_different_than_email_address')
    assert_table_values("users", 2, 1, 'member')
    assert_table_values("users", 3, 1, 'admin')
    assert_table_values("users", 4, 1, 'first')

    click_next_page_link_on_users_list
    click_previous_link_on_users_list

    assert_table_values("users", 1, 1, 'admin_with_name_different_than_email_address')
    assert_table_values("users", 2, 1, 'member')
    assert_table_values("users", 3, 1, 'admin')
    assert_table_values("users", 4, 1, 'first')
  end

  def test_search_user_should_not_lose_sort_by_on_users_list
    login_as('first')
    log_back_in('admin')
    log_back_in('member')
    bob = log_back_in('admin_with_name_different_than_email_address')

    navigate_to_user_management_page
    click_last_login_column

    assert_table_values("users", 1, 1, 'admin_with_name_different_than_email_address')
    assert_table_values("users", 2, 1, 'member')
    assert_table_values("users", 3, 1, 'admin')
    assert_table_values("users", 4, 1, 'first')

    search_user_in_user_management_page('admin')
    assert_table_values("users", 1, 1, 'admin_with_name_different_than_email_address')
    assert_table_values("users", 2, 1, 'admin')

    click_clear_search_user_button

    assert_table_values("users", 1, 1, 'admin_with_name_different_than_email_address')
    assert_table_values("users", 2, 1, 'member')
    assert_table_values("users", 3, 1, 'admin')
    assert_table_values("users", 4, 1, 'first')
  end

  #story 10148
  def test_proj_admin_can_search_user_on_user_list
    @team_member = users(:project_member)
    @project_admin = users(:proj_admin)
    project_one = create_project(:prefix => "proj_one", :admins => [@project_admin], :users => [@team_member])
    login_as_proj_admin_user
    navigate_to_user_management_page

    type_search_user_text(@team_member.login)
    click_search_user_button
    assert_search_info_message_contains("Search result for #{@team_member.login}")
    assert_users_are_present(@team_member)
  end
end
