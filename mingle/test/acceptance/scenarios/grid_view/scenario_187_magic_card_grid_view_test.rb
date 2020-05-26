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
  
# Tags: scenario, gridview
class Scenario187MagicCardGridViewTest < ActiveSupport::TestCase  
  fixtures :users

  CARD = "Card"
  TYPE = "Type"
  STATUS = 'Status'  
  NEW = 'new'  
  OPEN = 'open'  
  CLOSED = 'closed'  
  SIZE = 'size'  
  
  STORY = 'story'  
  
  PRIORITY = 'priority'  
  URGENT = 'URGENT'  
  HIGH = 'High'  
  LOW = 'Low'  
    
  OWNER = 'owner'  
  START_DATE = 'start date'  
  DEPENDENCY = 'dependency'  
  
  RELEASE = "Release"
  ITERATION = "Iteration"
  
  def setup  
    destroy_all_records(:destroy_users => false, :destroy_projects => true)      
    @browser = selenium_session  
    @mingle_admin = users(:admin)  
    @project_admin_user = users(:proj_admin)  
    @team_member = users(:project_member)  
    @project = create_project(:prefix => 'scenario_187', :users => [@team_member, @mingle_admin], :admins => [@project_admin_user])  
    setup_property_definitions(STATUS => [NEW, OPEN, CLOSED], PRIORITY => [URGENT, HIGH, LOW], SIZE => [1, 2, 3])  
    setup_user_definition(OWNER)  
    setup_date_property_definition(START_DATE)  
    @dependency = setup_card_type_property_definition(DEPENDENCY)
    @story_type = setup_card_type(@project, STORY, :properties => [STATUS, PRIORITY, SIZE, OWNER, START_DATE, DEPENDENCY])
    @card_type = @project.card_types.find_by_name(CARD)
    
    login_as_proj_admin_user
    @sample_card = create_card!(:name => "Bucky Beavor is gone!")
    create_card_plv(@project, "current iteration", @card_type, @sample_card, [@dependency])
  end  
    
  # Story 12598

  def test_quick_add_cards_when_set_range_for_managed_text_prop_in_filters
    check_setting_ambiguous_value_when(STATUS, {"is greater than" => NEW, "is less than" => CLOSED }, OPEN)
  end  
  
  def test_quick_add_cards_when_managed_text_prop_set_in_card_defaults_and_ambigous_filter
    set_card_default("Card", STATUS => OPEN)
    check_setting_ambiguous_value_when(STATUS, {"is greater than" => NEW }, OPEN)  
    
    create_card!(:name => "created_so_the_grid_view_is_displayed", :status => OPEN)
    set_card_default("Card", STATUS => CLOSED)
    check_setting_ambiguous_value_when(STATUS, {"is less than" => CLOSED }, NEW)
  end  

  def test_quick_add_cards_and_set_ambiguous_values_for_text_properties  
    check_setting_ambiguous_value_when(STATUS, {"is greater than" => NEW }, OPEN)
  end  

  def test_quick_add_cards_and_set_ambiguous_values_for_numeric_properties  
    check_setting_ambiguous_value_when(SIZE, {"is greater than" =>  "1"}, "2")  
  end  
  
  def test_quick_add_cards_and_set_ambiguous_values_for_user_properties
    check_setting_ambiguous_user_value_when(OWNER, "is not", "#{@team_member.login}", [@mingle_admin.name, @project_admin_user.name, '(not set)', '(current user)'])  
  end  
    
  def test_quick_add_cards_and_set_ambiguous_values_for_date_properties  
    check_setting_ambiguous_date_value_when(START_DATE, {"is not" => "today"})  
  end
  
  def test_quick_add_cards_and_set_range_for_date_property_in_filters
    create_card!(:name => "created_so_the_grid_view_is_displayed", START_DATE => "(today)")
    check_setting_ambiguous_date_value_when(START_DATE, {"is before" => "Oct 5 2050", "is after" => "Oct 5 1950"})
  end
  
  def test_quick_add_cards_and_set_ambiguous_values_for_card_type_properties
    check_setting_ambiguous_card_value_when(DEPENDENCY, {"is not" => @sample_card.number})
  end
  
  def test_quick_add_cards_and_set_ambigous_values_for_card_type_properties_using_plv
    check_setting_ambiguous_card_value_when(DEPENDENCY, {"is not" => "(current iteration)"})
  end
  
  def test_quick_add_cards_set_ambigous_values_for_type
    check_setting_ambiguous_card_type_when("is", [STORY, CARD], STORY)
  end
  
  def test_quick_add_cards_and_set_xambigous_values_for_tree_properties
    create_tree
    check_setting_ambiguous_tree_relationship_value_when([TYPE, "is", STORY], [RELEASE, "is not", @release_1.number], [ITERATION, "is not", @iteration_1.number])
  end

  # bug 13307
  def test_quick_add_cards_for_a_card_with_parentless_default
    tree = create_tree
    parentless_default_card = create_card!(:name => "Orphan Iteration", :card_type => ITERATION)
    add_cards_to_tree(tree, parentless_default_card)
    open_edit_defaults_page_for(@project, STORY)
    set_relationship_properties("defaults", ITERATION => parentless_default_card)
    click_save_defaults

    open_add_card_via_quick_add
    set_quick_add_card_type_to(STORY)
    iteration_tree_prop = @project.find_property_definition(ITERATION)
    open_card_selector_for_property_on_quick_add_lightbox(iteration_tree_prop)
    @browser.click card_selector_result_locator(:filter, @iteration_2.number)
    number = submit_card_name_and_type('My new card')
    newly_created_card = @project.cards.find_by_number(number)
    assert_equal @iteration_2, iteration_tree_prop.value(newly_created_card)
  end

  def test_quick_add_card_overlay_retain_type_selection_done
    logout
    login_as_proj_admin_user
    create_card!(:name => "card 1")
    navigate_to_grid_view_for(@project)
    drag_and_drop_quick_add_card_to_ungrouped_grid_view
    assert_card_type_set_on_quick_add_card(CARD)
    set_quick_add_card_type_to(STORY)
    name_card_and_save_for_quick_add("New Story")
    drag_and_drop_quick_add_card_to_ungrouped_grid_view
    assert_card_type_set_on_quick_add_card(STORY)
  end
  
  private  
  
  def name_card_and_save_for_quick_add(card_name)
    type_card_name(card_name)  
    submit_quick_add_card
    new_card = @project.reload.cards.find_by_name(card_name, :order => 'number desc')  
  end
  
  def check_setting_ambiguous_value_when(target_property, operator_and_values, expected_value)
    create_card!(:name => "created_so_the_grid_view_is_displayed", target_property => expected_value)
    
    navigate_to_grid_view_for(@project)
    
    set_filter_by_url(@project, get_filter_parameters(target_property, operator_and_values), "grid")  
    drag_and_drop_quick_add_card_to_ungrouped_grid_view
      
    assert_properties_set_on_quick_add_card(target_property => expected_value)  
      
    new_card = name_card_and_save_for_quick_add("Newly Created Card")
      
    assert_cards_present_in_grid_view(new_card)  
  end  
    
  def check_setting_ambiguous_user_value_when(target_property, operator, compare_to_value, acceptable_values)
    create_card!(:name => "created_so_the_grid_view_is_displayed", target_property => acceptable_values.first, :card_type => STORY)
    
    navigate_to_grid_view_for(@project)  
    set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]&filters[]=[#{target_property}][#{operator}][#{compare_to_value}]", "grid")  
    drag_and_drop_quick_add_card_to_ungrouped_grid_view  
      
    card_name = "Newly Created Card"  
    type_card_name(card_name)  
    submit_quick_add_card  
      
    new_card = @project.reload.cards.find_by_name(card_name, :order => 'number desc')  
    assert acceptable_values.include?(new_card.property_value(target_property).display_value)  
    assert_cards_present_in_grid_view(new_card)  
  end  
    
  def check_setting_ambiguous_date_value_when(target_property, operator_and_values)
    navigate_to_grid_view_for(@project)
    set_filter_by_url(@project, get_filter_parameters(target_property, operator_and_values), "grid")  
    drag_and_drop_quick_add_card_to_ungrouped_grid_view
    
    card_name = "Newly Created Card"  
    type_card_name(card_name)  
    submit_quick_add_card  
      
    new_card = @project.reload.cards.find_by_name(card_name, :order => 'number desc')  
    assert_cards_present_in_grid_view(new_card)      
  end  
  
  def check_setting_ambiguous_card_value_when(target_property, operator_and_values)
    navigate_to_grid_view_for(@project)
    set_filter_by_url(@project, get_filter_parameters(target_property, operator_and_values), "grid")  
    drag_and_drop_quick_add_card_to_ungrouped_grid_view  
    
    card_name = "Newly Created Card"  
    type_card_name(card_name)
    submit_quick_add_card
    
    new_card = @project.reload.cards.find_by_name(card_name, :order => 'number desc')  
    assert_cards_present_in_grid_view(new_card)       
  end
  
  def check_setting_ambiguous_card_type_when(operator, values, expected_value)
    navigate_to_grid_view_for(@project)
    filters_url = values.map{|value| "filters[]=[#{TYPE}][is][#{value}]"}.join("&")
    set_filter_by_url(@project, filters_url, "grid")  
    
    drag_and_drop_quick_add_card_to_ungrouped_grid_view
    assert_card_type_set_on_quick_add_card(expected_value)
    
    card_name = "Newly Created Card"  
    type_card_name(card_name)  
    submit_quick_add_card  
      
    new_card = @project.reload.cards.find_by_name(card_name, :order => 'number desc')
    open_card(@project, new_card.number)
    assert_card_type_set_on_card_show(expected_value)
  end
  
  def create_tree
    release_type = setup_card_type(@project, RELEASE, :properties => [])
    iteration_type = setup_card_type(@project, ITERATION, :properties => [])
    planning_tree = setup_tree(@project, "Planning Tree", :types => [release_type, iteration_type, @story_type], :relationship_names => [RELEASE, ITERATION])
    
    @release_1 = create_card!(:name => "Release 1", :card_type => RELEASE)
    @release_2 = create_card!(:name => "Release 2", :card_type => RELEASE)
    
    @iteration_1 = create_card!(:name => "Iteration 1", :card_type => ITERATION)
    @iteration_2 = create_card!(:name => "Iteration 2", :card_type => ITERATION)
    
    story_1 = create_card!(:name => "Story 1", :card_type => STORY)
    story_2 = create_card!(:name => "Story 2", :card_type => STORY)
    
    add_cards_to_tree(planning_tree, @release_1, @iteration_1, story_1)
    add_cards_to_tree(planning_tree, @release_2, @iteration_2)    
    planning_tree
  end
  
  def check_setting_ambiguous_tree_relationship_value_when(*filters)
    filters_url = filters.map { |single_filer|"filters[]=[#{single_filer[0]}][#{single_filer[1]}][#{single_filer[2]}]"}.join("&")
    
    navigate_to_grid_view_for(@project)    
    set_filter_by_url(@project, filters_url, "grid")  
    drag_and_drop_quick_add_card_to_ungrouped_grid_view

    card_name = "Newly Created Card"  
    type_card_name(card_name)  
    submit_quick_add_card  

    new_card = @project.reload.cards.find_by_name(card_name, :order => 'number desc')
    assert_cards_present_in_grid_view(new_card)      
  end
  
  def get_filter_parameters(target_property, filters)
    filters.map{|operator, value| "filters[]=[#{target_property}][#{operator}][#{value}]"}.join("&")    
  end
  
end
