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

module CardTreeAdminPage
  def assert_warning_messages_on_tree_node_remove(tree_node_type, relationship_property, options ={})
    aggregate_properties = options[:aggregate_properties] || ''
    count = 0
    count = aggregate_properties.length if aggregate_properties != ''
    assert_info_box_light_message("Cards of type #{tree_node_type} will be removed from the tree.")
    assert_info_box_light_message("Children of type #{tree_node_type} will be assigned to the deleted type's parent.")
    assert_info_box_light_message("The following 1 property will be deleted: #{relationship_property}")
    if(count >= 2)
      assert_info_box_light_message("The following #{count} aggregates will be deleted: #{aggregate_properties.join(' and ')}") 
      assert_info_box_light_message('Pages and tables/charts that use these properties will no longer work.')
    elsif(count == 1)
      assert_info_box_light_message("The following 1 aggregate will be deleted: #{aggregate_properties}") 
      assert_info_box_light_message('Pages and tables/charts that use this property will no longer work.')
    elsif(count == 0)
      assert_info_box_light_message('Pages and tables/charts that use this property will no longer work.')
    end
  end
  
  def assert_warning_messages_on_tree_delete(options = {})
    number_of_cards_on_tree = options[:number_of_cards_on_tree] || nil
    relationship_properties = options[:relationship_properties] || nil
    relationship_properties = [relationship_properties] unless relationship_properties.is_a?(Array)
    aggregate_properties = options[:aggregate_properties] || nil
    aggregate_properties = [aggregate_properties] unless aggregate_properties.is_a?(Array)
    transitions = options[:transitions] || nil
    transitions = [transitions] unless transitions.is_a?(Array)
    assert_info_box_light_message("#{number_of_cards_on_tree} card belongs to this tree.") if number_of_cards_on_tree != nil
    assert_info_box_light_message("The following 2 properties will be deleted: #{relationship_properties.to_sentence}") if relationship_properties != nil
    assert_info_box_light_message("The following 1 aggregate property will be deleted: #{aggregate_properties.to_sentence}") if aggregate_properties != nil
    assert_info_box_light_message("The following 1 transition will be deleted: #{transitions.to_sentence}") if transitions != nil
    assert_info_box_light_message("Properties deleted cannot be recovered and will no longer be displayed in history.")
    assert_info_box_light_message("Any favorites and tabs that use this tree or its properties will be deleted.")
    assert_info_box_light_message('Tables or charts that use this tree or its properties may no longer work.')
  end

  def assert_relationship_property_name_on_tree_configuration(relationship_property, options = {})
    relationship_propertys_number = options[:relationship_propertys_number] || '0'
    actual_value = @browser.get_eval("this.browserbot.getCurrentWindow().$('edit_relationship_#{relationship_propertys_number}_link').innerHTML")
    assert_equal(relationship_property, actual_value)
  end
  
  def assert_error_box_present_for_relationship_property(type_node_number = '0')
    textbox_type = @browser.get_eval("this.browserbot.getCurrentWindow().$('relationship_#{type_node_number}_name_field').hasClassName('relationship-name-field inline-editor error-editor')")
    assert_equal('true', textbox_type)
  end
  
  def assert_delete_link_present_on_card_tree_management_admin_page
    if @browser.is_element_present(SharedFeatureHelperPageId::DELETE_LINK)
      true
    else
      @browser.assert_fail "No delete link on this page"
    end
  end
  
  def assert_delete_link_not_present_on_card_tree_management_admin_page
    if @browser.is_element_present(SharedFeatureHelperPageId::DELETE_LINK)
      @browser.assert_fail "There should not be delete link on this page"
    else
      true
    end
  end
  
  def assert_tree_and_hierarchy_view_navigation_link_present_on_tree_management_page
    if(@browser.is_element_present(CardTreeAdminPageId::TREE_VIEW_LINK && CardTreeAdminPageId::HIERARCHY_VIEW_LINK))
      true
    else
      raise "There should be links Tree and Hierarchy view..."
    end
  end
  
  def assert_tree_configuraiton_not_created(relationship_property_name, error = "Name #{relationship_property_name} is a reserved property name")
    type_relationship_name_on_tree_configuration_for(0, relationship_property_name)
    click_save_link
    @browser.assert_text_present(error)
  end

  def assert_tree_configuration_form_not_present
    @browser.assert_element_not_present(CardTreeAdminPageId::TREE_NAME_TEXT_BOX)
    @browser.assert_element_not_present(CardTreeAdminPageId::TREE_DESCRIPTION_TEXT_BOX)
    @browser.assert_element_not_present(CardTreeAdminPageId::TREE_CONFIGURATION_VIEW)
  end
  
  # positions begin at 0
  def assert_tree_position_in_list(tree_name, position)
    @browser.assert_text("card-tree-name-row-#{position}", tree_name)
  end
  
  def assert_info_message_for_deleting_tree_when_aggregate_can_not_be_deleted(tree_name, formula_name)
    assert_info_box_light_message("#{tree_name} cannot be deleted as properties in this tree are currently used by this project..*used as a component property of #{formula_name}")
  end
  
  def assert_info_message_for_reconfiguring_tree_when_aggregate_can_not_be_deleted(tree_name, aggregate_name, formula_name)
    assert_info_message("#{tree_name} cannot be reconfigured as properties in this tree are currently used by this project.*used as a component property of #{formula_name}")
  end
  
  def assert_error_message_for_property_can_not_deleted_because_used_as_target_property_in_aggregate(aggregate)
    @browser.assert_text_present("used as the target property of #{aggregate.name}")
  end
end
