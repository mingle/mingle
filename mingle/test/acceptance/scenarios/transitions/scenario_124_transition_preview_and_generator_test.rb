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

# Tags: transition-crud, card
class Scenario124TransitionPreviewAndGeneratorTest < ActiveSupport::TestCase 

  fixtures :users, :login_access 

  STATUS = 'status'
  NEW = 'new'
  OPEN = 'open'
  PRIORITY = 'priority'
  HIGH = 'high'
  URGENT = 'urgent'
  ITERATION = 'iteration'
  NOT_SET = '(not set)'
  STORY = 'Story'
  DEFECT = 'Defect'
  
  MANAGED_NUMBER_PROPERTY = 'managed_number_property'
  MANAGED_TEXT_PROPERTY = 'managed_text_property'
  MANAGED_TEXT_PROPERTY_WITHOUT_VALUE = 'managed_text_property_without_value'
  
  ANY_TEXT_PROPERTY = 'any text property'
  ANY_NUMBER_PROPERTY = 'any numbe property'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin = users(:proj_admin)
    @team_member = users(:project_member)
    @read_only_user = users(:read_only_user)
    @mingle_admin = users(:admin)
    @project = create_project(:prefix => 'scenario_124', :users => [@team_member], :admins => [@mingle_admin, @project_admin], :read_only_users => [@read_only_user], :anonymous_accessible => true) 
    @managed_number_property = create_managed_number_list_property(MANAGED_NUMBER_PROPERTY, [1,2,3])
    @managed_text_property = create_managed_text_list_property(MANAGED_TEXT_PROPERTY, ['a', 'b', 'c'])
    @managed_text_property_without_value = create_managed_number_list_property(MANAGED_TEXT_PROPERTY_WITHOUT_VALUE,[])
    @any_text_property = create_allow_any_text_property(ANY_TEXT_PROPERTY)
    @any_number_property = create_allow_any_text_property(ANY_NUMBER_PROPERTY)
    @story_type = setup_card_type(@project, STORY, :properties => [MANAGED_TEXT_PROPERTY, MANAGED_NUMBER_PROPERTY, ANY_NUMBER_PROPERTY, ANY_TEXT_PROPERTY])
    @defect_type = setup_card_type(@project, DEFECT, :properties => [MANAGED_TEXT_PROPERTY, MANAGED_TEXT_PROPERTY_WITHOUT_VALUE, ANY_TEXT_PROPERTY, ANY_NUMBER_PROPERTY])
    @card_type = @project.card_types.find_by_name('Card')
    # login_as_proj_admin_user
    # @story_1 = create_card!(:name => 'sample card_1', :card_type => STORY, PRIORITY => 'high')
    # @card_2 = create_card!(:name => 'sample dependency', :card_type => DEFECT)
    # @card_3 = create_card!(:name => 'sample card_3', :card_type => STORY)    
    # @card_property = create_property_definition_for(@project, DEPENDENCY, :type => CARD, :types => STORY)
  end
  
  #bug 10967
  def test_that_user_cannot_generate_transitions_unless_both_card_type_and_property_definition_are_selected
    login_as_admin_user
    navigate_to_transition_management_for(@project)
    click_create_new_transtion_workflow_link
    assert_that_transitions_cannot_be_generated
    select_card_type_for_transtion_work_flow(DEFECT)
    assert_that_transitions_cannot_be_generated
    select_property_for_transtion_work_flow(MANAGED_TEXT_PROPERTY)
    assert_that_transitions_can_be_generated
  end
  
  def test_admin_user_can_create_transition_work_flow
    login_as_admin_user
    navigate_to_transition_management_for(@project)
    click_create_new_transtion_workflow_link
    assert_order_in_card_type_drop_list_on_transtion_generator_page(1, @card_type)
    assert_order_in_card_type_drop_list_on_transtion_generator_page(2, @defect_type)
    assert_order_in_card_type_drop_list_on_transtion_generator_page(3, @story_type)
    
    select_card_type_for_transtion_work_flow(DEFECT)
    select_property_for_transtion_work_flow_for_no_transition_scenario(MANAGED_TEXT_PROPERTY_WITHOUT_VALUE)
    assert_no_transition_for_preview_message_present_on_transition_generator_page
    
    assert_name_present_in_property_drop_list_on_transition_generator_page(@managed_text_property)
    assert_name_present_in_property_drop_list_on_transition_generator_page(@managed_text_property_without_value)
    assert_name_not_present_in_property_drop_list_on_transition_generator_page(@managed_number_property)
    assert_name_not_present_in_property_drop_list_on_transition_generator_page(@any_number_property)
    assert_name_not_present_in_property_drop_list_on_transition_generator_page(@any_text_property)
    
    select_card_type_for_transtion_work_flow(STORY)
    
    assert_no_property_selected_on_transition_generator_page
    
    select_property_for_transtion_work_flow(MANAGED_TEXT_PROPERTY)
    assert_name_present_in_property_drop_list_on_transition_generator_page(@managed_text_property)
    assert_name_present_in_property_drop_list_on_transition_generator_page(@managed_number_property)
    assert_name_not_present_in_property_drop_list_on_transition_generator_page(@managed_text_property_without_value)
    assert_name_not_present_in_property_drop_list_on_transition_generator_page(@any_number_property)
    assert_name_not_present_in_property_drop_list_on_transition_generator_page(@any_text_property)
    
    assert_property_position_in_transition_preview_page(0, "(not set)", 'a')
    assert_property_position_in_transition_preview_page(1, 'a', 'b')
    assert_property_position_in_transition_preview_page(2, 'b', 'c')
    
    
    assert_info_box_of_previewing_transition_workflow_present  
    click_link("Generate transition workflow")
    assert_notice_message("Transitions Move Story to a, Move Story to b and Move Story to c and properties Moved to a on, Moved to b on and Moved to c on were successfully created.")
    
    assert_card_type_selected_on_transition_page(@story_type)
    assert_property_selected_on_transition_page(@managed_text_property)
    
    click_create_new_transtion_workflow_link
    select_card_type_for_transtion_work_flow(STORY)
    select_property_for_transtion_work_flow(MANAGED_TEXT_PROPERTY)
    assert_info_box_of_previewing_transition_workflow_present
    assert_warning_box_for_exsisting_transtions_present(3, STORY, MANAGED_TEXT_PROPERTY)
    
    assert_property_position_in_transition_preview_page(0, "(not set)", 'a')
    assert_property_position_in_transition_preview_page(1, 'a', 'b')
    assert_property_position_in_transition_preview_page(2, 'b', 'c')
  end
  
  # bug 9310
  def test_link_should_show_user_duplicate_workflow
    login_as_admin_user
    navigate_to_transition_management_for(@project)
    
    click_create_new_transtion_workflow_link
    select_card_type_for_transtion_work_flow(DEFECT)
    select_property_for_transtion_work_flow(MANAGED_TEXT_PROPERTY)
    click_link("Generate transition workflow")

    click_create_new_transtion_workflow_link
    select_card_type_for_transtion_work_flow(STORY)
    select_property_for_transtion_work_flow(MANAGED_TEXT_PROPERTY)
    click_link("Generate transition workflow")
    
    click_create_new_transtion_workflow_link
    select_card_type_for_transtion_work_flow(STORY)
    select_property_for_transtion_work_flow(MANAGED_TEXT_PROPERTY)
    
    click_link('here')
    assert_not_visible("transition-#{@project.transitions.find_by_name("Move Defect to a").id}")
    assert_not_visible("transition-#{@project.transitions.find_by_name("Move Defect to b").id}")
    assert_not_visible("transition-#{@project.transitions.find_by_name("Move Defect to c").id}")
    
    assert_text_present("Move Story to a")
    assert_text_present("Move Story to b")
    assert_text_present("Move Story to c")    
  end


  
  def test_admin_user_can_create_new_transition_work_flow_via_link_when_there_is_no_transtion_in_list
    login_as_admin_user
    navigate_to_transition_management_for(@project)
    assert_no_transition_message_present_on_transition_page
    click_link("generate a new transition workflow")
    assert_current_url("/projects/#{@project.identifier}/transition_workflows/new")
    assert_no_card_type_selected_on_transition_generator_page
    assert_disabled('property_definition_id')
  end

  def test_only_admin_can_see_the_create_transtion_work_flow_link
    register_license_that_allows_anonymous_users
    login_as_project_member
    navigate_to_transition_management_for(@project)
    assert_create_transition_work_flow_link_is_not_present
    logout
    login_as_read_only_user
    navigate_to_transition_management_for(@project)
    assert_create_transition_work_flow_link_is_not_present
    logout
    navigate_to_transition_management_for(@project)
    assert_create_transition_work_flow_link_is_not_present
  end

end
