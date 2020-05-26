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

# Tags: transitions
class Scenario179AssignTransitionToGroupTest < ActiveSupport::TestCase

  fixtures :users, :login_access
  ADMIN = "admin users"
  QA="QAs in Mingle"
  BA="BAs in Mingle"
  DEV="Developers in Mingle"

  STATUS = "Status"
  PRIORITY = "Priority"

  NEW = "New"
  OPEN = "Open"
  CLOSED = "Closed"

  HIGH = "High"
  LOW = "Low"

  TRANSITION_NAME_1 = "transitions 1"
  TRANSITION_NAME_2 = "transitions 2"

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @mingle_admin = users(:admin)
    @project_admin = users(:proj_admin)
    @qa_1 = users(:project_member)
    @qa_2 = users(:user_with_html)
    @ba_1 = users(:user_with_quotes)
    @ba_2 = users(:existingbob)
    @dev_1 = users(:longbob)
    @dev_2 = users(:capitalized)
    @bob = users(:bob)
    @read_only_user = users(:read_only_user)
    @project = create_project(:prefix => 'scenario_179',  :admins => [@mingle_admin, @project_admin], :users => [@qa_1, @qa_2, @ba_1, @ba_2, @dev_1, @dev_2, @bob], :read_only_users => [@read_only_user], :anonymous_accessible => true)
  end


  def test_when_create_transtion_user_can_tie_it_to_groups
     login_as_admin_user
     setup_property_definitions(STATUS => [NEW, OPEN, CLOSED], PRIORITY => [HIGH, LOW])
     ba_group = create_a_group_for_project(@project, BA)
     qa_group = create_a_group_for_project(@project, QA)
     tansition_for_QAs = create_transition_for(@project, 'transtion for QAs', :set_properties => {STATUS => CLOSED}, :for_groups => [qa_group, ba_group])
     @browser.assert_text_present("This transition can be used by members of the following user groups: #{BA} and #{QA}")
  end

  def test_when_edit_transition_user_can_tie_it_to_groups
     login_as_admin_user
     setup_property_definitions(STATUS => [NEW, OPEN, CLOSED], PRIORITY => [HIGH, LOW])
     transition = create_transition(@project, TRANSITION_NAME_1, :set_properties => {:status => CLOSED})
     qa_group = create_a_group_for_project(@project, QA)
     login_as_proj_admin_user
     edit_transition_for(@project, transition, :for_groups => [qa_group])
     @browser.assert_text_present("This transition can be used by members of the following user group: #{QA}.")
  end

  def test_show_a_message_on_transtion_creation_page_when_no_group_in_current_project
     login_as_proj_admin_user
     navigate_to_transition_management_for(@project)
     click_create_new_transition_link
     select_only_selected_team_members_from_selected_group_radio_button
     @browser.assert_text_present_in("group-list", "There are no groups in the project.")
  end

  def test_show_error_message_when_save_transtion_without_selecting_any_group
     login_as_proj_admin_user
     setup_property_definitions(STATUS => [NEW, OPEN, CLOSED])
     ba_group = create_a_group_for_project(@project, BA)
     navigate_to_transition_management_for(@project)
     click_create_new_transition_link
     type_transition_name(TRANSITION_NAME_1)
     set_sets_properties(@project, STATUS => CLOSED)
     select_only_selected_team_members_from_selected_group_radio_button
     click_create_transition
     assert_error_message("Please select at least one group")
  end


  def test_users_in_groups_will_get_the_corresponding_permission_to_view_and_excute_the_tansition
     login_as_admin_user
     create_transitions_and_tie_them_with_user_groups
     card = create_card!(:name => 'card with transtion')

     login_as_super_user
     open_card(@project, card.number)
     assert_transition_present_on_card(@transition_for_BAs)
     assert_transition_present_on_card(@transition_for_QAs)
     assert_transition_present_on_card(@transition_for_Devs)

     login_as_qa
     open_card(@project, card.number)
     assert_transition_present_on_card(@transition_for_QAs)
     assert_transition_not_present_on_card(@transition_for_BAs)
     assert_transition_not_present_on_card(@transition_for_Devs)

     login_as_ba
     open_card(@project, card.number)
     assert_transition_present_on_card(@transition_for_BAs)
     assert_transition_not_present_on_card(@transition_for_Devs)
     assert_transition_not_present_on_card(@transition_for_QAs)

     login_as_dev
     open_card(@project, card.number)
     assert_transition_present_on_card(@transition_for_Devs)
     assert_transition_not_present_on_card(@transition_for_QAs)
     assert_transition_not_present_on_card(@transition_for_BAs)

     login_as_none_group_user
     open_card(@project, card.number)
     assert_transition_not_present_on_card(@transition_for_Devs)
     assert_transition_not_present_on_card(@transition_for_QAs)
     assert_transition_not_present_on_card(@transition_for_BAs)
  end

  def test_transition_will_be_available_to_every_team_members_if_the_associated_groups_got_deleted
     login_as_admin_user
     create_transitions_and_tie_them_with_user_groups
     card = create_card!(:name => 'card with transtion')
     navigate_to_group_list_page(@project)
     delete_group_with_confirmation(@project, BA)
     delete_group_with_confirmation(@project, QA)
     delete_group_with_confirmation(@project, DEV)

     login_as_super_user
     open_card(@project, card.number)
     assert_transition_present_on_card(@transition_for_QAs)
     assert_transition_present_on_card(@transition_for_BAs)
     assert_transition_present_on_card(@transition_for_Devs)

     login_as_qa
     open_card(@project, card.number)
     assert_transition_present_on_card(@transition_for_BAs)
     assert_transition_present_on_card(@transition_for_Devs)
     assert_transition_present_on_card(@transition_for_QAs)

     login_as_ba
     open_card(@project, card.number)
     assert_transition_present_on_card(@transition_for_Devs)
     assert_transition_present_on_card(@transition_for_QAs)
     assert_transition_present_on_card(@transition_for_BAs)

     login_as_dev
     open_card(@project, card.number)
     assert_transition_present_on_card(@transition_for_Devs)
     assert_transition_present_on_card(@transition_for_QAs)
     assert_transition_present_on_card(@transition_for_BAs)

     login_as_none_group_user
     open_card(@project, card.number)
     assert_transition_present_on_card(@transition_for_Devs)
     assert_transition_present_on_card(@transition_for_QAs)
     assert_transition_present_on_card(@transition_for_BAs)
  end



 private
   def create_transitions_and_tie_them_with_user_groups
     setup_property_definitions(STATUS => [NEW, OPEN, CLOSED], PRIORITY => [HIGH, LOW])
     admin_group = create_a_group_for_project(@project, ADMIN)
     ba_group = create_a_group_for_project(@project, BA)
     qa_group = create_a_group_for_project(@project, QA)
     dev_group = create_a_group_for_project(@project, DEV)
     add_user_to_group(@project, [@mingle_admin, @project_admin], [admin_group, qa_group, ba_group, dev_group])
     add_user_to_group(@project, [@qa_1, @qa_2], [qa_group])
     add_user_to_group(@project, [@ba_1, @ba_2], [ba_group])
     add_user_to_group(@project, [@dev_1, @dev_2], [dev_group])
     @transition_for_QAs = create_transition_for(@project, 'transition for QAs', :set_properties => {STATUS => CLOSED}, :for_groups => [qa_group])
     @transition_for_BAs = create_transition_for(@project, 'transition for BAs', :set_properties => {STATUS => NEW}, :for_groups => [ba_group])
     @transition_for_Devs = create_transition_for(@project, 'transition for Devs', :set_properties => {STATUS => OPEN}, :for_groups => [dev_group])
   end

   def login_as_qa
    login_as("member")
   end

   def login_as_another_qa
    login_as("user_with_html")
   end

   def login_as_ba
    login_as("user_with_quotes")
   end

   def login_as_another_ba
    login_as("existingbob")
   end

   def login_as_dev
    login_as("longbob", "longtest")
   end

   def login_as_another_dev
    login_as("capitalized")
   end

   def login_as_none_group_user
    login_as("bob")
   end

   def login_as_super_user
    login_as_admin_user
   end

   def login_as_another_super_user
    login_as_proj_admin_user
   end

end
