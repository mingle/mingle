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

module PropertyValuesPage
  def assert_enum_value_present_on_enum_management_page(*values)
    values.each do |value|
      @browser.assert_element_present(enum_values_on_mgmt_page(value))
    end
  end

  def assert_enum_value_not_present_on_enum_management_page(*values)
    values.each do |value|
      @browser.assert_element_not_present(enum_values_on_mgmt_page(value))
    end
  end

  def assert_property_does_have_value(property_definition, value)
    click_property_values_link_on_property_management_page(property_definition)
    @browser.assert_element_present(enum_values_on_mgmt_page(value))
    @browser.click_and_wait(SharedFeatureHelperPageId::CLICK_UP_LINK)
  end

  def assert_enum_values_in_order(*values)
    values.each_with_index do |value, index|
      @browser.assert_ordered(enumeration_value_id(value), "enumeration_value_#{values[index + 1].id}") unless value == values.last
    end
  end

  def assert_property_does_not_have_value(property_definition, value)
    @browser.click_and_wait(enumeration_values_id(property_definition))
    @browser.assert_element_not_present(enum_values_on_mgmt_page(value))
    @browser.click_and_wait(SharedFeatureHelperPageId::CLICK_UP_LINK)
  end

  def assert_enumerated_values_order_in_propertys_edit_page(project, property_definition, *enums)
    enums.each_with_index do |enum, index|
      assert_ordered("enumeration_value_#{get_enumeration_value_id_on_property_enumeration_edit_page(project, property_definition, enum)}", "enumeration_value_#{get_enumeration_value_id_on_property_enumeration_edit_page(project, property_definition, enums[index + 1])}") unless enum == enums.last
    end
  end

  def assert_all_enum_values_in_order(project, property, values)
    project = project.identifier if project.respond_to? :identifier
    property = Project.find_by_identifier(project).find_property_definition(property, :with_hidden => true)
    all_values = Project.find_by_identifier(project).find_enumeration_values(property)
    values.each_with_index do |value, index|
      value = Project.find_by_identifier(project).find_enumeration_value(property, value, :with_hidden => true)
      assert_equal(enumeration_value_id(value), "enumeration_value_#{all_values[index].id}")
    end
  end
end
