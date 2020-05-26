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

# Tags: scenario, project
class Scenario23ProjectCrudTest < ActiveSupport::TestCase


  fixtures :users, :login_access
  LICENSED_TO = 'ThoughtWorks Inc.'
  VALID_LICENSE_KEY = "NhsCbWb5BLSybiIBpWNM38jbYOchxr+opf53mj7vMlyAunTNZoUyV88CRF3P
  VJ+WJ79x17Di7YG22zSXecXNjBNo4A+0vxB5ytUzBiqfj6DSpHS1KOlJyDD1
  e7xQpU8OwwzMYXzP7hVdDMk9jMYi/nQfb8WGdfSl6K905tfxKqP+MomUyoE0
  FC+jTKr0ncnKilaRv4alOj5bBucTxqLKiJm4HTOOt9+KSpDonTzF+R7oLCgf
  6CXLOn594Bfk9ASwEyeTaargIpSyjrI15g0vz5ZgObCdS+ykghfTeiU7bPEr
  36m1xd6PXT5kzbIWGVovLcCIeD6VfgEaU1cssATQ4A=="

  # Expiration date: 2007-09-27
  EXPIRED_LICENSE_KEY = "XPdcBYNClmuNSerQDzS5p3MMgTE8bOKFvw5l3/QDba2ChzcH5WNzr7+b6rFm
  ARXZ5SVj5BOjjPG7BWCYgCnr1i9ENKddvrqkAzIH+6DMG9XmxsOShWFR33/j
  tO+p4C6nlCuTlCMWb2W5obccvAjWsCRmoK8Ia8gYiS4d977EnmI4XiiO/YTv
  rOMobIV+H/Ag7lBwqpnYIwasz70SuzlqmVw5/k4GeB9AS8iTP1ja3xc6BZnw
  g1/L5fP7KeCypg0oW/M1wHrGHhhXgM4sbM7gBwLa+3qjT2i1e9iigjLGBE8v
  oXVomTyv8tDC6YQ77JHej/6ZbG6IV0ZjP64QueaUVg=="

  BAD_REPOS_PATH_ERROR_MESSAGE = 'Error in connection with repository. Please contact your Mingle administrator and check your logs.'

  def setup
    @mingle_admin = users(:admin)
    @project_admin = users(:proj_admin)
    @team_member = users(:project_member)
    @read_only_user = users(:read_only_user)
    @full_user = users(:bob)
    @another_full_user = users(:existingbob)
    @one_more_full_user = users(:longbob)
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    reset_license
    @browser = selenium_session
    @project = create_project(:prefix => 'scenario_23', :users => [@mingle_admin, @team_member, @project_admin, @full_user, @another_full_user, @one_more_full_user], :read_only_users => [@read_only_user])
    login_as_admin_user
    navigate_to_all_projects_page
  end

  def teardown
    @browser.disable_license_decrypt
    reset_license
  end

  def test_that_canceling_new_project_takes_back_to_projects_list_page
    navigate_to_all_projects_page
    click_new_project_link
    click_cancel_create_project_button
    @browser.assert_location '/'
  end

  # story 5426
  def test_as_member_checkbox_should_be_checked_when_auto_enroll_all_users_on_new_project_creation
    click_new_project_link
    click_show_advanced_options_link
    assert_auto_enroll_all_users_checkbox_is_unchecked
    uncheck_I_will_be_a_member_checkbox
    check_auto_enroll_all_users_in_checkbox
    assert_I_will_be_a_member_checkbox_checked
    assert_disabled("as_member")
    uncheck_auto_enroll_all_users_in_checkbox
    assert_I_will_be_a_member_checkbox_checked
    assert_enabled("as_member")
  end

  def test_auto_enroll_user_as_full_team_member_on_full_user_and_light_user_when_create_new_project
    new_project_name = "auto_enroll_as_full_users"
    navigate_to_user_management_page
    light_user = users(:existingbob)
    check_light_user_check_box_for(light_user)

    navigate_to_all_projects_page
    click_new_project_link
    click_show_advanced_options_link
    type_project_name(new_project_name)
    type_project_identifier(new_project_name)
    check_auto_enroll_all_users_in_checkbox
    click_create_project_button

    project = Project.find_by_identifier(new_project_name)
    navigate_to_team_list_for(project)
    assert_user_is_normal_team_member(@full_user)
    assert_user_is_read_only_team_member(light_user)
    assert_disable_auto_enroll_button_is_present
  end

  def test_auto_enroll_user_as_read_only_team_member_on_full_user_and_light_user_when_create_new_project
    new_project_name = "auto_enroll_as_read_only_users"
    navigate_to_user_management_page
    light_user = users(:existingbob)
    check_light_user_check_box_for(light_user)

    navigate_to_all_projects_page
    click_new_project_link
    click_show_advanced_options_link
    type_project_name(new_project_name)
    type_project_identifier(new_project_name)
    check_auto_enroll_all_users_in_checkbox
    click_auto_enroll_as_read_only_button
    click_create_project_button
    project = Project.find_by_identifier(new_project_name)
    navigate_to_team_list_for(project)
    assert_user_is_read_only_team_member(@full_user)
    assert_user_is_read_only_team_member(light_user)
    assert_disable_auto_enroll_button_is_present
  end

  def test_cannot_create_project_with_duplicated_name_but_different_project_identifier
    project_name = 'test project 1'
    create_new_project(project_name)
    click_all_projects_link
    click_new_project_link
    type_project_name(project_name)
    type_project_identifier('test_project_2')
    click_create_project_button
    assert_error_message('Name has already been taken')
    assert_error_message_does_not_contain("Identifier can't be blank")
  end

  # for bug 387
  def test_can_not_create_with_empty_project_name
    navigate_to_all_projects_page
    click_new_project_link
    type_project_name('  ')
    click_create_project_button
    assert_error_message("Name can't be blank")
    click_cancel_link
    @browser.assert_text_not_present("Name can't be blank.")
  end

  # bug 644
  def test_cannont_create_multiple_projects_with_the_same_name_and_same_identifier
    project_name = 'foo bar'
    project_name_with_extra_spaces = 'foo     bar'
    navigate_to_all_projects_page
    create_new_project project_name
    navigate_to_all_projects_page
    create_new_project project_name
    assert_error_message_without_html_content_includes("Name has already been taken")
    assert_error_message_without_html_content_includes("Identifier has already been taken")
    navigate_to_all_projects_page
    create_new_project project_name_with_extra_spaces
    assert_error_message("Name has already been taken")
  end

  # bug 870
  def test_error_message_for_bad_repos_persists
    navigate_to_subversion_repository_settings_page(@project)
    type_project_repos_path('foo')
    click_save_settings_link
    click_source_tab
    assert_error_message(BAD_REPOS_PATH_ERROR_MESSAGE)
    navigate_to_history_for(@project)
    assert_error_message_not_present
    @browser.assert_text_not_present(BAD_REPOS_PATH_ERROR_MESSAGE)
  end

  # bug 921
  def test_strip_leading_and_trailing_whitespace_from_project_name_and_identifier
    name_with_leading_and_trailing_whitespace = ' foo project '
    name_without_whitespace = 'foo project'
    create_new_project name_with_leading_and_trailing_whitespace

    @browser.assert_element_does_not_match('notice', /Project #{name_with_leading_and_trailing_whitespace} successfully created./)
    assert_notice_message("Project #{name_without_whitespace} successfully created.")

    assert_link_not_present("/projects/_foo_project_")
    assert_link_present("/projects/foo_project")
  end

  # bug 952
  def test_correct_verb_tense_on_project_delete_confirmation_page
    open_project(@project)
    delete_project @project
    @browser.assert_text_present 'This project currently has no cards and no pages.'
    @browser.click_and_wait "cancel_bottom"

    open_project(@project)
    create_new_card(@project, :name => 'some story')
    create_new_wiki_page(@project, 'new page', 'foo')
    delete_project @project
    @browser.assert_text_present 'This project currently has 1 card and 1 page.'

    @browser.click_and_wait "cancel_top"
    open_project(@project)
    create_new_card(@project, :name => 'second story')
    create_new_wiki_page(@project, 'another page', 'foo')
    delete_project @project
    @browser.assert_text_present 'This project currently has 2 cards and 2 pages.'
  end

  # bug 954
  def test_delete_existing_project
    project_name = 'testing'
    Project.connection.execute("DROP TABLE #{project_name}_cards") if Project.connection.table_exists?("#{project_name}_cards")
    Project.connection.execute("DROP TABLE #{project_name}_card_versions") if Project.connection.table_exists?("#{project_name}_card_versions")

    create_new_project project_name
    @project = Project.find_by_name(project_name)
    @project.activate
    create_new_card(@project, :name => 'some test')
    delete_project_permanently(@project)
    @browser.assert_location '/'
    assert_link_not_present("/projects/#{project_name}")
  end

  # bug 963
  def test_can_create_project_with_name_that_begins_with_integer
    project_name = '12 march testing'
    create_new_project project_name
    assert_notice_message("Project #{project_name} successfully created.")
    @browser.assert_location "/projects/project_12_march_testing/overview"
  end

  # bug 965
  def test_delete_empty_project
    project_name = 'testing'
    Project.connection.execute("DROP TABLE #{project_name}_card_versions") if Project.connection.table_exists?("#{project_name}_card_versions")
    Project.connection.execute("DROP TABLE #{project_name}_cards") if Project.connection.table_exists?("#{project_name}_cards")
    create_new_project(project_name)
    assert_notice_message("Project #{project_name} successfully created.")
    delete_project_permanently(Project.find_by_name(project_name))
    @browser.assert_location('/')
    assert_link_not_present("/projects/#{project_name}")
  end

  # bug 1107
  def test_template_selection_not_present_when_no_templates_are_available
    @browser.open('/admin/projects/new')
    @browser.assert_text_not_present('How would you like to create your project?')
  end

  # bug 1238
  def test_project_create_fields_remove_leading_and_trailing_whitespace
    name = 'testing project'
    identifier = 'testing_project'
    description = 'this is for testing'
    email_sender = 'the admin'
    email_address = 'admin@foo.com'
    repos_path = '/Users/svn/repos'
    create_new_project(with_excess_whitespace(name), :identifier => "  #{identifier}  ", :email_sender_name => with_excess_whitespace(email_sender),
    :email_address => with_excess_whitespace(email_address))
    navigate_to_subversion_repository_settings_page(identifier)
    type_project_repos_path(with_excess_whitespace(repos_path))
    click_save_settings_link
    project_from_db = Project.find(:first, :conditions => "identifier LIKE '%#{identifier}%'")
    puts "project: #{project_from_db}"
    assert_equal(name, project_from_db.name)
    assert_equal(identifier, project_from_db.identifier)
    assert_equal(email_sender, project_from_db.email_sender_name)
    assert_equal(email_address, project_from_db.email_address)
    navigate_to_subversion_repository_settings_page(identifier)
    assert_equal(repos_path, MinglePlugins::Source.find_for(project_from_db).repository_path)
  end

  def with_excess_whitespace(text)
    "        #{text}     "
  end

  # bug 1296
  def test_can_delete_project_that_has_transitions
    setup_property_definitions(:status => ['new', 'in progress'])
    transition = create_transition_for(@project, 'start work', :required_properties => {:status => 'new'}, :set_properties => {:status => 'in progress'})
    delete_project_permanently(@project)
    assert_notice_message("#{@project.name} was successfully deleted")
    assert_link_not_present("/projects/#{@project.identifier}")
  end

  # bug #1419
  def test_project_with_repos_path_that_ends_in_forward_slash_does_not_crash_app
    project = 'testing'
    create_new_project(project)
    navigate_to_subversion_repository_settings_page(@project)
    type_project_repos_path('/this/is/bad/')
    click_save_settings_link
    click_source_tab
    assert_error_message(BAD_REPOS_PATH_ERROR_MESSAGE)
    navigate_to_subversion_repository_settings_page(@project)
    type_project_repos_path('/')
    click_save_settings_link
    click_source_tab
    assert_error_message(BAD_REPOS_PATH_ERROR_MESSAGE)
  end

  # bug 1441, 1481
  def test_can_remove_description_repos_path_from_project_settings
    blank = ''
    project = 'testing'
    create_new_project(project)
    navigate_to_subversion_repository_settings_page(@project)
    type_project_repos_path('/this/is/bad/')
    click_save_settings_link
    click_source_tab
    assert_error_message(BAD_REPOS_PATH_ERROR_MESSAGE)
    open_project_admin_for(project)
    type_project_description(blank)
    click_save_link
    navigate_to_subversion_repository_settings_page(@project)
    type_project_repos_path(blank)
    click_save_settings_link
    @browser.assert_element_present('link=Source')
    open_project_admin_for(project)
    @browser.assert_value('project_description', blank)
    navigate_to_subversion_repository_settings_page(@project)
    assert_project_repository_path(blank)
  end

  # bug 2964
  def test_invalid_value_for_project_idenitifier_does_not_replace_valid_value
    invalid_identifier = 'invalid_id 2.0'
    navigate_to_project_admin_for(@project)
    type_project_identifier(invalid_identifier)
    click_save_link
    assert_error_message("Identifier may contain only lower case letters, numbers and underscore")
    assert_project_identifier(@project.identifier)
    click_project_link_in_header(@project)
    @browser.assert_location("/projects/#{@project.identifier}/overview")
  end

  #bug 1358
  def test_click_link_to_user_on_the_project_delete_warning_page_should_direct_to_profile_page
    navigate_to_all_projects_page
    delete_project(@project)
    click_user_on_project_delete_warning_page(@mingle_admin.name)
    assert_text_present("#{@mingle_admin.name} is an administrator.")
  end

  # Bug 4276
  def test_creating_project_with_multiple_special_chars_does_not_throw_resource_not_fount_error
    project_name_with_bangs = "bang!!!!"
    create_new_project(project_name_with_bangs)
    assert_notice_message("Project #{project_name_with_bangs} successfully created.")
  end

  # bug 4882
  def test_creating_template_doesnot_make_existing_project_lose_history
    page_name = "page"
    card_name = "new card"
    create_new_wiki_page(@project, page_name, "content")
    card_number = create_new_card(@project, :name => card_name)
    navigate_to_history_for @project, :today
    assert_history_for(:card, card_number).version(1).shows(:created_by => "admin@email.com")
    assert_page_history_for(:page, page_name).version(1).shows(:changed => 'Content')
    create_template_for(@project)
    navigate_to_history_for @project, :today
    assert_page_history_for(:page, page_name).version(1).shows(:changed => 'Content')
  end

  def test_create_project_with_membership_requestable_should_allow_nonmember_seeing_it
     create_a_project_with(:name => 'membership requestable project', :membership_requestable => true)
     login_as_non_project_member
     navigate_to_all_projects_page
     @browser.assert_text_present('membership requestable project')
  end

  #Story 8782
  def test_should_able_to_see_the_warning_message_when_there_is_no_project_in_current_instance
    login_as_admin_user
    assert_create_your_first_project_messsage_not_present
    delete_project_permanently(@project)
    assert_create_your_first_project_messsage_present
    login_as_proj_admin_user
    assert_create_your_first_project_messsage_not_present
    login_as_read_only_user
    assert_create_your_first_project_messsage_not_present
    login_as_project_member
    assert_create_your_first_project_messsage_not_present
  end

  def test_warning_message_given_when_license_in_violation
    delete_project_permanently(@project)
    @browser.enable_license_decrypt
    set_new_license_for_project(EXPIRED_LICENSE_KEY, LICENSED_TO)
    assert_successful_registration_message
    assert_license_expired_message
    navigate_to_all_projects_page
    assert_no_projects_available_warning_present
    assert_create_your_first_project_messsage_not_present
    login_as_proj_admin_user
    assert_no_projects_available_warning_present
    assert_create_your_first_project_messsage_not_present
    login_as_read_only_user
    assert_no_projects_available_warning_present
    assert_create_your_first_project_messsage_not_present
    login_as_project_member
    assert_no_projects_available_warning_present
    assert_create_your_first_project_messsage_not_present
    reset_license
  end

  def test_click_on_the_create_new_project_link_on_warning_message_should_take_user_to_new_project_page
    delete_project_permanently(@project)
    click_link("Create the first project now")
    @browser.assert_location("/admin/projects/new")
  end
end
