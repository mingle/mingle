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


module CardTypeAdminPage

  def assert_card_type_present_on_card_type_management_page(card_type)
    @browser.assert_element_matches("content", /#{card_type}/)
  end

  def assert_card_type_not_present_on_card_type_management_page(card_type)
    @browser.assert_element_does_not_match("content", /#{card_type}/)
  end

  def assert_card_type_present(project, card_type_name)
    project = project.identifier if project.respond_to? :identifier
    card_type_definition = Project.find_by_identifier(project).card_types.find_by_name(card_type_name)
    @browser.assert_text_present(card_type_definition.name)
  end

  def assert_card_type_can_be_edited(project, card_type_name)
    project = project.identifier if project.respond_to? :identifier
    card_type_definition = Project.find_by_identifier(project).card_types.find_by_name(card_type_name)
    assert_link_present("/projects/#{project}/card_types/edit/#{card_type_definition.id}")
  end

  def assert_card_type_cannot_be_deleted(project, card_type_name)
    project = project.identifier if project.respond_to? :identifier
    card_type_definition = Project.find_by_identifier(project).card_types.find_by_name(card_type_name)
    assert_link_not_present("/projects/#{project}/card_types/confirm_delete/#{card_type_definition.id}")
  end

  def assert_card_type_can_be_deleted(project, card_type_name)
    project = project.identifier if project.respond_to? :identifier
    card_type_definition = Project.find_by_identifier(project).card_types.find_by_name(card_type_name)
    assert_link_present("/projects/#{project}/card_types/confirm_delete/#{card_type_definition.id}")
  end

  def assert_all_properties_available_for_card_type(project, options)
    project = project.identifier if project.respond_to? :identifier
    properties = options[:properties] || []
    properties.each do |property|
      property_definition = Project.find_by_identifier(project).find_property_definition_or_nil(property)
      @browser.assert_element_present(property_definition_check_box(property_definition))
    end
  end

  def assert_property_present_on_card_type_edit_page(project, property)
    project = project.identifier if project.respond_to? :identifier
    property = Project.find_by_identifier(project).find_property_definition_or_nil(property, :with_hidden => true) unless property.respond_to?(:name)
    @browser.assert_element_present(card_type_property_name_id(property))
  end

  def assert_properties_selected_for_card_type(project, *properties)
    project = project.identifier if project.respond_to? :identifier
    properties.each do |property|
      property_definition = Project.find_by_identifier(project).find_property_definition_or_nil(property, :with_hidden => true)
      @browser.assert_checked(property_definition_check_box(property_definition))
    end
  end

  def assert_properties_not_selected_for_card_type(project, *properties)
    project = project.identifier if project.respond_to? :identifier
    properties.each do |property|
      property_definition = Project.find_by_identifier(project).find_property_definition_or_nil(property, :with_hidden => true)
      @browser.assert_not_checked(property_definition_check_box(property_definition))
    end
  end

  def assert_card_types_ordered_in_card_type_management_page(project, *card_types)
    comma_joined_values = @browser.get_eval(%{
      this.browserbot.getCurrentWindow().$$('.link_button').pluck('id').join(',');
    })
    card_type_ids = comma_joined_values.split(',').collect{ |html_id| html_id.gsub(/drag_card_type_/, '').to_i }
    expected = card_types.collect {|card_type| get_card_type_id(project, card_type)}
    assert_equal(expected, card_type_ids, "expected order: #{card_types.join(", ")}")
  end

  def assert_properties_order_in_card_type_edit_page(project, *properties)
    properties.each_with_index do |property, index|
      assert_ordered("card_type_property_row_#{get_property_id_on_card_type_edit_page(project, property)}", "card_type_property_row_#{get_property_id_on_card_type_edit_page(project, properties[index+1])}") unless property == properties.last
    end
  end

  def assert_drag_and_drop_not_possible
    @browser.assert_element_not_present(css_locator('div#content .table-top th.col4'))
  end

  def assert_drag_and_drop_is_possible
    @browser.assert_element_matches(css_locator('div#content .table-top th.col4'), /Order/)
  end

  def assert_properties_not_draggable(project, *properties)
    properties.each do |property|
      @browser.assert_not_visible("drag_property_definition_#{get_property_id_on_card_type_edit_page(project, property)}")
    end
  end

  def assert_properties_draggable(project, *properties)
    properties.each do |property|
      @browser.assert_visible("drag_property_definition_#{get_property_id_on_card_type_edit_page(project, property)}")
    end
  end

  def assert_change_type_confirmation_for_single_card_present
    @browser.assert_text_present "Confirm card type change"
    @browser.assert_text_present "With this card type change this card will lose:"
    @browser.assert_text_present "values of any properties that are not common between the types"
    @browser.assert_text_present "tree memberships if the new card type is not available to the same trees"
    @browser.assert_text_present "Note: All previous property values will be recorded in the card's history."
  end

  def assert_change_type_confirmation_for_multiple_cards_present
    @browser.assert_text_present "Confirm card type change"
    @browser.assert_text_present "With card type changes these cards will lose:"
    @browser.assert_text_present "values of any properties that are not common between the types"
    @browser.assert_text_present "tree memberships if the new card type is not available to the same trees"
    @browser.assert_text_present "Note: All previous property values will be recorded in the cards' history."
  end
end
