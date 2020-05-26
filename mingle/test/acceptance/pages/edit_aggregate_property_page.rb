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

module EditAggregatePropertyPage
  def assert_leaf_node_deos_not_have_edit_aggregate_link(leaf_node_type)
    @browser.assert_element_not_present(edit_aggregate_link_id(leaf_node_type))
  end
  
  def assert_aggregate_property_present_on_configuration_for(aggregate_property)
    @browser.assert_element_present(edit_aggregare_property_id(aggregate_property))
    @browser.assert_element_present(delete_aggregate_property_id(aggregate_property))
  end
  
  
  def assert_aggregate_property_not_present_on_configuration(aggregate_property)
    
    @browser.assert_element_does_not_match(EditAggregatePropertyPageId::AGGREGATE_LIST_ID, /#{aggregate_property}/)
  end
  
  def assert_no_aggregate_configured
    @browser.assert_text_present('This card type currently has no aggregate properties.')
  end
  
  def assert_properties_available_on_target_property_drop_down(*properties)
    properties.each do |property|
      @browser.assert_drop_down_contains_value(EditAggregatePropertyPageId::AGGREGATE_PROPERTY_AGGREGATE_TARGET_DROPDOWN, property.id)
    end
  end
  
  def assert_properties_not_available_on_target_property_drop_down(*properties)
    properties.each do |property|
      @browser.assert_drop_down_does_not_contain_value(EditAggregatePropertyPageId::AGGREGATE_PROPERTY_AGGREGATE_TARGET_DROPDOWN, property.id)
    end
  end
  
  def assert_target_drop_down_names_are(names)
    drop_down_names = @browser.get_all_drop_down_option_values(EditAggregatePropertyPageId::AGGREGATE_PROPERTY_AGGREGATE_TARGET_DROPDOWN)
    assert_equal names, drop_down_names
  end
  
  def assert_aggregate_value_being_out_of_date_tool_tip_shown_for(aggregate_property)
    actual_tool_tip = @browser.get_attribute("#{property_editor_id(aggregate_property.name)}@title")
    assert_equal("This value may be out of date. Refresh this page to view updated aggregates.", actual_tool_tip)
  end
  
  def assert_value_for_target_type_present_in_drop_down(target_property)
    flag = false
    target_properties_length = @browser.get_eval("this.browserbot.getCurrentWindow().$('aggregate_property_definition_aggregate_target_id').length")
    (0..target_properties_length.to_i - 1).each do |index|
      value = @browser.get_eval("this.browserbot.getCurrentWindow().$('aggregate_property_definition_aggregate_target_id')[#{index}].value")
      if(value == target_property.id.to_s)
        flag = true
      else
        flag = false
      end
    end
    if(flag)
      true
    else
      raise "Property #{target_property.name} is not present in dropdown" 
    end
  end
    
  def assert_set_parameters_for_aggregate_property(aggregate_property_name, aggregate_type, scope_type = nil, target_property = nil)
    @browser.assert_value(EditAggregatePropertyPageId::AGGREGARE_PROPERTY_NAME_TEXT_BOX, aggregate_property_name)
    @browser.assert_selected_value(EditAggregatePropertyPageId::AGGREGATE_PROPERTY_TYPE_DROPDOWN, aggregate_type.upcase)
    @browser.assert_selected_value(EditAggregatePropertyPageId::AGGREGATE_PROPERTY_AGGREGATE_TARGET_DROPDOWN, target_property.id) if target_property != nil
    if(scope_type != '')
      @browser.assert_selected_value(EditAggregatePropertyPageId::AGGREGATE_PROPERTY_SCOPE_CARD_TYPE_DROPDOWN, scope_type.id) if target_property != nil
    else
      @browser.assert_selected_value(EditAggregatePropertyPageId::AGGREGATE_PROPERTY_SCOPE_CARD_TYPE_DROPDOWN, scope_type) if target_property != nil
    end
  end
  
  def assert_aggregate_description(index, aggregate_property_definition, expected_description)
    @browser.assert_text(aggregate_description_id(index), expected_description)
    @browser.assert_visible(css_locator("li#modify-aggregate-#{aggregate_property_definition.id}"))
  end
  
end
