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

# Tags: scenario, new_user_role, user, readonly
class Scenario101ReadOnlyTeamMemberCrudTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin = users(:proj_admin)
    @team_member = users(:project_member)
    @read_only_user = users(:bob)
    @mingle_admin = users(:admin)
    @project = create_project(:prefix => 'scenario_101_project', :users => [@team_member], :admins => [@mingle_admin, @project_admin])
    login_as_admin_user
  end

  def test_should_be_able_to_add_read_only_team_member_for_a_project
    add_to_team_as_read_only_user_for(@project, @read_only_user)
    assert_notice_message("#{@read_only_user.name} is now a read only team member")
    assert_user_is_read_only_team_member(@read_only_user)
  end

  def test_should_be_able_to_remove_read_only_team_member_for_a_project
    add_to_team_as_read_only_user_for(@project, @read_only_user)
    remove_from_team_for(@project, @read_only_user)
    assert_notice_message("1 member has been removed from the #{@project.name} team successfully.")
    assert_user_is_not_team_member(@read_only_user)
  end

  def test_project_list_page_shows_projects_for_read_only_user_which_he_belongs_to
    add_to_team_as_read_only_user_for(@project, @read_only_user)
    login_as(@read_only_user.login)
    navigate_to_all_projects_page
    assert_project_link_present(@project)
    assert_delete_this_and_create_template_from_this_project_links_not_present
  end

  def test_project_admin_should_not_be_able_to_set_himself_as_read_only_user
    login_as_proj_admin_user
    navigate_to_team_list_for(@project)
    assert_project_admin_check_box_disabled_for(@project_admin)
  end

  def test_removing_read_only_user_from_team_should_give_warning_message_for_a_user_property
    add_to_team_as_read_only_user_for(@project, @read_only_user)
    user_property = setup_user_definition("owner")
    card = create_card!(:name => 'card1', :owner => @read_only_user.id)
    remove_from_team_for(@project, @read_only_user)
    assert_warning_box_message("There is 1 card with #{user_property.name} set to team member #{@read_only_user.login}.")
  end

  def test_removing_read_only_user_from_team_should_give_warning_message_when_transition_using_read_only_user
    add_to_team_as_read_only_user_for(@project, @read_only_user)
    user_property = setup_user_definition("owner")
    transition = create_transition(@project, "set to read only user", :set_properties => {user_property.name => @read_only_user.id})
    remove_from_team_for(@project, @read_only_user)
     assert_warning_box_message("The following transition will be deleted: #{transition.name}.")
  end

  def test_removing_read_only_user_from_team_should_give_warning_message_when_card_default_set_read_only_user_property
    add_to_team_as_read_only_user_for(@project, @read_only_user)
    user_property = setup_user_definition("owner")
    set_property_defaults_and_save_default_for(@project, 'Card',:properties => {user_property.name => @read_only_user.name})
    remove_from_team_for(@project, @read_only_user)
     assert_warning_box_message("There is 1 card defaults with #{user_property.name} set to team member #{@read_only_user.login}.")
  end

  def test_removing_read_only_user_from_team_should_give_warning_message_when_PLV_set_read_only_user_property
    add_to_team_as_read_only_user_for(@project, @read_only_user)
    user_property = setup_user_definition('owner')
    setup_project_variable(@project, :name => 'read_only_user', :data_type => ProjectVariable::USER_DATA_TYPE, :value => @read_only_user)
    remove_from_team_for(@project, @read_only_user)
     assert_warning_box_message("There is 1 project variable with value set to team member #{@read_only_user.login}.")
  end

  def test_read_only_user_can_be_deactivated_by_mingle_admin
    add_to_team_as_read_only_user_for(@project, @read_only_user)
    toggle_activation_for(@read_only_user)
    assert_successful_user_deactivation_message(@read_only_user)
    login_as(@read_only_user.login)
    assert_deactivated_user_error_message(@read_only_user)
  end

  def test_read_only_user_can_update_his_profile_or_change_his_password
    add_to_team_as_read_only_user_for(@project, @read_only_user)
    login_as(@read_only_user.login)
    user = edit_user_profile_details(@read_only_user, :user_login => 'newbob', :user_name => 'new bob new name', :email => 'newbob@email.com')
    assert_notice_message("Profile was successfully updated for #{user.name}.")
    assert_change_password_link_present
  end

  def test_admin_tab_is_not_visible_for_read_only_team_member
    add_to_team_as_read_only_user_for(@project, @read_only_user)
    login_as(@read_only_user.login)
    navigate_to_programs_page
    assert_admin_pill_not_present
  end

end
