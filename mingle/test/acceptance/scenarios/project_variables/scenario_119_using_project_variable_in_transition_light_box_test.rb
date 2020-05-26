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

# Tags: project-variable-usage
class Scenario119UsingProjectVariableInTransitionLightBoxTest < ActiveSupport::TestCase
  fixtures :users, :login_access
  STORY = 'Story'
  ANY_TEXT_PROPERTY = 'any text'
  ANY_NUMBER_PROPERTY = 'any number'
  MANAGED_TEXT_PROPERTY = 'managed text list'
  MANAGED_NUMBER_PROPERTY = 'managed number list'
  TEAM_MEMBER_PROPERTY = 'user'
  TEAM_MEMBER_PROPERTY_2 = 'user2'
  CARD_TYPE_PROPERTY = 'releated card'
  CARD_TYPE_PROPERTY_2 = 'releated card 2'
  DATE_PROPERTY = 'today'
  DATE_PROPERTY_2 = 'another day'
  
  CARD_NAME_1= 'simple card 1'
  CARD_NAME_2 = 'simple card 2'
  
  TRANSITION_NAME_1 = 'transtion 1'
  TRANSITION_NAME_2 = 'transtion 2'
  
  NOTSET = '(not set)'
  
  USER_INPUT_OPTIONAL = '(user input - optional)'
  USER_INPUT_REQUIRED = '(user input - required)'
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin = users(:proj_admin)
    @team_member = users(:project_member)
    @read_only_user = users(:read_only_user)
    @project = create_project(:prefix => 'scenario_119', :read_only_users => [@read_only_user], :users => [@team_member], :admins => [@project_admin], :anonymous_accessible => true)
    @project.activate
    @type_story = setup_card_type(@project, STORY)
    login_as_proj_admin_user
    @story1 = create_card!(:name => CARD_NAME_1, :card_type  => STORY)
    @story2 = create_card!(:name => CARD_NAME_2, :card_type  => STORY)
  end
  
  #story 5645
  def test_user_can_set_text_property_value_via_transtion_light_box_with_avialable_text_plv
    text_plv_name = 'text plv'
    text_plv_value = 'I am the value of text plv!'
    
    any_text_property = create_allow_any_text_property(ANY_TEXT_PROPERTY)
    managed_text_property = create_managed_text_list_property(MANAGED_TEXT_PROPERTY, ['a', 'b', 'c'])
    create_text_plv(@project, text_plv_name, text_plv_value, [any_text_property, managed_text_property])
    add_properties_for_card_type(@type_story, [any_text_property,managed_text_property])
    
    story_transtion_1 = create_transition_for(@project, TRANSITION_NAME_1, :type => STORY, :set_properties => {ANY_TEXT_PROPERTY => USER_INPUT_REQUIRED, MANAGED_TEXT_PROPERTY => USER_INPUT_OPTIONAL})
    
    open_card(@project, @story1)
    click_transition_link_on_card_with_input_required(story_transtion_1)
    
    set_value_to_property_in_lightbox_editor_on_transition_execute(ANY_TEXT_PROPERTY => "(#{text_plv_name})", MANAGED_TEXT_PROPERTY => "(#{text_plv_name})")
    click_on_complete_transition
    
    assert_properties_set_on_card_show({ ANY_TEXT_PROPERTY => text_plv_value })
    assert_properties_set_on_card_show(MANAGED_TEXT_PROPERTY => text_plv_value)
    
    @browser.run_once_history_generation
    assert_history_for(:card, @story1.number).version(2).shows(:set_properties => {ANY_TEXT_PROPERTY => text_plv_value, MANAGED_TEXT_PROPERTY => text_plv_value})
    
    disassociate_project_variable_from_property(@project, text_plv_name, ANY_TEXT_PROPERTY)
    open_card(@project, @story1)
    click_transition_link_on_card_with_input_required(story_transtion_1)
    assert_free_text_does_not_have_drop_down(ANY_TEXT_PROPERTY, 'transition_lightbox')
    assert_property_does_not_have_values_in_transiton_light_box(ANY_TEXT_PROPERTY, "(#{text_plv_name})")
    click_property_droplist_link_in_transition_lightbox(MANAGED_TEXT_PROPERTY)
    assert_property_have_values_in_transiton_light_box(MANAGED_TEXT_PROPERTY, "(#{text_plv_name})")
    
    delete_project_variable(@project, text_plv_name)
    click_continue_to_delete
    open_card(@project, @story1)
    click_transition_link_on_card_with_input_required(story_transtion_1)
    assert_free_text_does_not_have_drop_down(ANY_TEXT_PROPERTY, 'transition_lightbox')
    assert_property_does_not_have_values_in_transiton_light_box(ANY_TEXT_PROPERTY, "(#{text_plv_name})")
    click_property_droplist_link_in_transition_lightbox(MANAGED_TEXT_PROPERTY)
    assert_property_does_not_have_values_in_transiton_light_box(MANAGED_TEXT_PROPERTY, "(#{text_plv_name})")
  end
  
  #story 5645
  def test_user_can_set_number_property_vlaue_via_transition_light_box_with_available_number_plv
    number_plv_name = 'number plv'
    number_plv_value = '20090119'
    
    any_number_property = create_allow_any_number_property(ANY_NUMBER_PROPERTY)
    managed_number_property = create_managed_number_list_property(MANAGED_NUMBER_PROPERTY, [1,2,3])
    create_number_plv(@project, number_plv_name, number_plv_value, [any_number_property, managed_number_property])
    add_properties_for_card_type(@type_story, [any_number_property, managed_number_property])
    
    story_transtion_1 = create_transition_for(@project, TRANSITION_NAME_1, :type => STORY, :set_properties => {ANY_NUMBER_PROPERTY => USER_INPUT_REQUIRED, MANAGED_NUMBER_PROPERTY => USER_INPUT_OPTIONAL})
    
    open_card(@project, @story1)
    click_transition_link_on_card_with_input_required(story_transtion_1)
    
    set_value_to_property_in_lightbox_editor_on_transition_execute(ANY_NUMBER_PROPERTY => "(#{number_plv_name})", MANAGED_NUMBER_PROPERTY => "(#{number_plv_name})")
    click_on_complete_transition
    
    assert_properties_set_on_card_show({ ANY_NUMBER_PROPERTY => number_plv_value })
    assert_properties_set_on_card_show(MANAGED_NUMBER_PROPERTY => number_plv_value)
    
    @browser.run_once_history_generation
    assert_history_for(:card, @story1.number).version(2).shows(:set_properties => {ANY_NUMBER_PROPERTY => number_plv_value, MANAGED_NUMBER_PROPERTY => number_plv_value})
  end
  
  #story 5645
  def test_user_can_set_user_property_value_via_transtion_light_box_with_availabe_user_plv
    team_plv_name = 'team plv'
    team_plv_id = @team_member
    team_plv_value = "member@ema..."
    team_plv_full_value = "member@email.com"
    
    team_property = create_team_property(TEAM_MEMBER_PROPERTY)
    team_property_2 = create_team_property(TEAM_MEMBER_PROPERTY_2)
    create_user_plv(@project, team_plv_name, team_plv_id, [team_property, team_property_2])
    add_properties_for_card_type(@type_story, [team_property, team_property_2])
    
    story_transtion_1 = create_transition_for(@project, TRANSITION_NAME_1, :type => STORY, :set_properties => {TEAM_MEMBER_PROPERTY => USER_INPUT_REQUIRED, TEAM_MEMBER_PROPERTY_2 => USER_INPUT_OPTIONAL})
    
    open_card(@project, @story1)
    click_transition_link_on_card_with_input_required(story_transtion_1)
    
    set_value_to_property_in_lightbox_editor_on_transition_execute(TEAM_MEMBER_PROPERTY => "(#{team_plv_name})", TEAM_MEMBER_PROPERTY_2 => "(#{team_plv_name})")
    click_on_complete_transition
    
    assert_properties_set_on_card_show(TEAM_MEMBER_PROPERTY => team_plv_value)
    assert_properties_set_on_card_show(TEAM_MEMBER_PROPERTY_2 => team_plv_value)
    
    @browser.run_once_history_generation
    assert_history_for(:card, @story1.number).version(2).shows(:set_properties => {TEAM_MEMBER_PROPERTY => team_plv_full_value, TEAM_MEMBER_PROPERTY_2 => team_plv_full_value})
    
    delete_project_variable(@project, team_plv_name)
    click_continue_to_delete
    open_card(@project, @story1)
    click_transition_link_on_card_with_input_required(story_transtion_1)
    
    click_property_droplist_link_in_transition_lightbox(TEAM_MEMBER_PROPERTY)
    assert_property_does_not_have_values_in_transiton_light_box(TEAM_MEMBER_PROPERTY, "(#{team_plv_name})")
    click_property_droplist_link_in_transition_lightbox(TEAM_MEMBER_PROPERTY_2)
    assert_property_does_not_have_values_in_transiton_light_box(TEAM_MEMBER_PROPERTY_2, "(#{team_plv_name})")
  end
  
  #story 5645
  def test_user_can_set_card_type_property_via_transtion_light_box_with_available_user_type_plv
    card_type_plv_1_name = 'card type plv'
    card_type_plv_1_value = "#1 simple card 1"
    
    card_type_plv_2_name= 'card type plv 2'
    card_type_plv_2_value = "#2 simple card 2"
    
    card_type_property = create_card_type_property(CARD_TYPE_PROPERTY)
    card_type_property_2 = create_card_type_property(CARD_TYPE_PROPERTY_2)
    create_card_plv(@project, card_type_plv_1_name, @type_story, @story1, [card_type_property, card_type_property_2])
    create_card_plv(@project, card_type_plv_2_name, @type_story, @story2, [card_type_property, card_type_property_2])
    add_properties_for_card_type(@type_story, [card_type_property, card_type_property_2])
    
    story_transtion_1 = create_transition_for(@project, TRANSITION_NAME_1, :type => STORY, :set_properties => {CARD_TYPE_PROPERTY => USER_INPUT_OPTIONAL, CARD_TYPE_PROPERTY_2 => USER_INPUT_REQUIRED})
    
    open_card(@project, @story1)
    click_transition_link_on_card_with_input_required(story_transtion_1)
    
    set_value_to_property_in_lightbox_editor_on_transition_execute(CARD_TYPE_PROPERTY => "(#{card_type_plv_1_name})", CARD_TYPE_PROPERTY_2 => "(#{card_type_plv_2_name})")
    click_on_complete_transition
    
    assert_properties_set_on_card_show(CARD_TYPE_PROPERTY => card_type_plv_1_value)
    assert_properties_set_on_card_show(CARD_TYPE_PROPERTY_2 => card_type_plv_2_value)
    
    @browser.run_once_history_generation
    assert_history_for(:card, @story1.number).version(2).shows(:set_properties => {CARD_TYPE_PROPERTY => card_type_plv_1_value, CARD_TYPE_PROPERTY_2 => card_type_plv_2_value})
    
    
    disassociate_project_variable_from_property(@project, card_type_plv_1_name, CARD_TYPE_PROPERTY)
    open_card(@project, @story1)
    click_transition_link_on_card_with_input_required(story_transtion_1)
    
    click_property_droplist_link_in_transition_lightbox(CARD_TYPE_PROPERTY)
    assert_property_does_not_have_values_in_transiton_light_box(CARD_TYPE_PROPERTY, "(#{card_type_plv_1_name})")
    assert_property_have_values_in_transiton_light_box(CARD_TYPE_PROPERTY, "(#{card_type_plv_2_name})")
    click_property_droplist_link_in_transition_lightbox(CARD_TYPE_PROPERTY_2)  
    assert_property_have_values_in_transiton_light_box(CARD_TYPE_PROPERTY_2, "(#{card_type_plv_1_name})")
    assert_property_have_values_in_transiton_light_box(CARD_TYPE_PROPERTY_2, "(#{card_type_plv_2_name})")
    
    delete_project_variable(@project, card_type_plv_1_name)
    click_continue_to_delete
    open_card(@project, @story1)
    click_transition_link_on_card_with_input_required(story_transtion_1)
    click_property_droplist_link_in_transition_lightbox(CARD_TYPE_PROPERTY)
    assert_property_does_not_have_values_in_transiton_light_box(CARD_TYPE_PROPERTY, "(#{card_type_plv_1_name})")
    assert_property_have_values_in_transiton_light_box(CARD_TYPE_PROPERTY, "(#{card_type_plv_2_name})")
    click_property_droplist_link_in_transition_lightbox(CARD_TYPE_PROPERTY_2)  
    assert_property_does_not_have_values_in_transiton_light_box(CARD_TYPE_PROPERTY_2, "(#{card_type_plv_1_name})")
    assert_property_have_values_in_transiton_light_box(CARD_TYPE_PROPERTY_2, "(#{card_type_plv_2_name})")
  end

  def test_user_can_set_date_type_property_via_transition_light_box_with_available_date_type_plv
    date_type_plv_1_name = 'date type plv'
    date_type_plv_1_value = '01 Jan 2009'
    
    date_type_plv_2_name = 'date type plv 2'
    date_type_plv_2_value = '14 Feb 2009'
    
    date_type_property = create_date_property(DATE_PROPERTY)
    date_type_property_2 = create_date_property(DATE_PROPERTY_2)
    create_date_plv(@project, date_type_plv_1_name, date_type_plv_1_value, [date_type_property, date_type_property_2])
    create_date_plv(@project, date_type_plv_2_name, date_type_plv_2_value, [date_type_property, date_type_property_2])
    add_properties_for_card_type(@type_story, [date_type_property, date_type_property_2])
    
    story_transtion_1 = create_transition_for(@project, TRANSITION_NAME_1, :type => STORY, :set_properties => {DATE_PROPERTY => USER_INPUT_OPTIONAL, DATE_PROPERTY_2 => USER_INPUT_REQUIRED})
    
    open_card(@project, @story1)
    click_transition_link_on_card_with_input_required(story_transtion_1)
    
    set_value_to_property_in_lightbox_editor_on_transition_execute(DATE_PROPERTY => "(#{date_type_plv_1_name})", DATE_PROPERTY_2 => "(#{date_type_plv_2_name})")
    click_on_complete_transition
    
    assert_properties_set_on_card_show(DATE_PROPERTY => date_type_plv_1_value)
    assert_properties_set_on_card_show(DATE_PROPERTY_2 => date_type_plv_2_value)
    
    @browser.run_once_history_generation
    assert_history_for(:card, @story1.number).version(2).shows(:set_properties => {DATE_PROPERTY => date_type_plv_1_value, DATE_PROPERTY_2 => date_type_plv_2_value})
    
    delete_project_variable(@project, date_type_plv_1_name)
    click_continue_to_delete
    open_card(@project, @story1)
    click_transition_link_on_card_with_input_required(story_transtion_1)
    click_property_droplist_link_in_transition_lightbox(DATE_PROPERTY)
    assert_property_does_not_have_values_in_transiton_light_box(DATE_PROPERTY, "(#{date_type_plv_1_name})")
    assert_property_have_values_in_transiton_light_box(DATE_PROPERTY, "(#{date_type_plv_2_name})")
    click_property_droplist_link_in_transition_lightbox(DATE_PROPERTY_2)  
    assert_property_does_not_have_values_in_transiton_light_box(DATE_PROPERTY_2, "(#{date_type_plv_1_name})")
    assert_property_have_values_in_transiton_light_box(DATE_PROPERTY_2, "(#{date_type_plv_2_name})")
  end
end
