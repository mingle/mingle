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

#Tags: users, project

class Scenario153MembershipRequestingTest < ActiveSupport::TestCase

  fixtures :users, :login_access
  PROJECT_NAME = "request membership test"
  PROJECT_TEMPLATE_NAME = "scenario_153"


  def setup
    server_eval("$original_site_url = MingleConfiguration.site_url ; MingleConfiguration.site_url = 'http://mingle.example.com'")
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project = create_project(:prefix => 'scenario_153', :admins => [users(:proj_admin), users(:bob)], :users => [users(:project_member)])
    login_as_proj_admin_user
  end

  def teardown
    super
    server_eval("MingleConfiguration.site_url = $original_site_url")
  end

  def test_nonmember_requests_membership_send_emails_to_all_project_admins
    update_project_settings_with(@project, :membership_requestable => true)
    configure_smtp_as(:sender_address => 'hello@example.com')

    login_as("existingbob")
    navigate_to_all_projects_page
    request_membership

    there_should_be_a_email_send(
    :from => ['hello@example.com'],
    :to => [users(:proj_admin).email, users(:bob).email],
    :subject => "existingbob@email.com wants to join your project #{@project.name}",
    :body => match_html_text(<<-BODY))

    If you want to add this user to your project, please click the link below.
    http://mingle.example.com/projects/#{@project.identifier}/team/list_users_for_add_member?user_id=1000002

    BODY

    project_admin_use_link_from_last_email_add_requestor_as_full_team_member
    login_as("existingbob")
    open_project(@project)
    assert_error_message_not_present
  end

  def test_admin_can_create_membership_request_able_project
    login_as_admin_user
    navigate_to_all_projects_page
    click_new_project_link
    click_show_advanced_options_link
    assert_project_membership_requestable_present
    create_a_projct_with_membership_requestable_checked(PROJECT_NAME)
    login_as("existingbob")
    open_project(@project)
    assert_project_is_present_and_requestable_but_not_accessible(PROJECT_NAME)
  end

  def test_newly_created_project_is_not_membership_request_able_by_default
    login_as_admin_user
    navigate_to_all_projects_page
    click_new_project_link
    the_membership_request_check_box_should_be_unchecked_by_default
    create_a_project_with_membership_requstable_unchecked(PROJECT_NAME)
    login_as("existingbob")
    assert_project_not_found(PROJECT_NAME)
  end

  def test_admin_should_be_able_to_update_a_non_requestable_project_to_requestable
    login_as_admin_user
    navigate_to_all_projects_page
    create_a_project_with(:name => PROJECT_NAME, :membership_requestable => false)
    update_project_settings_with(Project.find_by_name(PROJECT_NAME), :membership_requestable => true)
    login_as("existingbob")
    user_can_only_see_this_project_and_can_request_it(PROJECT_NAME)

  end

  def test_admin_should_be_able_to_update_a_requestable_project_to_non_requestable
    login_as_admin_user
    navigate_to_all_projects_page
    create_a_project_with(:name => PROJECT_NAME, :membership_requestable => true)
    update_project_settings_with(Project.find_by_name(PROJECT_NAME),:membership_requestable => false)
    login_as("existingbob")
    assert_project_not_found(PROJECT_NAME)
  end

  def test_admin_can_create_anon_accessible_and_membership_request_able_project
    register_license_that_allows_anonymous_users
    login_as_admin_user
    navigate_to_all_projects_page
    click_new_project_link
    click_show_advanced_options_link
    assert_project_membership_requestable_present
    create_a_project_with_membership_requstable_and_anon_accessible_checked(PROJECT_NAME)
    non_member_user_can_access_this_project_and_request_it(PROJECT_NAME)
    reset_license
  end

  def test_team_member_should_not_see_the_request_link
    update_project_settings_with(@project, :membership_requestable => true)
    login_as 'bob'
    user_should_be_able_to_access_but_not_able_to_request
  end

  def test_light_user_should_be_able_to_request
    update_project_settings_with(@project, :membership_requestable => true)
    login_as_light_user
    user_can_only_see_this_project_and_can_request_it(@project.name)
  end

  def test_admin_user_should_be_able_to_request
    update_project_settings_with(@project, :membership_requestable => true)
    login_as_admin_user
    user_can_access_this_project_and_request_it
  end

  def test_request_link_should_not_present_when_license_is_invalid
    update_project_settings_with(@project, :membership_requestable => true)
    register_expired_license_that_allows_anonymous_users
    login_as 'longbob', 'longtest'
    user_can_only_see_this_project_but_can_not_access_or_request_it
  end

  def test_anon_user_should_not_see_requestable_project_or_request_link
    register_license_that_allows_anonymous_users
    login_as_admin_user
    update_project_settings_with(@project, :anonymous_accessible => true, :membership_requestable => true)
    logout
    user_should_be_able_to_access_but_not_able_to_request
    reset_license
  end

  def test_should_not_include_require_membership_feature_in_templates
    login_as_admin_user
    update_project_settings_with(@project, :membership_requestable => true)
    create_template_for(@project)
    navigate_to_template_management_page
    open_project_template(@project)
    @browser.click_and_wait 'link=Project admin'
    should_not_see_require_membership_option_in_project_template
  end

  def test_should_not_carry_one_the_require_membership_settings_from_template
    login_as_admin_user
    update_project_settings_with(@project, :membership_requestable => true)
    create_template_for(@project)
    update_project_template_identifier(@project,"scenario_153")
    navigate_to_all_projects_page
    click_new_project_link
    create_project_from_current_project_template("new_project",PROJECT_TEMPLATE_NAME)
    navigate_to_project_admin_for("new_project")
    click_show_advanced_options_link
    assert_project_membership_requestable_present
    the_membership_request_check_box_should_be_unchecked_by_default

  end

  def server_eval(to_eval)
    url = URI.parse("http://localhost:#{MINGLE_PORT}")
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.get("/_eval?scriptlet=#{CGI.escape(to_eval)}")
    }
  end
end
