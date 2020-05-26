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
class Scenario134FormulaOfAggregateUsageTest < ActiveSupport::TestCase


  fixtures :users, :login_access
  RELEASE = "Release"
  ITERATION = "Iteration"
  STORY = "Story"
  PLANNING_TREE= "Planning tree"

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin = users(:admin)
    @project = create_project(:prefix => 'scenario_134', :admins => [@project_admin])
    login_as_admin_user
  end

  # aggregate recalculating invalidate value of aggregate formula
  def test_removing_card_type_from_tree_would_invalidate_value_of_aggregate_formula
    get_tree_aggregate_formula_and_cards_ready
    AggregateComputation.run_once
    remove_a_card_type_and_save_tree_configuraiton(@project, @tree, @story_type)
    open_card(@project, @release_card)
    assert_stale_value(@formula_created_using_aggregate.name, "2")
  end

  def test_adding_cards_on_tree_would_invalidate_value_of_aggregate_formula
    get_tree_aggregate_formula_and_cards_ready
    AggregateComputation.run_once
    quick_add_cards_on_tree(@project, @tree, @iteration_card, :card_names => ['story 2'])
    open_card(@project, @release_card)
    assert_stale_value(@formula_created_using_aggregate.name, "2")
  end

  def test_removing_cards_from_tree_would_invalidate_value_of_aggregate_formula
    get_tree_aggregate_formula_and_cards_ready
    AggregateComputation.run_once
    navigate_to_tree_view_for(@project, @tree.name)
    click_remove_card_from_tree(@story_card, @tree)
    open_card(@project, @release_card)
    assert_stale_value(@formula_created_using_aggregate.name, "2")
  end

  # p->a->f, p's value changes, f's value will change
  def test_updating_original_property_value_would_invalidate_value_of_aggregate_formula
    get_a_R_I_S_tree_ready
    property = setup_numeric_property_definition('original property',['1','2'])
    property.update_attributes(:card_types => [@story_type])
    aggregate = setup_aggregate_property_definition('aggregate', AggregateType::SUM, property, @tree.id, @release_type.id, @story_type)
    formula_created_using_aggregate = create_property_definition_for(@project, 'formula using aggregate', :type => 'formula', :formula => "'#{aggregate.name}'", :types => [RELEASE])
    create_cards_and_add_them_onto_tree
    open_card(@project, @story_card)
    set_properties_on_card_show(property.name => 1)

    AggregateComputation.run_once
    sleep 1
    navigate_to_card_list_for(@project)
    add_column_for(@project, [formula_created_using_aggregate.name])
    check_cards_in_list_view(@story_card)
    click_edit_properties_button
    set_bulk_properties(@project, property.name => '2')
    assert_card_list_property_value(formula_created_using_aggregate, @release_card, '* 1')
  end

  # p->a->f, a's definition changes, f's value will change
  def test_change_aggregate_definition_would_invalidate_value_of_aggregate_formula
    get_tree_aggregate_formula_and_cards_ready
    AggregateComputation.run_once
    edit_aggregate_property_for(@project, @tree, @release_type, @aggregate, :aggregation_type => 'Count', :scope => "#{@story_type.name}")
    open_card(@project, @release_card)
    assert_stale_value(@formula_created_using_aggregate.name, "2")
  end

  # p->f1->a->f2, f1's definition changes, f2's value will change
  def test_changing_definition_of_formula_used_in_aggregate_would_invalidate_value_of_aggregate_formula
    get_a_R_I_S_tree_ready
    setup_numeric_property_definition('p1',['1','2']).update_attributes(:card_types => [@iteration_type, @story_type])
    formula_used_in_aggregate = setup_formula_property_definition('f1', "p1")
    formula_used_in_aggregate.update_attributes(:card_types => [@iteration_type, @story_type])
    aggregate = setup_aggregate_property_definition('a1', AggregateType::SUM, @project.all_property_definitions.find_by_name('f1'), @tree.id, @release_type.id, AggregateScope::ALL_DESCENDANTS)
    formula_created_using_aggregate = create_property_definition_for(@project, 'formula using aggregate', :type => 'formula', :formula => "'#{aggregate.name}'", :types => [RELEASE])
    create_cards_and_add_them_onto_tree
    AggregateComputation.run_once
    open_card(@project, @story_card)
    set_properties_on_card_show('p1' => 1)
    AggregateComputation.run_once

    edit_property_definition_for(@project, formula_used_in_aggregate, :new_formula => formula = "'p1' + 2")
    open_card(@project, @release_card)
    assert_stale_value(formula_created_using_aggregate.name, "1")
  end


  # change events of aggregate fromula should generate history
  def test_creating_and_editing_aggregate_formula_generate_history
    get_a_R_I_S_tree_ready
    aggregate = setup_aggregate_property_definition('aggregate', AggregateType::COUNT, nil, @tree.id, @release_type.id, AggregateScope::ALL_DESCENDANTS)
    create_cards_and_add_them_onto_tree
    AggregateComputation.run_once
    sleep 1
    formula_created_using_aggregate = create_property_definition_for(@project, 'formula using aggregate', :type => 'formula', :formula => "'#{aggregate.name}'", :types => [RELEASE])

    open_card(@project, @release_card)
    assert_history_for(:card, @release_card.number).version(2).shows(:set_properties => {formula_created_using_aggregate.name => '2'})

    edit_property_definition_for(@project, formula_created_using_aggregate, :new_formula => formula = "'#{aggregate.name}' + 2")
    open_card(@project, @release_card)
    assert_history_for(:card, @release_card.number).version(3).present
  end

  def test_history_generation_when_aggregate_formula_changed_because_of_tree_reconfiguration
    get_tree_aggregate_formula_and_cards_ready
    AggregateComputation.run_once
    sleep 1
    remove_a_card_type_and_save_tree_configuraiton(@project, @tree, @story_type)
    AggregateComputation.run_once
    @browser.run_once_history_generation
    sleep 1
    open_card(@project, @release_card)
    assert_history_for(:card, @release_card.number).version(3).shows(:changed => @formula_created_using_aggregate.name, :from => '2', :to => '1')
  end

  def test_history_generation_when_aggregate_formula_changed_because_add_removing_card_on_tree
    get_tree_aggregate_formula_and_cards_ready
    AggregateComputation.run_once
    sleep 1
    quick_add_cards_on_tree(@project, @tree, @iteration_card, :card_names => ['story 2'])
    AggregateComputation.run_once
    @browser.run_once_history_generation
    open_card(@project, @release_card)
    assert_history_for(:card, @release_card.number).version(3).shows(:changed => @formula_created_using_aggregate.name, :from => '2', :to => '3')

    navigate_to_tree_view_for(@project, @tree.name)
    click_remove_card_from_tree(@story_card, @tree)
    AggregateComputation.run_once
    sleep 1
    @browser.run_once_history_generation
    open_card(@project, @release_card)
    assert_history_for(:card, @release_card.number).version(4).shows(:changed => @formula_created_using_aggregate.name, :from => '3', :to => '2')
  end

  # p->a->f, p's value changes, f's value will change
  def test_history_generation_when_aggregate_formula_changed_because_original_property_value_change
    get_a_R_I_S_tree_ready
    property = setup_numeric_property_definition('original property',['1','2'])
    property.update_attributes(:card_types => [@story_type])
    aggregate = setup_aggregate_property_definition('aggregate', AggregateType::SUM, property, @tree.id, @release_type.id, @story_type)
    formula_created_using_aggregate = create_property_definition_for(@project, 'formula using aggregate', :type => 'formula', :formula => "'#{aggregate.name}'", :types => [RELEASE])
    create_cards_and_add_them_onto_tree
    AggregateComputation.run_once
    sleep 1
    open_card(@project, @story_card)
    set_properties_on_card_show(property.name => 1)
    AggregateComputation.run_once
    sleep 1
    @browser.run_once_history_generation
    open_card(@project, @release_card)
    assert_history_for(:card, @release_card.number).version(2).shows(:set_properties => {formula_created_using_aggregate.name => '1'})
  end

  # p->a->f, a's definition changes, f's value will change
  def test_history_generation_when_aggregate_formula_changed_because_aggregate_definition_changes
    get_tree_aggregate_formula_and_cards_ready
    AggregateComputation.run_once
    sleep 1
    edit_aggregate_property_for(@project, @tree, @release_type, @aggregate, :aggregation_type => 'Count', :scope => "#{@story_type.name}")
    AggregateComputation.run_once
    sleep 1
    @browser.run_once_history_generation
    open_card(@project, @release_card)
    assert_history_for(:card, @release_card.number).version(3).shows(:changed => @formula_created_using_aggregate.name, :from => '2', :to => '1')
  end

  # p->f1->a->f2, f1's definition changes, f2's value will change
  def test_history_generation_when_aggregate_formula_changes_because_another_formula_used_in_aggregate_changes_its_definition
    get_a_R_I_S_tree_ready
    setup_numeric_property_definition('p1',['1','2']).update_attributes(:card_types => [@iteration_type, @story_type])
    formula_used_in_aggregate = setup_formula_property_definition('f1', "p1")
    formula_used_in_aggregate.update_attributes(:card_types => [@iteration_type, @story_type])
    aggregate = setup_aggregate_property_definition('a1', AggregateType::SUM, @project.all_property_definitions.find_by_name('f1'), @tree.id, @release_type.id, AggregateScope::ALL_DESCENDANTS)
    formula_created_using_aggregate = create_property_definition_for(@project, 'formula using aggregate', :type => 'formula', :formula => "'#{aggregate.name}'", :types => [RELEASE])
    create_cards_and_add_them_onto_tree
    AggregateComputation.run_once
    sleep 1
    open_card(@project, @story_card)
    set_properties_on_card_show('p1' => 1)
    AggregateComputation.run_once
    edit_property_definition_for(@project, formula_used_in_aggregate, :new_formula => formula = "'p1' + 2")
    AggregateComputation.run_once
    open_card(@project, @release_card)
    assert_history_for(:card, @release_card.number).version(3).shows(:changed => formula_created_using_aggregate.name, :from => '1', :to => '3')
  end

  def test_should_give_errors_when_you_try_to_change_a_aggregate_property_name_and_type
    get_tree_aggregate_and_formula_ready
    create_property_definition_for(@project, 'foo', :type => 'any number')
    create_formula_property_definition_for(@project, 'bar', "'foo'")
    open_property_for_edit(@project, 'foo')
    type_property_name('foozor')
    uncheck_card_types_required_for_a_property(@project, :card_types => ['Card'])
    click_save_property
    @browser.wait_for_element_present('info')
    @browser.assert_element_matches('info', /foo is used as a component property of bar. To manage bar, please go to card property management page./)
  end

  # #Fred! Story#11078
  # def test_allow_formula_to_specify_how_to_handle_not_set
  #   get_a_R_I_S_tree_ready
  #   test_effort = setup_numeric_property_definition('Testing Effort',['3','5'])
  #   dev_effort = setup_numeric_property_definition('Development Effort',['4','6'])
  #
  #   test_effort.update_attributes(:card_types => [@story_type])
  #   dev_effort.update_attributes(:card_types => [@story_type])
  #
  #   release = create_card!(:card_type => @release_type, :name => 'release_1' )
  #   iteration_1 = create_card!(:card_type => @iteration_type, :name => 'iteration_2')
  #   iteration_2 = create_card!(:card_type => @iteration_type, :name => 'iteration_2')
  #   story_1 = create_card!(:card_type => @story_type, :name => 'story_1', "Testing Effort" => 3)
  #   story_2 = create_card!(:card_type => @story_type, :name => 'story_2', "Testing Effort" => 5)
  #
  #   add_card_to_tree(@tree, release)
  #   add_card_to_tree(@tree, iteration_1, release)
  #   add_card_to_tree(@tree, story_1, iteration_1)
  #   add_card_to_tree(@tree, story_2, iteration_1)
  #
  #   total_test_effort_in_iteration = create_aggregate_property_for(@project, 'total_test_effort_in_iteration', @tree, @iteration_type, :aggregation_type => 'Sum',
  #   :property_to_aggregate => "Testing Effort")
  #   total_dev_effort_in_iteartion = create_aggregate_property_for(@project, 'total_dev_effort_in_iteration', @tree, @iteration_type, :aggregation_type => 'Sum',
  #   :property_to_aggregate => "Development Effort")
  #
  #    create_property_definition_for(@project, 'Total Effort in Iteration', :type => 'formula', :formula => "'total_test_effort_in_iteration' + 'total_dev_effort_in_iteration'", :replace_not_set => true, :types => ITERATION)
  #    create_property_definition_for(@project, 'Total Effort in Story', :type => 'formula', :formula => "'Testing Effort' + 'Development Effort'", :replace_not_set => true, :types => STORY)
  #    AggregateComputation.run_once
  #    open_card(@project, story_1)
  #    assert_properties_set_on_card_show('Total Effort in Story' => '3')
  #
  #    open_card(@project, story_2)
  #    assert_properties_set_on_card_show('Total Effort in Story' => '5')
  # end

  #Fred! Story#11078
  def test_allow_formulas_to_specify_how_to_handle_not_set
    @story_type = setup_card_type(@project, STORY)
    test_effort = setup_numeric_property_definition('Testing Effort',['3','5'])
    dev_effort = setup_numeric_property_definition('Development Effort',['4','6'])

    test_effort.update_attributes(:card_types => [@story_type])
    dev_effort.update_attributes(:card_types => [@story_type])

    story_1 = create_card!(:card_type => @story_type, :name => 'story_1', "Testing Effort" => 3)
    story_2 = create_card!(:card_type => @story_type, :name => 'story_2', "Testing Effort" => 5, "Development Effort" => 6)

    create_property_definition_for(@project, 'Total Effort in Story', :type => 'formula', :formula => "'Testing Effort' + 'Development Effort'", :replace_not_set => true, :types => [STORY])
    open_card(@project, story_1)
    assert_properties_set_on_card_show('Total Effort in Story' => '3')

    open_card(@project, story_2)
    assert_properties_set_on_card_show('Total Effort in Story' => '11')
  end

  def test_date_property_should_remain_not_set_when_not_set_is_handled_as_zero
    @story_type = setup_card_type(@project, STORY)
    start_date = create_date_property('Start Date')
    end_date = create_date_property('End Date')

    start_date.update_attributes(:card_types => [@story_type])
    end_date.update_attributes(:card_types => [@story_type])

    story_1 = create_card!(:card_type => @story_type, :name => 'story_1', 'Start Date' => 'Jun 10 2011', 'End Date' => 'Jun 20 2011')
    story_2 = create_card!(:card_type => @story_type, :name => 'story_2', 'End Date' => 'Jun 20 2011')

    create_property_definition_for(@project, 'Duration in days', :type => 'formula', :formula => "'End Date' - 'Start Date'", :replace_not_set => true, :types => [STORY])
    open_card(@project, story_1)
    assert_properties_set_on_card_show('Duration in days' => '10')

    open_card(@project, story_2)
    assert_properties_set_on_card_show('Duration in days' => '(not set)')
  end

  private
  def get_a_R_I_S_tree_ready
    @release_type = setup_card_type(@project, RELEASE)
    @iteration_type = setup_card_type(@project, ITERATION)
    @story_type = setup_card_type(@project, STORY)
    @project.reload.activate
    @tree = setup_tree(@project, PLANNING_TREE, :types => [@release_type, @iteration_type, @story_type], :relationship_names => ["Release", "Iteration"])
  end

  def create_cards_and_add_them_onto_tree
    @iteration_card = create_card!(:card_type => @iteration_type, :name => 'iteration' )
    @release_card = create_card!(:card_type => @release_type, :name => 'release' )
    @story_card = create_card!(:card_type => @story_type, :name => 'story')
    add_card_to_tree(@tree, @release_card)
    add_card_to_tree(@tree, @iteration_card, @release_card)
    add_card_to_tree(@tree, @story_card, @iteration_card)
  end

  def get_tree_aggregate_and_formula_ready
    get_a_R_I_S_tree_ready
    @aggregate = setup_aggregate_property_definition('aggregate', AggregateType::COUNT, nil, @tree.id, @release_type.id, AggregateScope::ALL_DESCENDANTS)
    @formula_created_using_aggregate = setup_formula_property_definition('formula using aggregate',"'#{@aggregate.name}'")
    @formula_created_using_aggregate.update_attributes(:card_types => [@release_type])
  end

  def get_tree_aggregate_formula_and_cards_ready
    get_tree_aggregate_and_formula_ready
    create_cards_and_add_them_onto_tree
  end

end
