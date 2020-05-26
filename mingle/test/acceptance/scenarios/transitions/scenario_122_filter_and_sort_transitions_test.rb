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

# Tags: transition-crud
class Scenario122FilterAndSortTransitionsTest < ActiveSupport::TestCase
  fixtures :users, :login_access  
  
  RELATIONSHIP_TYPE = 'relationship' 
  ALL = "All"
  CARD = "Card"
  SUPER_CARD = "Super Card"
  STATUS = "status"
  OPEN = "open"
  CLOSED = "closed"  
  START_DATE = 'start date'
  MANAGED_TEXT_PROPERTY = 'managed text property'
  MANAGED_NUMBER_PROPERTY = 'managed number property'
  STORY = 'story'
  DEFECT = 'defect'
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)   
    
    start_of_login = Time.now
    @browser = selenium_session
    login_as_proj_admin_user

    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_122', :admins => [@project_admin_user])
    @type_super_card = setup_card_type(@project, "Super Card")     
  end
  
  def test_transition_filters_should_be_lost_if_user_leaves_transition_page
    status = create_managed_text_list_property(STATUS, [OPEN,CLOSED])

    navigate_to_transition_management_for(@project)
    select_card_type_in_transition_filter(CARD)
    select_property_in_transition_filter(STATUS)
    click_overview_tab    
    navigate_to_transition_management_for(@project)
    assert_no_card_type_seleced_on_transition_page
    assert_no_property_seleced_on_transition_page
  end
  
  def test_should_persist_transition_filters_after_created_transition
    status = create_managed_text_list_property(STATUS, ['a', 'b', 'c'])
    size = create_allow_any_number_property("Size")
    card_type = @project.card_types.find_by_name(CARD)
    add_properties_for_card_type(@type_super_card,[size])

    navigate_to_transition_management_for(@project)
    select_card_type_in_transition_filter(CARD)
    select_property_in_transition_filter(STATUS)
    click_create_new_transition_link
    fill_in_transition_values(@project, 'Move card status to a', :type => CARD, :set_properties => {STATUS => 'a'})
    click_create_transition
    
    assert_card_type_selected_on_transition_page(card_type)
    assert_property_selected_on_transition_page(status)
    assert_notice_message("Transition Move card status to a was successfully created.")
    assert_transition_present_in_filter_result(@project.transitions.find_by_name("Move card status to a"))

    select_card_type_in_transition_filter("Super Card")
    select_property_in_transition_filter("Size")
    click_create_a_new_transition_link_on_no_transition_warning_message
    fill_in_transition_values(@project, 'Move card status to b', :type => CARD, :set_properties => {STATUS => 'b'})
    click_create_transition

    assert_card_type_selected_on_transition_page(@type_super_card)
    assert_property_selected_on_transition_page(size)
    assert_notice_message("Transition Move card status to b was successfully created, but is not shown because it does not match the current filter.")
    assert_transition_not_present_in_filter_result(@project.transitions.find_by_name("Move card status to b"))
  end
  
  def test_should_persist_transition_filters_after_edit_transition
    start_date = create_date_property(START_DATE)
    add_properties_for_card_type(@type_super_card,[start_date])
    card_type = @project.card_types.find_by_name(CARD)
    get_one_simple_relationship_property("tree property")
    tree = @project.tree_configurations.find_by_name("Simple Tree")    
    transition = create_transition_for(@project, 'transition with tree', :type => CARD, :set_properties => {"tree property" => "(not set)"})

    navigate_to_transition_management_for(@project)
    select_card_type_in_transition_filter(CARD)
    select_property_in_transition_filter("tree property")
    
    click_edit_transition(transition)
    fill_in_transition_values(@project,transition.name,:type => CARD, :set_properties => {"tree property" => "(user input - optional)"})
    click_save_transition
    
    assert_card_type_selected_on_transition_page(card_type)
    assert_property_selected_on_transition_page(@project.all_property_definitions.find_by_name("tree property"))
    assert_notice_message("Transition transition with tree was successfully updated.")
    assert_transition_present_in_filter_result(transition)

    click_edit_transition(transition)
    fill_in_transition_values(@project,transition.name,:type => "Super Card", :set_properties => {start_date => "(today)"})
    click_save_transition

    assert_card_type_selected_on_transition_page(card_type)
    assert_property_selected_on_transition_page(@project.all_property_definitions.find_by_name("tree property"))
    assert_notice_message("Transition transition with tree was successfully updated, but is not shown because it does not match the current filter.")
    assert_transition_not_present_in_filter_result(transition)
  end  
    
  def test_should_persist_transition_filters_after_delete_transition
    release = create_card_type_property("release")
    owner = create_team_property("Owner")
    card_type = @project.card_types.find_by_name(CARD)
    add_properties_for_card_type(@type_super_card,[owner])
        
    transition = create_transition(@project, 'transition', :card_type => @type_super_card, :required_properties => {"release" => "(set)"}, :set_properties => {"Owner" => "(current user)"})
  
    navigate_to_transition_management_for(@project)
    select_card_type_in_transition_filter("Super Card")
    select_property_in_transition_filter("Owner")

    click_delete(transition)
    @browser.verify_confirmation("Are you sure?") 
  
    assert_card_type_selected_on_transition_page(@type_super_card)
    assert_property_selected_on_transition_page(owner)
    assert_notice_message("Transition transition was successfully deleted")
  end
  
  def test_transition_filters_should_be_set_as_on_creating_transition_workflow_page
    status = create_managed_text_list_property(STATUS, ['a', 'b', 'c'])
    size = create_managed_text_list_property("Size", [1, 2, 4])
    card_type = @project.card_types.find_by_name(CARD)    
    add_properties_for_card_type(@type_super_card,[size,status])

    navigate_to_transition_management_for(@project)
    select_card_type_in_transition_filter(CARD)
    select_property_in_transition_filter(STATUS)
    click_create_new_transtion_workflow_link
    select_card_type_for_transtion_work_flow("Super Card")
    select_property_for_transtion_work_flow("Size")
    click_cancel_using_js
    # click_link("Cancel")
    assert_card_type_selected_on_transition_page(@type_super_card)
    assert_property_selected_on_transition_page(size)    

    click_create_new_transtion_workflow_link
    select_card_type_for_transtion_work_flow(CARD)
    select_property_for_transtion_work_flow(STATUS)
    click_link("Generate transition workflow")

    assert_card_type_selected_on_transition_page(card_type)
    assert_property_selected_on_transition_page(status)    
  end  
  
  def test_should_persist_transition_filters_after_cancel_editing_transition
    status = create_managed_text_list_property(STATUS, ['a', 'b', 'c'])
    size = create_allow_any_number_property("Size")
    card_type = @project.card_types.find_by_name(CARD)
    add_properties_for_card_type(@type_super_card,[size])

    navigate_to_transition_management_for(@project)
    select_card_type_in_transition_filter(CARD)
    select_property_in_transition_filter(STATUS)
    click_create_new_transition_link
    click_cancel_transition
    assert_card_type_selected_on_transition_page(card_type)
    assert_property_selected_on_transition_page(status)

    select_card_type_in_transition_filter("Super Card")
    select_property_in_transition_filter("Size")

    click_create_a_new_transition_link_on_no_transition_warning_message
    click_cancel_transition
    
    assert_card_type_selected_on_transition_page(@type_super_card)
    assert_property_selected_on_transition_page(size)    
  end
    
  def test_card_types_and_properties_should_be_present_on_the_transition_dropdown_list  
    create_property_of_particular_type "Managed text list", "status"
    create_property_of_particular_type "Allow any text", "iteration"
    create_property_of_particular_type "Managed number list", "size"
    create_property_of_particular_type "Allow any number", "reversion"
    create_property_of_particular_type "date", "reported on"
    create_property_of_particular_type "team", "owner"
    create_property_of_particular_type "card", "dependency"
    create_property_of_particular_type "relationship", "Tree - Card"    
        
    navigate_to_transition_management_for(@project)
    assert_transition_filter_present
    assert_card_types_present_in_transition_filter_drop_list(CARD,SUPER_CARD)   
    select_card_type_in_transition_filter(CARD)
    assert_properties_present_in_transition_filter_drop_list("All properties","status", "iteration", "size", "reversion", "reported on", "owner", "dependency", "Tree - Card")     
  end
  
  def test_property_used_in_transitons_should_be_able_be_filtered
    create_property_of_particular_type "Managed text list", "status"
    create_property_of_particular_type "Allow any text", "iteration"
    card_type = @project.card_types.find_by_name(CARD)
    using_property_in_required_field = create_transition(@project, 'property used in required field', :card_type => card_type, :required_properties => {"status" => "(not set)"}, :set_properties => {"iteration" => "123"})
    using_property_in_set_field = create_transition(@project, 'property used in set field', :card_type => card_type, :required_properties => {"iteration" => "(not set)"}, :set_properties => {"status" => "(not set)"})
    using_property_in_both_required_and_set_field = create_transition(@project, 'property used in both required and set fields', :card_type => card_type, :required_properties => {"status" => "(not set)"}, :set_properties => {"status" => "(not set)"})
    not_using_property = create_transition(@project, 'property not been used', :card_type => card_type, :required_properties => {"iteration" => "(not set)"}, :set_properties => {"iteration" => "(not set)"})
    
    navigate_to_transition_management_for(@project)
    select_card_type_in_transition_filter(CARD)
    select_property_in_transition_filter(STATUS)  
    assert_transitions_present_in_filter_result(using_property_in_both_required_and_set_field, using_property_in_required_field, using_property_in_set_field)
    assert_transition_not_present_in_filter_result(not_using_property)
  end
  
  #bug 7237 
  def test_filter_transition_with_hidden_property
    create_property_of_particular_type "Managed text list", "status"
    create_property_of_particular_type "Allow any text", "iteration"
    card_type = @project.card_types.find_by_name(CARD)
    using_property_in_required_field = create_transition(@project, 'property used in required field', :card_type => card_type, :required_properties => {"status" => "(not set)"}, :set_properties => {"iteration" => "123"})
    using_property_in_set_field = create_transition(@project, 'property used in set field', :card_type => card_type, :required_properties => {"iteration" => "(not set)"}, :set_properties => {"status" => "(not set)"})
    using_property_in_both_required_and_set_field = create_transition(@project, 'property used in both required and set fields', :card_type => card_type, :required_properties => {"status" => "(not set)"}, :set_properties => {"status" => "(not set)"})
    not_using_property = create_transition(@project, 'property not been used', :card_type => card_type, :required_properties => {"iteration" => "(not set)"}, :set_properties => {"iteration" => "(not set)"})
    
    hide_property(@project, STATUS)
    navigate_to_transition_management_for(@project)
    select_card_type_in_transition_filter(CARD)
    select_property_in_transition_filter(STATUS)  
    assert_transitions_present_in_filter_result(using_property_in_both_required_and_set_field, using_property_in_required_field, using_property_in_set_field)
    assert_transition_not_present_in_filter_result(not_using_property)
  end
  
  
  def test_the_order_of_transition_in_transition_filter_result
    status_property = setup_property_definitions(STATUS => [OPEN, CLOSED])
    create_property_of_particular_type "Allow any text", "iteration"
    setup_project_variable(@project, :name => "plv ", :data_type => "StringType", :properties => [STATUS])
       
    card_type = @project.card_types.find_by_name(CARD)
    
    not_set_2_open = create_transition(@project, 'x', :card_type => card_type, :required_properties => {STATUS => nil}, :set_properties => {STATUS => OPEN})
    not_set_2_no_change = create_transition(@project, 'j', :card_type => card_type, :required_properties => {STATUS => nil}, :set_properties => {"iteration" => nil})
    open_2_not_set = create_transition(@project, 'm', :card_type => card_type, :required_properties => {STATUS => OPEN}, :set_properties => {STATUS => nil})
    open_2_closed = create_transition(@project, 'a', :card_type => card_type, :required_properties => {STATUS => OPEN}, :set_properties => {STATUS => CLOSED})
    open_2_no_changed = create_transition(@project, 'i', :card_type => card_type, :required_properties => {STATUS => OPEN}, :set_properties => {"iteration" => nil})
    open_2_plv = create_transition(@project, 's', :card_type => card_type, :required_properties => {STATUS => OPEN}, :set_properties => {STATUS => "(plv)"})
    open_2_user_input = create_transition(@project, 'k', :card_type => card_type, :required_properties => {STATUS  => OPEN}, :set_properties => {STATUS => '(user input - required)'})
    closed_2_not_set = create_transition(@project, 'y', :card_type => card_type, :required_properties => {STATUS => CLOSED}, :set_properties => {STATUS => NOT_SET})   
    any_2_not_set = create_transition(@project, 'z', :card_type => card_type, :set_properties => {STATUS => nil})    
    any_2_open = create_transition(@project, 'B', :card_type => card_type, :set_properties => {STATUS => OPEN})    
    any_2_closed = create_transition(@project, 'c', :card_type => card_type, :set_properties => {STATUS => CLOSED})
    plv_2_not_set = create_transition(@project, 'l', :card_type => card_type, :required_properties => {STATUS => "(plv)"}, :set_properties => {STATUS => nil})   
    plv_2_open = create_transition(@project, 'h', :card_type => card_type, :required_properties => {STATUS => "(plv)"}, :set_properties => {STATUS => OPEN})
    set_2_open = create_transition(@project, 'Q', :card_type => card_type, :required_properties => {STATUS => '(set)'}, :set_properties => {STATUS => OPEN})    
    set_2_no_change = create_transition(@project, 'e', :card_type => card_type, :required_properties => {STATUS => '(set)'}, :set_properties => {"iteration" => nil})  
    does_not_match_filter = create_transition(@project, 'd', :card_type => card_type, :required_properties => {"iteration" => nil}, :set_properties => {"iteration" => "whatever"})
    
    navigate_to_transition_management_for(@project)
    assert_order_of_transitions(open_2_closed, any_2_open, any_2_closed, does_not_match_filter, set_2_no_change, plv_2_open, open_2_no_changed, not_set_2_no_change, open_2_user_input, plv_2_not_set, open_2_not_set, set_2_open, open_2_plv, not_set_2_open, closed_2_not_set, any_2_not_set)
    select_card_type_in_transition_filter(CARD)
    select_property_in_transition_filter(STATUS)
    assert_order_of_transitions(not_set_2_open, not_set_2_no_change, open_2_not_set, open_2_closed, open_2_plv, open_2_user_input, open_2_no_changed, closed_2_not_set, plv_2_not_set, plv_2_open,set_2_open,set_2_no_change, any_2_not_set, any_2_open, any_2_closed)
  end
  
  #bug 6134
  def test_transition_filter_property_dropdown_list_should_be_disabled_on_page_load
    managed_text_property = create_managed_text_list_property('status', ['fixed', 'open', 'ready'])
    navigate_to_transition_management_for(@project)
    assert_disabled('property-definitions-of-card-type-filter')
    @browser.assert_text_present_in('property-definitions-of-card-type-filter', 'All properties')
  end
  
  def test_change_the_Filter_by_card_type_to_another_card_type_should_reset_the_value_of_show_workflow_for_to_All_properties
    managed_text_property = create_managed_text_list_property(MANAGED_TEXT_PROPERTY, ['a', 'b', 'c'])
    managed_number_property = create_managed_number_list_property(MANAGED_NUMBER_PROPERTY, [1,2,3])
    story_type = setup_card_type(@project, STORY, :properties => [MANAGED_TEXT_PROPERTY, MANAGED_NUMBER_PROPERTY])
    defect_type = setup_card_type(@project, DEFECT, :properties => [MANAGED_TEXT_PROPERTY, MANAGED_TEXT_PROPERTY])
    navigate_to_transition_management_for(@project)
    select_card_type_in_transition_filter(STORY)
    select_property_in_transition_filter(MANAGED_TEXT_PROPERTY)
    select_card_type_in_transition_filter(DEFECT)
    assert_no_property_seleced_on_transition_page
  end
  
  private 
  def create_property_of_particular_type(property_type, property_name)
    if property_type == RELATIONSHIP_TYPE
      get_one_simple_relationship_property(property_name)
    else
      create_property_for_card(property_type, property_name)
    end   
  end
  
  def get_one_simple_relationship_property(relationship_property_name)
    type_card = @project.card_types.find_by_name(CARD)    
    tree = setup_tree(@project, 'Simple Tree', :types => [@type_super_card, type_card], :relationship_names => ["#{relationship_property_name}"])
  end
    
end
