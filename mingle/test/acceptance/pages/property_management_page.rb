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

module PropertyManagementPage

  def remove_normal_property_from_project_cards_table(property_name)
    @project.connection.remove_column(CardSchema.generate_cards_table_name(@project.identifier), "cp_#{property_name}")
  end

  #applied for card relationship property and tree relationship property
  def remove_relationship_property_from_project_cards_table(property_name)
    @project.connection.remove_column(CardSchema.generate_cards_table_name(@project.identifier), "cp_#{property_name}_card_id")
  end

  #applied for user property e.g. owner
  def remove_user_type_property_from_project_cards_table(property_name)
    @project.connection.remove_column(CardSchema.generate_cards_table_name(@project.identifier), "cp_#{property_name}_user_id")
  end

  def assert_normal_property_corruption_info_for_admin_present(property_name)
    @browser.assert_text_present("Property #{property_name} is corrupt. You can rectify this issue by deleting this property.")
  end

  def assert_tree_relationship_property_corruption_info_for_admin_present(property_name)
    @browser.assert_text_present("Property #{property_name} is corrupt, please contact support.")
  end

  def assert_tree_relationship_property_corruption_info_for_admin_not_present(property_name)
    @browser.assert_text_not_present("Property #{property_name} is corrupt, please contact support.")
  end

  def assert_normal_property_corruption_info_for_admin_not_present(property_name)
    @browser.assert_text_not_present("Property #{property_name} is corrupt. You can rectify this issue by deleting this property.")
  end

  def assert_property_corruption_info_for_non_admin_users_present
    @browser.assert_text_present("Mingle found a problem it couldn't fix. Please contact your Mingle administrator. When the administrator accesses this project they should be able to rectify the issue by deleting the corrupt property.")
  end

  def assert_property_corruption_info_for_non_admin_users_not_present
    @browser.assert_text_not_present("Mingle found a problem it couldn't fix. Please contact your Mingle administrator. When the administrator accesses this project they should be able to rectify the issue by deleting the corrupt property.")
  end



  def assert_property_name_too_long_error_present(propery_name)
    @browser.wait_for_element_present(SharedFeatureHelperPageId::ERROR)
    @browser.assert_element_present(SharedFeatureHelperPageId::ERROR)
    @browser.assert_text_present("#{propery_name}\'s value is too long \(maximum is 255 characters\)")
  end

  def assert_property_updated_success_message_present
    @browser.assert_text_present(PropertyManagementPageId::UPDATE_SUCCESSFUL_MESSAGE)
  end

  def assert_property_exists(property_def)
    @browser.assert_element_present(property_row_id(property_def))
  end

  def assert_properties_exist(*property_defs)
    property_defs.each {|property_def| @browser.assert_element_present(property_row_id(property_def))}
  end

  def assert_property_does_not_exist(property)
    @browser.assert_element_does_not_match(PropertyManagementPageId::PROPERTY_DEFINATION_TABLE_LIST_ID, /^#{property}$/)
  end

  def assert_property_present_on_property_management_page(property)
    @browser.assert_element_matches(PropertyManagementPageId::PROPERTY_DEFINATIONS_ID, /#{property}/)
  end

  def assert_property_not_present_on_property_management_page(property)
    @browser.assert_element_does_not_match(PropertyManagementPageId::PROPERTY_DEFINATIONS_ID, /#{property}/)
  end

  def assert_properties_present_on_property_management_page(properties)
    properties.each do |property|
    assert_property_present_on_property_management_page(property)
    end
  end

  def assert_hide_check_box_disabled_for(project, property)
    property = project.reload.find_property_definition(property) unless property.respond_to?(:name)
    assert_disabled(visibility_property_definition(property))
  end

  def assert_hide_check_box_enabled_for(project, property)
    property = project.reload.find_property_definition(property)
    assert_enabled(visibility_property_definition(property))
  end

  def assert_lock_check_box_enabled_for(project, property)
    property = project.reload.find_property_definition(property)
    assert_enabled(restricted_property_definition(property))
  end

  def assert_lock_check_box_disabled_for(project, property)
    property = project.reload.find_property_definition(property) unless property.respond_to?(:name)
    assert_disabled(restricted_property_definition(property))
  end

  def assert_lock_check_box_not_present_for(project, property)
    property = project.reload.find_property_definition(property)
    @browser.assert_element_not_present(restricted_property_definition(property))
  end

  def assert_lock_check_box_not_applicable(project, property)
    property = project.reload.find_property_definition(property)
    @browser.assert_element_text("xpath=//tr[@id='prop_def_row_#{property.id}']/td[4]",'(n/a)')
  end

  def assert_unlock_link_not_present_for(project, property)
    property = project.reload.find_property_definition(property)
    @browser.assert_element_not_present("unlock_property_def_#{property.id}")
  end

  def assert_card_property_link_not_present(project, property)
    project = project.identifier if project.respond_to? :identifier
    property_definition = Project.find_by_identifier(project).find_property_definition(property)
    assert_link_not_present("/projects/#{project}/enumeration_values/list?definition_id=#{property_definition.id}")
  end

  def assert_locked_for(project, property)
    project = project.identifier if project.respond_to? :identifier
    property = Project.find_by_identifier(project).find_property_definition(property, :with_hidden => true)
    @browser.assert_checked(restricted_property_definition(property))
  end

  def assert_unlocked_for(project, property)
    project = project.identifier if project.respond_to? :identifier
    property = Project.find_by_identifier(project).find_property_definition(property)
    @browser.assert_not_checked(restricted_property_definition(property))
  end

  def assert_hidden_is_checked_for(project, property)
    project = project.identifier if project.respond_to? :identifier
    property = Project.find_by_identifier(project).find_property_definition(property, :with_hidden => true)
    @browser.assert_checked(visibility_property_definition(property))
  end

  def assert_hidden_is_not_checked_for(project, property)
    project = project.identifier if project.respond_to? :identifier
    property = Project.find_by_identifier(project).find_property_definition(property)
    @browser.assert_not_checked(visibility_property_definition(property))
  end

  def assert_transition_only_is_checked_for(project, property)
    project = project.identifier if project.respond_to? :identifier
    property = Project.find_by_identifier(project).find_property_definition_or_nil(property, :with_hidden => true) unless property.respond_to?(:name)
    @browser.assert_checked(transitiononly_property_definition(property))
  end

  def assert_transition_only_is_not_checked_for(project, property)
    project = project.identifier if project.respond_to? :identifier
    property = Project.find_by_identifier(project).find_property_definition_or_nil(property, :with_hidden => true) unless property.respond_to?(:name)
    @browser.assert_not_checked(transitiononly_property_definition(property))
  end

  def assert_transition_only_check_box_enabled(project, property)
    property = project.reload.find_property_definition(property)
    assert_enabled(transitiononly_property_definition(property))
  end

  def assert_transition_only_check_box_disabled(project, property)
    property = project.reload.find_property_definition(property)
    assert_disabled(transitiononly_property_definition(property))
  end

  def assert_transition_only_check_box_not_present_for(project, property)
    property = project.reload.find_property_definition(property)
    @browser.assert_element_not_present(transitiononly_property_definition(property))
  end

  def assert_card_types_checked_or_unchecked_in_create_new_property_page(project, options)
     project = project.identifier if project.respond_to? :identifier
     card_types_checked = options[:card_types_checked] || []
     card_types_checked.each do |card_type|
       card_type_definition = Project.find_by_identifier(project).card_types.find_by_name(card_type)
       @browser.assert_checked(card_types_definition(card_type_definition))
     end
     card_types_unchecked = options[:card_types_unchecked] || []
     card_types_unchecked.each do |card_type|
       card_type_definition = Project.find_by_identifier(project).card_types.find_by_name(card_type)
       @browser.assert_not_checked(card_types_definition(card_type_definition))
     end
  end

  def assert_on_property_create_page_for(project)
    project = project.identifier if project.respond_to? :identifier
    @browser.assert_location("/projects/#{project}/property_definitions/create")
  end

  def assert_formula_for_formula_property(formula)
    @browser.assert_value(PropertyManagementPageId::PROPERTY_DEFINITION_FORMULA_TEXT_BOX, formula)
  end

  def assert_properties_order_in_property_management_list(properties)
    property_id_collection = properties.collect{|property| property_row_id(property) }
    assert_ordered(*property_id_collection)
  end

  def assert_link_direct_user_to_target_aggregate(message_type, aggregate_name)
    target_url = @browser.get_element_attribute("css=div.#{message_type} li a", 'href')
    @browser.open target_url
    @browser.wait_for_page_to_load
    @browser.wait_for_all_ajax_finished
    aggregate_id = @project.all_property_definitions.find_by_name(aggregate_name)
    @browser.assert_element_present(delete_aggregate_property_id(aggregate_id))
  end

  def assert_link_direct_user_to_to_formula_edit_page(message_type, formula_name)
    target_url = @browser.get_element_attribute("css=div.#{message_type} li a", 'href')
    @browser.open target_url
    @browser.assert_title "#{@project.name} Edit Property_definition - Mingle"
    @browser.assert_value(PropertyManagementPageId::PROPERTY_DEFINTION_NAME_ID, formula_name)
    @browser.assert_element_present("css=.action-bar a.delete")
  end

end
