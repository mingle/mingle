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

module CardTypeDefaultsPage

  def click_property_on_card_defaults(property)
    click_on_card_property(property, "defaults")
  end

  def assert_property_tooltip_on_card_default_page(property_name)
    property = @project.all_property_definitions.find_by_name(property_name)
    assert_equal property.tooltip, get_property_tooltip(property, 'defaults')
  end

  def assert_value_violation_because_of_parenthesis
    assert_error_message("Value cannot both start with '(' and end with ')' unless it is an existing project variable which is available for this property", :escape => true)
  end

  def assert_card_defaults_updated_message(card_type)
    assert_notice_message("Defaults for card type #{card_type} were successfully updated", :escape => true)
  end

  def assert_properties_set_on_card_defaults(project, properties)
    properties.each { |name, value| assert_property_set_on_card_defaults(project, name, value)  }
  end

  def assert_property_present_on_card_defaults(property)
    @browser.assert_element_matches(CardTypeAdminPageId::EDIT_PROPERTIES_ID, /#{property}/)
  end

  def assert_property_not_present_on_card_defaults(property)
    if @browser.is_element_present(CardTypeAdminPageId::EDIT_PROPERTIES_ID)
      @browser.assert_element_does_not_match(CardTypeAdminPageId::EDIT_PROPERTIES_ID, /#{property}/)
    else
      assert_equal(true, true)
    end
  end

  def assert_default_description(description)
    assert_card_or_page_content_in_edit(description)
  end

  def assert_property_set_on_card_defaults(project, property, value, options={})
    project = Project.find_by_identifier(project) unless project.respond_to?(:identifier)
    project.reload.with_active_project do |active_project|
      property = active_project.reload.find_property_definition(property, :with_hidden => true)
      property_type = property.attributes['type']
      if(options[:plv_exists] || property_type == 'EnumeratedPropertyDefinition' || property_type == 'UserPropertyDefinition' || property_type == 'DatePropertyDefinition')
        @browser.assert_text(droplist_link_id(property, "defaults"), value)
      elsif(property_type == 'TextPropertyDefinition' || property_type == 'AggregatePropertyDefinition')
        @browser.assert_text(editlist_link_id(property, "defaults"), value)
      elsif  (property_type == 'CardRelationshipPropertyDefinition')
        value = card_number_and_name(value) if value.respond_to?(:name)
        @browser.assert_text(droplist_link_id(property, "defaults"), value)
      elsif(property_type == 'TreeRelationshipPropertyDefinition')
        value = card_number_and_name(value) if value.respond_to?(:name)
        @browser.assert_text(droplist_link_id(property, "defaults"), value)
      else
        raise "Property type #{property_type} is not supported"
      end
    end
  end

  def assert_disabled_relationship_property_set_on_card_defaults(project, property, value)
    project = Project.find_by_identifier(project) unless project.respond_to?(:identifier)
    property = project.find_property_definition(property, :with_hidden => true)
    @browser.assert_text(disabled_link_id(property, 'defaults'), value)
  end

  def assert_property_not_editable_on_card_defaults(project, property)
    assert_property_not_editable_in('defaults', project, property)
  end

  def assert_properties_not_editable_on_card_defaults(project, *properties)
    properties.each do |property|
      assert_property_not_editable_in('defaults', project, property)
    end
  end

  def assert_disabled_relationship_property_value_on_card_default(project, properties)
    properties.each do |property, value|
      @browser.assert_text(disabled_link_id(property, 'defaults'), value)
    end
  end

  def assert_plv_name_present_property_dropdown_in_card_default(property_name, project_variable_name)
    project_variable_value = "(#{project_variable_name})"
    assert_values_present_in_property_drop_down(property_name, [project_variable_value], "defaults")
  end

  def assert_plv_name_not_present_property_dropdown_in_card_default(property_name, project_variable_name, property_type)
    project_variable_value = "(#{project_variable_name})"
    assert_values_not_present_in_property_drop_down(property_name, [project_variable_value], "defaults")
  end

  def assert_preview_text(value)
    @browser.wait_for_text_present(value)
  end
end

