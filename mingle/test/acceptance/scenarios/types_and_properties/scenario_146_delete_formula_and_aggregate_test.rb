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
class Scenario146DeleteFormulaAggregateTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  PROPERTY = 'numeric_property'
  FORMULA = 'formula'
  FAVORITE = 'favorite'
  AGGREGATE = 'aggregate'
  ANOTHER_AGGREGATE = "aggregate2"
  CARD = 'Card'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    login_as_proj_admin_user
    @project = create_project(:prefix => 'scenario_146', :admins => [users(:proj_admin)], :users => [users(:project_member)])
  end

  def test_deleting_formula_used_in_favorite_would_get_message_with_link
    property = setup_numeric_text_property_definition(PROPERTY)
    formula = setup_formula_property_definition(FORMULA, PROPERTY)
    navigate_to_card_list_for(@project)
    set_mql_filter_for("Type = #{CARD} AND #{FORMULA} = 1")
    favorite = create_card_list_view_for(@project, FAVORITE)
    navigate_to_property_management_page_for(@project)
    delete_property_for(@project, FORMULA, :stop_at_confirmation => true)
    @browser.assert_text_present("is used in team favorite #{FAVORITE}. To manage #{FAVORITE}, please go to team favorites & tabs management page.")
    assert_link_direct_user_to_favorite_management_page("info-box")
  end

  def test_deleting_formula_used_in_favorite_as_column_would_get_message_with_link
    card = create_card!(:name => 'card to show column' )
    property = setup_numeric_text_property_definition(PROPERTY)
    formula = setup_formula_property_definition(FORMULA, PROPERTY)
    navigate_to_card_list_for(@project)
    add_column_for(@project, [FORMULA])
    favorite = create_card_list_view_for(@project, FAVORITE)
    navigate_to_property_management_page_for(@project)
    delete_property_for(@project, FORMULA, :stop_at_confirmation => true)
    @browser.assert_text_present("is used in team favorite #{FAVORITE}. To manage #{FAVORITE}, please go to team favorites & tabs management page.")
    assert_link_direct_user_to_favorite_management_page("info-box")
  end

  def test_deleting_formula_be_aggregated_on_in_aggregate_would_get_message_with_link
    prepare_property_formula_and_tree_for_aggregate
    aggregate = setup_aggregate_property_definition(AGGREGATE, AggregateType::SUM, @formula, @b_a_tree.id, @b_type.id, @a_type)
    navigate_to_property_management_page_for(@project)
    delete_property_for(@project, FORMULA, :stop_at_confirmation => true)
    @browser.assert_text_present "is used as the target property of #{AGGREGATE}. To manage #{AGGREGATE}, please go to configure aggregate properties page."
    assert_link_direct_user_to_target_aggregate("info-box", AGGREGATE)
  end

  def test_deleting_formula_used_in_conditional_aggregate_would_get_message_with_link
    prepare_property_formula_and_tree_for_aggregate
    create_aggregate_property_for(@project, AGGREGATE, @b_a_tree, @b_type, :aggregation_type => 'Count',
    :scope => AggregateScope::DEFINE_CONDITION, :condition => "#{FORMULA} = 1")
    navigate_to_property_management_page_for(@project)
    delete_property_for(@project, FORMULA, :stop_at_confirmation => true)
    @browser.assert_text_present "is used in the condition of #{AGGREGATE}. To manage #{AGGREGATE}, please go to configure aggregate properties page."
    assert_link_direct_user_to_target_aggregate("info-box", AGGREGATE)
  end

  def test_deleting_aggregate_used_in_favorite_would_get_message_with_link
    prepare_property_and_tree_for_aggregate
    aggregate = setup_aggregate_property_definition(AGGREGATE, AggregateType::SUM, @property, @b_a_tree.id, @b_type.id, @a_type)
    navigate_to_card_list_for(@project)
    set_mql_filter_for("Type = #{CARD} AND #{AGGREGATE} = 1")
    favorite = create_card_list_view_for(@project, FAVORITE)
    aggregate = @project.all_property_definitions.find_by_name(AGGREGATE)
    delete_aggregate_property_for(@project, @b_a_tree, @b_type, aggregate)
    @browser.assert_text_present"is used in team favorite #{FAVORITE}. To manage #{FAVORITE}, please go to team favorites & tabs management page."
    assert_link_direct_user_to_favorite_management_page("info-box")
  end

  def test_deleting_aggregate_used_in_favorite_as_column_would_get_message_with_link
    card = create_card!(:name => 'card to show column' )
    prepare_property_and_tree_for_aggregate
    aggregate = setup_aggregate_property_definition(AGGREGATE, AggregateType::SUM, @property, @b_a_tree.id, @b_type.id, @a_type)
    navigate_to_card_list_for(@project)
    add_column_for(@project, [AGGREGATE])
    favorite = create_card_list_view_for(@project, FAVORITE)
    aggregate = @project.all_property_definitions.find_by_name(AGGREGATE)
    delete_aggregate_property_for(@project, @b_a_tree, @b_type, aggregate)
    @browser.assert_text_present"is used in team favorite #{FAVORITE}. To manage #{FAVORITE}, please go to team favorites & tabs management page."
    assert_link_direct_user_to_favorite_management_page("info-box")
  end

  def test_deleting_aggregate_used_in_formula_should_get_message_with_link
    prepare_property_and_tree_for_aggregate
    aggregate = setup_aggregate_property_definition(AGGREGATE, AggregateType::SUM, @property, @b_a_tree.id, @b_type.id, @a_type)
    formula = setup_formula_property_definition(FORMULA,"#{AGGREGATE}")
    aggregate = @project.all_property_definitions.find_by_name(AGGREGATE)
    delete_aggregate_property_for(@project, @b_a_tree, @b_type, aggregate)
    @browser.assert_text_present "is used as a component property of #{FORMULA}. To manage #{FORMULA}, please go to card property management page."
    assert_link_direct_user_to_to_formula_edit_page("info-box", FORMULA)
  end

  def test_deleting_aggregate_used_in_another_aggregate_should_get_message_with_link
    prepare_property_and_tree_for_aggregate
    aggregate = setup_aggregate_property_definition(AGGREGATE, AggregateType::SUM, @property, @b_a_tree.id, @b_type.id, @a_type)
    another_aggregate = create_aggregate_property_for(@project, ANOTHER_AGGREGATE, @b_a_tree, @b_type, :aggregation_type => 'Count',
    :scope => AggregateScope::DEFINE_CONDITION, :condition => "#{AGGREGATE} = 1")
    aggregate = @project.all_property_definitions.find_by_name(AGGREGATE)
    delete_aggregate_property_for(@project, @b_a_tree, @b_type, aggregate)
    @browser.assert_text_present "is used in the condition of #{ANOTHER_AGGREGATE}. To manage #{ANOTHER_AGGREGATE}, please go to configure aggregate properties page."
    assert_link_direct_user_to_target_aggregate("info-box", ANOTHER_AGGREGATE)
  end

  def test_deleting_the_component_of_formula_would_get_message_with_link
    property = setup_numeric_text_property_definition(PROPERTY)
    formula = setup_formula_property_definition(FORMULA, PROPERTY)
    navigate_to_property_management_page_for(@project)
    delete_property_for(@project, PROPERTY, :stop_at_confirmation => true)
    @browser.assert_text_present "is used as a component property of #{FORMULA}. To manage #{FORMULA}, please go to card property management page."
    assert_link_direct_user_to_to_formula_edit_page("info-box", FORMULA)
  end

  def test_deleting_the_property_be_aggregated_on_would_get_message
    prepare_property_and_tree_for_aggregate
    aggregate = setup_aggregate_property_definition(AGGREGATE, AggregateType::SUM, @property, @b_a_tree.id, @b_type.id, @a_type)
    navigate_to_property_management_page_for(@project)
    delete_property_for(@project, PROPERTY, :stop_at_confirmation => true)
    @browser.assert_text_present "is used as the target property of #{AGGREGATE}. To manage #{AGGREGATE}, please go to configure aggregate properties page."
    assert_link_direct_user_to_target_aggregate("info-box", AGGREGATE)
  end

  def test_deleting_the_property_used_in_conditional_aggregate_would_get_message
    prepare_property_and_tree_for_aggregate
    create_aggregate_property_for(@project, AGGREGATE, @b_a_tree, @b_type, :aggregation_type => 'Count',
    :scope => AggregateScope::DEFINE_CONDITION, :condition => "#{PROPERTY} = 1")
    navigate_to_property_management_page_for(@project)
    delete_property_for(@project, PROPERTY, :stop_at_confirmation => true)
    @browser.assert_text_present "is used in the condition of #{AGGREGATE}. To manage #{AGGREGATE}, please go to configure aggregate properties page."
    assert_link_direct_user_to_target_aggregate("info-box", AGGREGATE)
  end

  def test_remove_card_type_from_aggregate_component_would_get_message_with_link
    prepare_property_and_tree_for_aggregate
    aggregate = setup_aggregate_property_definition(AGGREGATE, AggregateType::SUM, @property, @b_a_tree.id, @b_type.id, @a_type)
    update_property_by_removing_card_type(@project, PROPERTY, @a_type.name)
    @browser.assert_text_present "is used as the target property of #{AGGREGATE}. To manage #{AGGREGATE}, please go to configure aggregate properties page."
    assert_link_direct_user_to_target_aggregate("info-box", AGGREGATE)
  end

  def test_remove_card_type_from_formula_component_while_formula_is_used_in_aggregate
    prepare_property_formula_and_tree_for_aggregate
    aggregate = setup_aggregate_property_definition(AGGREGATE, AggregateType::SUM, @formula, @b_a_tree.id, @b_type.id, @a_type)
    update_property_by_removing_card_type(@project, PROPERTY, @a_type.name)
    @browser.assert_text_present "is used as a component property of #{FORMULA}. To manage #{FORMULA}, please go to card property management page."
    assert_link_direct_user_to_to_formula_edit_page("info-box", FORMULA)
  end

  def test_delete_aggregate_by_reconfigurating_tree_would_get_message_with_link
    prepare_property_and_tree_for_aggregate
    aggregate = setup_aggregate_property_definition(AGGREGATE, AggregateType::SUM, @property, @b_a_tree.id, @b_type.id, @a_type)
    formula = setup_formula_property_definition(FORMULA,"#{AGGREGATE}")
    @c_type = setup_card_type(@project, 'type_C')
    @project.reload.activate
    edit_card_tree_configuration(@project, @b_a_tree.name, :types => [@b_type.name, @c_type.name])
    assert_info_message_for_reconfiguring_tree_when_aggregate_can_not_be_deleted(@b_a_tree.name, AGGREGATE, FORMULA)
    assert_link_direct_user_to_to_formula_edit_page("info-box", FORMULA)
  end

  def test_delete_aggregate_by_deleting_tree_would_get_message_with_link
    prepare_property_and_tree_for_aggregate
    aggregate = setup_aggregate_property_definition(AGGREGATE, AggregateType::SUM, @property, @b_a_tree.id, @b_type.id, @a_type)
    formula = setup_formula_property_definition(FORMULA,"#{AGGREGATE}")
    navigate_to_tree_configuration_management_page_for(@project)
    click_delete_link_for(@project, @b_a_tree)
    assert_info_message_for_deleting_tree_when_aggregate_can_not_be_deleted("#{@b_a_tree.name}", FORMULA)
    assert_link_direct_user_to_to_formula_edit_page("info-box", FORMULA)
  end

  def test_remove_property_from_card_type_would_get_massage_with_link
    prepare_property_and_tree_for_aggregate
    aggregate = setup_aggregate_property_definition(AGGREGATE, AggregateType::SUM, @property, @b_a_tree.id, @b_type.id, @a_type)
    edit_card_type_for_project(@project, 'type_A', :uncheck_properties => ['numeric_property'], :wait_on_warning => true)
    @browser.assert_text_present "#{PROPERTY} is used as the target property of #{AGGREGATE}. To manage #{AGGREGATE}, please go to configure aggregate properties page."
    assert_link_direct_user_to_target_aggregate("info-box", AGGREGATE)
  end

  private

  def prepare_property_formula_and_tree_for_aggregate
    prepare_property_and_tree_for_aggregate
    @formula = setup_formula_property_definition(FORMULA, PROPERTY)
    @formula.update_attributes(:card_types => [@a_type])
  end

  def prepare_property_and_tree_for_aggregate
    @a_type = setup_card_type(@project, 'type_A')
    @b_type = setup_card_type(@project, 'type_B')
    @b_a_tree = setup_tree(@project, 'b a tree', :types => [@b_type, @a_type], :relationship_names => ["B"])
    @property = setup_numeric_text_property_definition(PROPERTY)
    @property.update_attributes(:card_types => [@a_type])
  end

end
