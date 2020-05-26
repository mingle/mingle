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

module EditAggregatePropertyAction
  
  def create_aggregate_property_for(project, aggregate_property_name, tree, card_type_node, options = {})
    location = @browser.get_location
    open_aggregate_property_management_page_for(project, tree) unless location =~ /#{project.identifier}\/card_trees\/edit_aggregate_properties\/#{tree.id}/
    aggregation_type = options[:aggregation_type]
    scope = options[:scope] || 'All descendants'
    property_to_aggregate = options[:property_to_aggregate]
    click_on_edit_aggregate_link_on_a_node_for(card_type_node)
    type_aggreage_property_name(aggregate_property_name)
    select_aggregation_type(aggregation_type) unless aggregation_type.to_s == ''
    select_scope(scope) unless scope.to_s == ''
    if scope == AggregateScope::DEFINE_CONDITION then
      type_aggreage_property_condition(options[:condition])
    end
    select_property_to_be_aggregated(property_to_aggregate) unless property_to_aggregate.to_s == ''
    click_on_add_or_update_aggregate_property
    project.all_property_definitions.find_by_name(aggregate_property_name)
  end
  
  def edit_aggregate_property_for(project, tree, card_type_node, aggregate_property, options = {})
    location = @browser.get_location
    open_aggregate_property_management_page_for(project, tree) unless location =~ /#{project.identifier}\/card_trees\/edit_aggregate_properties\/#{tree.id}/
    aggregate_property_name = options[:aggregate_property_name]
    aggregation_type = options[:aggregation_type] 
    scope = options[:scope] 
    property_to_aggregate = options[:property_to_aggregate] 
    click_on_edit_aggregate_link_on_a_node_for(card_type_node)
    click_edit_aggregate_property_for(aggregate_property)
    type_aggreage_property_name(aggregate_property_name) unless aggregate_property_name.to_s == ''
    select_aggregation_type(aggregation_type) unless aggregation_type.to_s == ''
    select_scope(scope) unless scope.to_s == ''
    select_property_to_be_aggregated(property_to_aggregate) unless property_to_aggregate.to_s == ''
    click_on_add_or_update_aggregate_property
    project.all_property_definitions.find_by_name(aggregate_property_name)
  end
  
  def delete_aggregate_property_for(project, tree, card_type_node, aggregate_property)
    location = @browser.get_location
    open_aggregate_property_management_page_for(project, tree) unless location =~ /#{project.identifier}\/card_trees\/edit_aggregate_properties\/#{tree.id}/
    click_on_edit_aggregate_link_on_a_node_for(card_type_node)
    click_delete_aggregate_property_for(aggregate_property)
  end
  
  def click_on_edit_tree_structure
    @browser.click_and_wait(EditAggregatePropertyPageId::EDIT_TREE_STRUCTURE_LINK)
  end
  
  def type_aggreage_property_name(name)
    @browser.type(EditAggregatePropertyPageId::AGGREGARE_PROPERTY_NAME_TEXT_BOX, name)
  end
  
  def type_aggreage_property_condition(conditon)
    @browser.type(EditAggregatePropertyPageId::AGGREGATE_PROPERTY_CONDITION_TEXT_BOX, conditon)
  end
  
  def select_aggregation_type(aggregation_type)
    @browser.select(EditAggregatePropertyPageId::AGGREGATE_PROPERTY_TYPE_DROPDOWN, aggregation_type)
  end
  
  def select_scope(scope)
    @browser.select(EditAggregatePropertyPageId::AGGREGATE_PROPERTY_SCOPE_CARD_TYPE_DROPDOWN, scope)
  end
  
  def select_property_to_be_aggregated(property_name)
    @browser.select(EditAggregatePropertyPageId::AGGREGATE_PROPERTY_AGGREGATE_TARGET_DROPDOWN, property_name)
  end
  
  def click_on_add_or_update_aggregate_property
    @browser.with_ajax_wait do
      @browser.click(EditAggregatePropertyPageId::COMMIT_LINK)
    end
  end
  
  def click_edit_aggregate_property_for(aggregate_property)
    @browser.with_ajax_wait do
      @browser.click(edit_aggregare_property_id(aggregate_property))
    end
  end
  
  def click_on_edit_aggregate_link_on_a_node_for(card_type_node)
    @browser.with_ajax_wait do
      @browser.click(edit_aggregate_link_id(card_type_node))
    end
    @browser.wait_for_element_visible(class_locator('aggregate-popup-outer'))
  end
  
  def click_delete_aggregate_property_for(aggregate_property)
    @browser.with_ajax_wait do
      @browser.click(delete_aggregate_property_id(aggregate_property))
    end
  end
  
end
