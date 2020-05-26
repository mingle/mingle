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

# Tags: properties, formula, aggregate-properties
class Scenario133FormulaOfAggregateCrudTest < ActiveSupport::TestCase
  
  fixtures :users, :login_access
  RELEASE = "Release"
  ITERATION = "Iteration"
  STORY = "Story"
  PLANNING_TREE= "Planning tree"
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin = users(:admin)
    @project = create_project(:prefix => 'scenario_133', :admins => [@project_admin])
    login_as_admin_user   
  end
  
  def teardown
    @project.deactivate
  end
  
  def test_user_can_create_update_delete_formula_using_aggregate
    get_a_R_I_S_tree_ready
    aggregate = setup_aggregate_property_definition('aggregate', AggregateType::COUNT, nil, @tree.id, @iteration_type.id, @story_type)
    formula_created_using_aggregate = create_property_definition_for(@project, 'formula using aggregate', :type => 'formula', :formula => "'#{aggregate.name}' + 2", :types => [ITERATION])
    assert_notice_message("Property was successfully created.")
    
    formula_to_be_edit = formula_created_using_aggregate
    edit_property_definition_for(@project, formula_to_be_edit, :new_formula => "1")    
    assert_notice_message("Property was successfully updated.")
    edit_property_definition_for(@project, formula_to_be_edit, :new_formula => "'#{aggregate.name}' + 2")    
    assert_notice_message("Property was successfully updated.")
      
    delete_property_for(@project, formula_created_using_aggregate)
    assert_notice_message("Property #{formula_created_using_aggregate.name} has been deleted.")   
  end
  
  def test_unhappy_path_of_creating_aggregate_formula
    get_a_R_I_S_tree_ready
    non_existing_agg = 'foo'
    create_property_definition_for(@project, 'formula using aggregate', :type => 'formula', :formula => "#{non_existing_agg} + 2")
    assert_error_message("The formula is not well formed. No such property: #{non_existing_agg}.")
    
    aggregate = setup_aggregate_property_definition('aggregate', AggregateType::COUNT, nil, @tree.id, @iteration_type.id, @story_type)
    create_property_definition_for(@project, 'formula using aggregate', :type => 'formula', :formula => "'#{aggregate.name}' + 2", :types => [RELEASE])
    assert_error_message("The component property should be available to all card types that formula property is available to.")
    
    same_name_of_aggregate = "aggregate"
    create_property_definition_for(@project, same_name_of_aggregate, :type => 'formula', :formula => "'#{aggregate.name}' + 2", :types => [RELEASE])
    assert_error_message("Name has already been taken")   
  end
  
  
  def test_formula_can_not_have_loop
    a_type = setup_card_type(@project, 'type_A')
    b_type = setup_card_type(@project, 'type_B')
    a_b_tree = setup_tree(@project, 'a b tree', :types => [a_type, b_type], :relationship_names => ["A"])         
    b_a_tree = setup_tree(@project, 'b a tree', :types => [b_type, a_type], :relationship_names => ["B"])         
    
    property = setup_numeric_text_property_definition('p1')
    property.update_attributes(:card_types => [a_type])   
    formula_1 = setup_formula_property_definition('f1', "p1")
    formula_1.update_attributes(:card_types => [a_type])  
    aggregate_1 = setup_aggregate_property_definition('a1', AggregateType::SUM, formula_1, b_a_tree.id, b_type.id, a_type)
    formula_2 = setup_formula_property_definition('f2', "a1")
    formula_2.update_attributes(:card_types => [b_type])    
    aggregate_2 = setup_aggregate_property_definition('a2', AggregateType::SUM, formula_2, a_b_tree.id, a_type.id, b_type)   
    edit_property_definition_for(@project, formula_1, :new_formula => formula = "a2")   
    assert_error_message("This formula #{formula_1.name} contains a circular reference. Formulas and aggregates cannot contain circular references.")
  end
  
  def test_user_can_not_remove_aggregate_which_is_used_in_formula_directly_or_by_changing_tree_configuration
    get_a_R_I_S_tree_ready  
    aggregate = setup_aggregate_property_definition('aggregate', AggregateType::COUNT, nil, @tree.id, @iteration_type.id, AggregateScope::ALL_DESCENDANTS)
    formula_with_aggregate = create_property_definition_for(@project, 'formula using aggregate', :type => 'formula', :formula => "#{aggregate.name} + 2", :types => [ITERATION])
    delete_aggregate_property_for(@project, @tree, @iteration_type, aggregate)
    assert_info_box_light_message("used as a component property of #{formula_with_aggregate.name}")
    
    navigate_to_tree_configuration_management_page_for(@project)
    click_delete_link_for(@project, @tree)
    assert_info_message_for_deleting_tree_when_aggregate_can_not_be_deleted('Planning tree', formula_with_aggregate.name)
    
    remove_a_card_type_and_wait_on_confirmation_page(@project, @tree, @iteration_type) 
    assert_info_message_for_reconfiguring_tree_when_aggregate_can_not_be_deleted(@tree.name, aggregate.name, formula_with_aggregate.name)
    remove_a_card_type_and_wait_on_confirmation_page(@project, @tree, @story_type)     
    assert_info_message_for_reconfiguring_tree_when_aggregate_can_not_be_deleted(@tree.name, aggregate.name, formula_with_aggregate.name)
  end

  # bug #7019
  def test_negative_value_used_in_complex_aggregate_formula_should_not_throw_500_error
    get_a_R_I_S_tree_ready
    
    estimate = setup_numeric_property_definition('estimate',[2,4,6])
    estimate.update_attributes(:card_types => [@story_type])    
    start_date = setup_date_property_definition('start on')
    start_date.update_attributes(:card_types => [@story_type])
    finish_date = setup_date_property_definition('finish on')
    finish_date.update_attributes(:card_types => [@story_type])
    actual_effort = setup_formula_property_definition('actual effort', "'finish on' - 'start on'")
    actual_effort.update_attributes(:card_types => [@story_type])
    
    effort_in_iteration = setup_aggregate_property_definition('total effort', AggregateType::SUM, actual_effort, @tree.id, @iteration_type.id, @story_type)
    estimate_in_iteration = setup_aggregate_property_definition('total estimate', AggregateType::SUM, estimate, @tree.id, @iteration_type.id, @story_type)
    balance_in_iteration = setup_formula_property_definition('balance', "'total estimate' - 'total effort'")
    balance_in_iteration.update_attributes(:card_types => [@iteration_type])
    
    balance_in_release = setup_aggregate_property_definition('total balance', AggregateType::SUM, balance_in_iteration, @tree.id, @release_type.id, @iteration_type)
    release_date = setup_date_property_definition('release date')
    release_date.update_attributes(:card_types => [@project.card_types.find_by_name(RELEASE)])
    
    
    iteration_card = create_card!(:card_type => @iteration_type, :name => 'iteration' )   
    release_card = create_card!(:card_type => @release_type, :name => 'release' )
    add_card_to_tree(@tree, release_card) 
    add_card_to_tree(@tree, iteration_card, release_card)
    story_card = create_card!(:card_type => @story_type, :name => 'story', 'estimate' => 4, 'start on' => '01 Jan 2001', 'finish on' => '07 Jan 2001' )                          
    add_card_to_tree(@tree, story_card, iteration_card)
    AggregateComputation.run_once
    sleep 1 
    navigate_to_property_management_page_for(@project)  
    new_release_date = create_property_definition_for(@project, "new release date", :type => 'formula', :formula => "'release date' + 'total balance'", :types => [RELEASE])
    assert_notice_message("Property was successfully created.")    
  end
  
  # bug 7034
  def test_user_should_be_able_to_create_update_aggregate_formula_when_aggregate_is_recalculating
    get_a_R_I_S_tree_ready
    aggregate = setup_aggregate_property_definition('aggregate', AggregateType::COUNT, nil, @tree.id, @release_type.id, AggregateScope::ALL_DESCENDANTS)
    create_cards_and_add_them_onto_tree
    
    navigate_to_tree_view_for(@project, @tree.name)
    click_remove_card_from_tree(@story_card, @tree)
    formula_created_using_aggregate = create_property_definition_for(@project, 'formula using aggregate', :type => 'formula', :formula => "'#{aggregate.name}'", :types => [RELEASE])
    assert_notice_message("Property was successfully created.")
    edit_property_definition_for(@project, formula_created_using_aggregate, :new_formula => "'#{aggregate.name}' + 1")    
    assert_notice_message("Property was successfully updated.")     
  end
  
  private
  def get_a_R_I_S_tree_ready
    @release_type = setup_card_type(@project, RELEASE)
    @iteration_type = setup_card_type(@project, ITERATION)
    @story_type = setup_card_type(@project, STORY)
    @project.reload.activate
    @tree = setup_tree(@project, PLANNING_TREE, :types => [@release_type, @iteration_type, @story_type], :relationship_names => ["Release", "Iteration"])         
  end
  
  def get_tree_aggregate_and_formula_ready
    get_a_R_I_S_tree_ready  
    @aggregate = setup_aggregate_property_definition('aggregate', AggregateType::COUNT, nil, @tree.id, @release_type.id, AggregateScope::ALL_DESCENDANTS)
    @project.reload.activate
    @formula_created_using_aggregate = setup_formula_property_definition('formula using aggregate',"'#{@aggregate.name}'")
    @formula_created_using_aggregate.update_attributes(:card_types => [@release_type])
  end
  
  def create_cards_and_add_them_onto_tree
    @iteration_card = create_card!(:card_type => @iteration_type, :name => 'iteration' )
    @release_card = create_card!(:card_type => @release_type, :name => 'release' )
    @story_card = create_card!(:card_type => @story_type, :name => 'story')
    add_card_to_tree(@tree, @release_card)
    add_card_to_tree(@tree, @iteration_card, @release_card)
    add_card_to_tree(@tree, @story_card, @iteration_card)
  end
  
end
