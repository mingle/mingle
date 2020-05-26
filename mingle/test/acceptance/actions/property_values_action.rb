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

module PropertyValuesAction

  def create_enumeration_value_for(project, property_definition, enumeration_value, options = {})
    project = project.identifier if project.respond_to? :identifier
    property_definition = Project.find_by_identifier(project).find_property_definition_or_nil(property_definition, :with_hidden => true) unless property_definition.respond_to?(:name)
    @browser.open "/projects/#{project}/enumeration_values/list?definition_id=#{property_definition.id}"
    @browser.type PropertyValuesPageId::ENUMERATION_VALUE_INPUT_BOX_ID, enumeration_value
    @browser.click_and_wait PropertyValuesPageId::CARD_PROPERTIES_ADD_BUTTON
    enum_value = Project.find_by_identifier(project).with_active_project do |project|
      project.find_enumeration_value(property_definition.name, enumeration_value.trim, :with_hidden => true)
    end
    enum_value
  end


  def open_edit_enumeration_values_list_for(project, property_definition)
    project = project.identifier if project.respond_to? :identifier
    property_definition = Project.find_by_identifier(project).find_property_definition_or_nil(property_definition, :with_hidden => true) unless property_definition.respond_to?(:name)
    @browser.open("/projects/#{project}/enumeration_values/list?definition_id=#{property_definition.id}")
  end

  def click_add_property_value_button
    @browser.with_ajax_wait do
      @browser.click PropertyValuesPageId::CARD_PROPERTIES_QUICK_ADD_BUTTON
    end
  end

  def edit_enumeration_value_for(project, property_definition, current_enumeration_value, new_enum_value_name, options = {})
    project = project.identifier if project.respond_to? :identifier
    enum_value = Project.find_by_identifier(project).find_enumeration_value(property_definition, current_enumeration_value, :with_hidden => true)
    property_definition = Project.find_by_identifier(project).find_property_definition_or_nil(property_definition, :with_hidden => true) unless property_definition.respond_to?(:name)
    @browser.open("/projects/#{project}/enumeration_values/list?definition_id=#{property_definition.id}")

    @browser.click(edit_enum_value(enum_value))
    @browser.type(enum_value_name_editor(enum_value), new_enum_value_name)
    @browser.click_and_wait(save_enum_value(enum_value))

    Project.find_by_identifier(project).find_enumeration_value(property_definition.name, new_enum_value_name, :with_hidden => true)
    @browser.assert_element_present(enumeration_value_id(enum_value))
  end

  def edit_enumeration_value_from_edit_page(project, property_name, current_enumeration_value, new_enum_value_name)
    project = project.identifier if project.respond_to? :identifier
    enum_value = Project.find_by_identifier(project).find_enumeration_value(property_name, current_enumeration_value, :with_hidden => true)
    @browser.click(edit_enum_value(enum_value))
    @browser.type(enum_value_name_editor(enum_value), new_enum_value_name)
    @browser.click_and_wait(save_enum_value(enum_value))
  end

  def delete_enumeration_value_for(project, property_definition, enum_value, options={})
    requires_confirmation = options.delete(:requires_confirmation)
    stop_at_confirmation = options.delete(:stop_at_confirmation)
    project = project.identifier if project.respond_to? :identifier
    property_definition = Project.find_by_identifier(project).find_property_definition_or_nil(property_definition) unless property_definition.respond_to?(:name)
    enum_value = Project.find_by_identifier(project).find_enumeration_value(property_definition.name, enum_value) unless enum_value.respond_to?(:name)
    @browser.open("/projects/#{project}/enumeration_values/list?definition_id=#{property_definition.id}")
    if(requires_confirmation)
      @browser.click_and_wait(delete_enum_value_id(enum_value))
      click_continue_to_delete_link unless stop_at_confirmation
    elsif
      @browser.click_and_wait(delete_enum_value_id(enum_value))
    end
  end

  def delete_enum_value(property_name, enum_value_name)
    project = Project.find_by_identifier(@project.identifier)
    property_def = project.find_property_definition(property_name)
    enum_value = project.find_enumeration_value(property_name, enum_value_name)
    @browser.open("/projects/#{project.identifier}/enumeration_values/list?definition_id=#{property_def.id}")
    @browser.click_and_wait(delete_enum_value_id(enum_value))
  end

  def drag_and_dorp_enumeration_value_downward_for(project, property_definition, enum1, enum2)
    @browser.with_drag_and_drop_wait do
      @browser.with_ajax_wait do
        @browser.drag_and_drop_downwards("drag_enumeration_value_#{get_enumeration_value_id_on_property_enumeration_edit_page(project, property_definition, enum1)}","drag_enumeration_value_#{get_enumeration_value_id_on_property_enumeration_edit_page(project, property_definition, enum2)}")
      end
    end
  end

  def drag_and_dorp_enumeration_value_upward_for(project, property_definition, enum1, enum2)
    @browser.with_drag_and_drop_wait do
      @browser.with_ajax_wait do
        @browser.drag_and_drop_upwards("drag_enumeration_value_#{get_enumeration_value_id_on_property_enumeration_edit_page(project, property_definition, enum1)}","drag_enumeration_value_#{get_enumeration_value_id_on_property_enumeration_edit_page(project, property_definition, enum2)}")
      end
    end
  end

  def get_enumeration_value_id_on_property_enumeration_edit_page(project, property_definition, enum_value)
    project = project.identifier if project.respond_to? :identifier
    enum_value = Project.find_by_identifier(project).find_enumeration_value(property_definition, enum_value)
    return enum_value.id
  end

  def change_color(enum_value, color)
    @browser.click "css=##{color_panel_id(enum_value)} .color_block"
    @browser.with_ajax_wait do
      @browser.click "css=.color-selector .color_block[style='background-color: #{color};']"
    end
  end

end
