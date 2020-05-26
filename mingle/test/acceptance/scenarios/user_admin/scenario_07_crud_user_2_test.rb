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

require File.expand_path('../../../acceptance/acceptance_test_helper.rb', File.dirname(__FILE__))
require File.expand_path('user_crud_acceptance_support.rb', File.dirname(__FILE__))

# Tags: user
class Scenario07CRUDUser2Test < ActiveSupport::TestCase

  include UserCrudAcceptanceSupport

  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @admin = users(:admin)
    @project_member = users(:project_member)
    @project = create_project(:prefix => 'scenario_07', :users => [@project_member, @admin])
    @browser = selenium_session
    navigate_to_all_projects_page
    login_as_admin_user
  end

  def test_profile_link_on_top_right_corner_refreshes_to_show_correct_user_name
    as_project_member do
      @browser.open "/projects/#{@project.identifier}"
      @browser.click_and_wait(profile_for_user_name_link("member@email.com"))
      @browser.click_and_wait "edit-profile"
      @browser.type 'user_name', 'Sam Jones'
      @browser.type 'user_version_control_user_name', 'sjones'
      click_save_profile_button

      @browser.assert_element_present profile_for_user_name_link('Sam Jones')
    end
  end

  def test_can_delete_user_when_they_do_not_belong_to_any_project_and_have_no_project_data
    team_member = users(:existingbob)
    read_only_user = users(:longbob)
    navigate_to_delete_users_page
    assert_users_deletable(team_member, read_only_user)
    delete_users(team_member, read_only_user)
    navigate_to_user_management_page
    assert_user_is_not_in_user_management_page(team_member)
    assert_user_is_not_in_user_management_page(read_only_user)
  end

  def test_can_delete_user_that_has_not_been_used_in_any_project_history
    bob = users(:bob)
    login_as_admin_user
    add_full_member_to_team_for(@project, bob)
    navigate_to_delete_users_page
    assert_users_deletable(bob)
    delete_users(bob)
    navigate_to_user_management_page
    assert_user_is_not_in_user_management_page(bob)
  end

  def test_can_not_delete_user_that_have_been_used_in_any_project_history
    history_maker = users(:bob)
    add_full_member_to_team_for(@project, history_maker)

    new_card = as_user('bob') do
      create_card!(:name => 'new_card', :description => 'I am a new card')
    end

    as_user('admin') do
      navigate_to_delete_users_page

      assert_users_not_deletable(history_maker)

      remove_from_team_for(@project, history_maker, :update_permanently => true)

      navigate_to_delete_users_page
      assert_users_not_deletable(history_maker)

      delete_card(@project, new_card.name)
      navigate_to_delete_users_page
      assert_users_not_deletable(history_maker)
    end
  end

  # Story 5799  Allow to delete of users who are team members but have not been used in project (History and project data)
  def test_should_be_able_to_delete_one_user_who_doesnt_have_any_history
    bob = users(:bob)
    as_user("admin") do
      navigate_to_team_list_for(@project)
      auto_enroll_all_users_as_full_users(@project)
      navigate_to_delete_users_page
      delete_users(bob)
      navigate_to_user_management_page
      assert_user_is_not_in_user_management_page(bob)
    end
  end

  def test_admin_can_delete_light_and_deactivated_users
    light_user = users(:bob)
    deactived_user = users(:existingbob)

    as_user('admin') do
      navigate_to_user_management_page
      check_light_user_check_box_for(light_user)
      toggle_activation_for(deactived_user)
      navigate_to_delete_users_page
      delete_users(light_user, deactived_user)
      navigate_to_user_management_page
      assert_user_deleted_on_maagement_page(light_user)
      assert_user_deleted_on_maagement_page(deactived_user)
    end

    login_as('bob')
    assert_message_for_wrong_user_and_password
    login_as('existingbob')
    assert_message_for_wrong_user_and_password
  end

  def test_delete_admin_user
    new_admin_user = create_user! :login => 'redshirt', :admin => true, :password => MINGLE_TEST_DEFAULT_PASSWORD, :password_confirmation => MINGLE_TEST_DEFAULT_PASSWORD

    as_user('redshirt') do
      assert_notice_message(SIGN_IN_SUCCESSFUL)
    end

    as_user('admin') do
      navigate_to_delete_users_page
      delete_users(new_admin_user)
      navigate_to_user_management_page
      assert_user_deleted_on_maagement_page(new_admin_user)
    end

    login_as('redshirt')
    assert_message_for_wrong_user_and_password
  end

  def test_error_messages_only_for_blanks_when_no_data_entered_on_register_user
    navigate_to_all_projects_page
    open_mingle_admin_dropdown
    @browser.click_and_wait "link=Manage users"
    @browser.click_and_wait "link=New user"
    click_create_profile_button()
    @browser.assert_text_not_present 'Email is invalid'
    @browser.assert_text_not_present 'Email is too short (minimum is 3 characters)'
    @browser.assert_text_not_present 'Password is too short (minimum is 5 characters)'
    @browser.assert_text_present "Password can't be blank"
    @browser.assert_text_present "Password confirmation can't be blank"
  end

  # bug 296
  def test_error_messages_only_for_blanks_when_no_data_entered_on_edit_user
    navigate_to_all_projects_page
    open_mingle_admin_dropdown
    @browser.click_and_wait "link=Manage users"
    @browser.click_and_wait "link=New user"
    @browser.type 'user_login', 'mefoo'
    @browser.type 'user_email', 'foo@bar.com'
    @browser.type 'user_name', 'foo@bar.com'
    @browser.type 'user_password', 'passw0rd-'
    @browser.type 'user_password_confirmation', 'passw0rd-'
    click_create_profile_button()

    logout

    log_back_in("mefoo", "passw0rd-")
    @browser.click_and_wait profile_for_user_name_link('foo@bar.com')
    @browser.click_and_wait 'edit-profile'
    click_save_profile_button

    @browser.assert_text_not_present 'Email is invalid'
    @browser.assert_text_not_present 'Email is too short (minimum is 3 characters)'
    @browser.assert_text_not_present 'Password is too short (minimum is 5 characters)'

    @browser.click_and_wait profile_for_user_name_link('foo@bar.com')
    @browser.click_and_wait 'link=Change password'
    @browser.type('current_password', "passw0rd-")
    click_change_password_button

    @browser.assert_text_present "Password can't be blank"
    @browser.assert_text_present "Password confirmation can't be blank"
  end

  # bug 823
  def test_edit_last_name_by_starting_with_empty_space
    open_project(@project)
    first_name = 'Con-Fou'
    @browser.click_and_wait profile_for_user_name_link('admin@email.com')
    @browser.click_and_wait 'edit-profile'
    @browser.type 'user_name', ' Master'
    click_save_profile_button

    open_project(@project)
    click_all_tab
    add_new_card '1st Card'
    @browser.run_once_history_generation
    navigate_to_history_for(@project)
    @browser.assert_text_present("by Master")
  end

  # bug 1081 & 1470
  def test_cannot_update_users_email_with_same_email_as_existing_user
    as_project_member do
      open_edit_profile_for(@project_member)
      @browser.type('user_email', "#{@admin.email}")
      click_save_profile_button
      @browser.assert_text_present(EMAIL_ALREADY_TAKEN)
    end

    as_user('admin') do
      open_edit_profile_for(@admin)
      @browser.type('user_email', ANOTHER_VALID_EMAIL)
      click_save_profile_button

      @browser.open("/users/edit_profile/#{@project_member.id}")
      @browser.type('user_email', ANOTHER_VALID_EMAIL)
      click_save_profile_button
      @browser.assert_text_present(EMAIL_ALREADY_TAKEN)
    end
  end

  # bug 1246
  def test_leading_and_trailing_whitespace_is_trimmed_on_create_user_fields
    as_admin do
      navigate_to_all_projects_page
      open_mingle_admin_dropdown
      @browser.click_and_wait("link=Manage users")
      @browser.click_and_wait("link=New user")
      @browser.type "user_login", "     #{VALID_LOGIN}     "
      @browser.type "user_email", "     #{VALID_EMAIL}     "
      @browser.type "user_name", "     #{VALID_NAME}     "
      @browser.type "user_password", "    #{VALID_PASSWORD}    "
      @browser.type "user_password_confirmation", "    #{VALID_PASSWORD}     "
      @browser.type "user_version_control_user_name", "        #{VALID_NAME}    "
      click_create_profile_button
    end

    as_user(VALID_LOGIN, VALID_PASSWORD) do
      assert_notice_message(SIGN_IN_SUCCESSFUL)
      @browser.assert_element_matches("css=.current-user", /#{VALID_NAME}/)
    end

    user_from_db = User.find_by_login(VALID_LOGIN)
    assert_equal(VALID_LOGIN, user_from_db.login)
    assert_equal(VALID_EMAIL, user_from_db.email)
    assert_equal(VALID_NAME, user_from_db.name)
    assert_equal(VALID_NAME, user_from_db.version_control_user_name)
  end

  # bug 1411
  def test_logins_are_case_insensitive
    login = 'FooBar'
    login_as_admin_user
    @browser.open('/users/new')
    add_new_user("#{login}@email.com", VALID_PASSWORD)
    logout
    login_as(login.swapcase, VALID_PASSWORD)
    assert_notice_message(SIGN_IN_SUCCESSFUL)
  end

  # bug 1606
  def test_mulitple_users_can_have_blank_svn_names_in_their_profiles
    as_project_member do
      open_edit_profile_for(@project_member)
      @browser.type('user_version_control_user_name', BLANK)
      click_save_profile_button
      assert_notice_message("Profile was successfully updated for #{@project_member.name}.")
    end

    as_user('admin') do
      open_edit_profile_for(@admin)
      @browser.type('user_version_control_user_name', BLANK)
      click_save_profile_button
      assert_notice_message("Profile was successfully updated for #{@admin.name}.")
    end
  end

  # bug 1795
  def test_can_edit_user_login
    new_login_name = 'FooTime'
    as_project_member do
      open_edit_profile_for(@project_member)
      @browser.type('user_login', new_login_name)
      click_save_profile_button
    end

    as_user(new_login_name) do
      assert_notice_message(SIGN_IN_SUCCESSFUL)
    end

    as_user(new_login_name.upcase) do
      assert_notice_message(SIGN_IN_SUCCESSFUL)
    end
  end

  # bug 13028
  def test_can_delete_user_if_user_has_personal_favorites
    user = create_user!
    @project.add_member(user)
    login(user)
    navigate_to_card_list_for(@project)
    save_current_view_as_my_favorite('my favo')
    login_as_admin_user

    navigate_to_delete_users_page
    delete_users(user)
    @browser.assert_text_present "deleted successfully"
    navigate_to_user_management_page
    assert_user_is_not_in_user_management_page(user)
  end

end
