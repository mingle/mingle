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

module ProjectVariableAdminPage
  
  NOT_SET = '(not set)'
  
  def assert_on_project_variables_list_page_for(project)
    @browser.assert_location("/projects/#{project.identifier}/project_variables/list")
  end
  
  def assert_project_variable_present_on_property_management_page(project_variable)
    @browser.assert_element_matches(SharedFeatureHelperPageId::CONTENT, /#{project_variable}/)
  end
  
  def assert_project_variable_not_present_on_property_management_page(project_variable)
    @browser.assert_element_does_not_match(SharedFeatureHelperPageId::CONTENT, /#{project_variable}/)
  end
  
  def assert_card_value_present_on_property_management_page(card)
    card = card_number_and_name(card) if card.respond_to?(:name)
    @browser.assert_element_matches(SharedFeatureHelperPageId::CONTENT, /#{card}/)
  end
  
  def assert_card_value_not_present_on_property_management_page(card)
    card = card_number_and_name(card) if card.respond_to?(:name)
    @browser.assert_element_does_not_match(SharedFeatureHelperPageId::CONTENT, /#{card}/)
  end
  
  def assert_project_variable_name(name)
    @browser.assert_value(ProjectVariableAdminPageId::PROJECT_VARIABLE_NAME_ID, name)
  end
  
  def assert_project_variable_data_type_selected(data_type)
    @browser.assert_checked(project_variable_data_type_radio_button(data_type))
  end
  
  def assert_CARD_DATA_TYPE_is_disabled
    @browser.assert_element_not_editable(project_variable_data_type_radio_button(ProjectVariable::CARD_DATA_TYPE))
  end
  
  def assert_card_type_selected_for_project_variable(project, card_type)
    project = Project.find_by_identifier(project) unless project.respond_to?(:identifier)
    card_type = project.card_types.find_by_name(card_type) unless card_type.respond_to?(:name)
    @browser.assert_checked(card_type_radio_button(card_type))
  end
  
  def assert_card_type_not_selected_for_project_variable(project, card_type)
    project = Project.find_by_identifier(project) unless project.respond_to?(:identifier)
    card_type = project.card_types.find_by_name(card_type) unless card_type.respond_to?(:name)
    @browser.assert_not_checked(card_type_radio_button(card_type))
  end
  
  def assert_card_types_ordered_on_card_type_management_page(project, *card_types)
    comma_joined_values = @browser.get_eval(%{
      this.browserbot.getCurrentWindow().$$('.card_type_radio_button').pluck('id').join(',');
    })
    ordered_project_variable_card_type_ids = comma_joined_values.split(',').collect{ |html_id| html_id.gsub(/project_variable_card_type_id_/, '').to_i }
    card_types.each_with_index do |card_type, index|
      assert_equal(ordered_project_variable_card_type_ids[index], get_card_type_id(project, card_type))
    end
  end
  
  def assert_properties_selected_for_project_variable(project, *properties)
    project = project.identifier if project.respond_to? :identifier
    properties.each do |property|    
      property_definition = Project.find_by_identifier(project).find_property_definition_or_nil(property, :with_hidden => true)
      @browser.assert_checked(property_definitions_check_box(property_definition))
    end
  end
  
  def assert_properties_not_selected_for_project_variable(project, *properties)
    project = project.identifier if project.respond_to? :identifier
    properties.each do |property|    
      property_definition = Project.find_by_identifier(project).find_property_definition_or_nil(property, :with_hidden => true)
      @browser.assert_not_checked(property_definitions_check_box(property_definition)) if @browser.is_element_present(property_definitions_check_box(property_definition))
    end
  end
  
  def assert_properties_present_for_association_to_project_variable(project, *properties)
    project = project.identifier if project.respond_to? :identifier
    properties.each do |property|    
      property_definition = Project.find_by_identifier(project).find_property_definition_or_nil(property, :with_hidden => true)
      @browser.assert_element_present(property_definitions_check_box(property_definition))
    end
  end
  
  def assert_properties_not_present_for_association_to_project_variable(project, *properties)
    project = project.identifier if project.respond_to? :identifier
    properties.each do |property|    
      property_definition = Project.find_by_identifier(project).find_property_definition_or_nil(property, :with_hidden => true)
      @browser.assert_element_not_present(property_definitions_check_box(property_definition))
    end
  end
  
  def assert_property_not_present_in_property_table_on_plv_edit_page(property)
    @browser.assert_element_does_not_match(ProjectVariableAdminPageId::AVAILABLE_PROPERTY_DEFINATION_CONTAINER, /#{property}/)
  end
  
  def assert_value_for_project_variable(project, project_variable, value)
    project = project.identifier if project.respond_to? :identifier
    project_variable = Project.find_by_identifier(project).project_variables.find_by_name(project_variable) unless project_variable.respond_to?(:name)
    data_type = project_variable.data_type
    if(data_type == ProjectVariable::STRING_DATA_TYPE || data_type == ProjectVariable::NUMERIC_DATA_TYPE)
      @browser.assert_value(ProjectVariableAdminPageId::PROJECT_VARIABLE_VALUE_ID, value)
    elsif(data_type == ProjectVariable::USER_DATA_TYPE)
      value = value.name if value.respond_to?(:name)
      @browser.assert_text(ProjectVariableAdminPageId::PROJECT_VARIABLE_DROP_LINK, value)
    elsif(data_type == ProjectVariable::DATE_DATA_TYPE)
      @browser.assert_text(ProjectVariableAdminPageId::PROJECT_VARIABLE_EDIT_LINK, value)
    elsif(data_type == ProjectVariable::CARD_DATA_TYPE)
      value = card_number_and_name(value) if value.respond_to?(:name)
      @browser.assert_text(ProjectVariableAdminPageId::EDIT_PROJECT_VALUE_DROP_LINK, value)
    else
      raise "Data type #{data_type} for project variable is not supported"
    end
  end
  
  def assert_user_not_available_as_value(user)
    @browser.assert_element_not_present(project_variable_options(user.name))
  end
  
  def assert_users_available_as_value(*users)
    @browser.click(ProjectVariableAdminPageId::PROJECT_VARIABLE_DROP_LINK)
    users.each do |user|
      @browser.assert_element_present(project_variable_options(user.name))
    end
  end
  
  def assert_users_in_user_value_dropdown_are_ordered(*ordered_user_names)
    @browser.click(ProjectVariableAdminPageId::PROJECT_VARIABLE_DROP_LINK)
    ordered_user_names[0..-2].each_with_index do |value, index|
      @browser.assert_ordered(project_variable_options(value), project_variable_options(ordered_user_names[index+1]))
    end
  end
  
  def assert_card_types_not_present_on_plv_create_edit_page(project, *card_types)
    project = project.identifier if project.respond_to? :identifier
    card_types.each do |card_type|
      card_type = Project.find_by_identifier(project).card_types.find_by_name(card_type) unless card_type.respond_to?(:name)
      @browser.assert_element_not_present(card_type_radio_button(card_type))
    end
   end

   def assert_card_types_present_on_plv_create_edit_page(project, *card_types)
     project = project.identifier if project.respond_to? :identifier
     card_types.each do |card_type|
       card_type = Project.find_by_identifier(project).card_types.find_by_name(card_type) unless card_type.respond_to?(:name)
       @browser.assert_element_present(card_type_radio_button(card_type))
     end
   end
   
  def assert_no_cards_available_for_type_message(project, card_type_name)
    @browser.assert_text_present("There are no cards matching your criteria.")
  end
  
  def assert_successful_project_variable_update(project_variable)
    assert_notice_message("Project variable #{project_variable.name} was successfully updated.")
  end
end
