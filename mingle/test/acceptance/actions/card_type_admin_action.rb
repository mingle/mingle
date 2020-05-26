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

module CardTypeDefaultsAction

  def set_property_defaults(project, properties)
    project = Project.find_by_name(project) unless project.respond_to?(:name)
    project.reload
    properties.each do |property, value|
      property = project.find_property_definition_or_nil(property, :with_hidden => true) unless property.respond_to?(:name)
      property_type = property.attributes['type']
      value = NULL_VALUE if value.nil?
      if need_popup_card_selector?(property_type, value)
        @browser.click(droplist_link_id(property, "defaults"))
        @browser.with_ajax_wait do
          @browser.click droplist_select_card_action(droplist_dropdown_id(property, "defaults"))
        end
        @browser.click card_selector_result_locator(:filter, value.number)
      else
        @browser.assert_visible droplist_link_id(property, "defaults")
        set_property_default(property.name, value)
      end
    end
  end

  def assert_order_of_properties_on_card_defaults(project, *properties)
    project = project.identifier if project.respond_to? :identifier
    next_property = Hash.new
    properties.each_with_index do |property, index|
      if (property != properties.last)
        @browser.wait_for_element_present(CardEditPageId::EDIT_PROPERTIES_CONTAINER)
        property = Project.find_by_identifier(project).find_property_definition(property, :with_hidden => true)
        next_property[index] = Project.find_by_identifier(project).find_property_definition_or_nil(properties[index.next], :with_hidden => true) if property != properties.last
        assert_ordered("defaults_enumeratedpropertydefinition_#{property.id}_span", "defaults_enumeratedpropertydefinition_#{next_property[index].id}_span") unless property == properties.last
      end
    end
  end

  def set_property_defaults_and_save_default_for(project, card_type, options={})
    open_edit_defaults_page_for(project, card_type)
    type_description_defaults(options[:description])
    set_property_defaults(project, options[:properties])
    click_save_defaults
  end

  def set_card_default(card_type, props = {})
    card_type = @project.card_types.find_by_name(card_type.to_s)
    card_defaults = card_type.card_defaults

    props.each do |prop_name, prop_value|
      card_defaults.update_properties(prop_name => prop_value)
      card_defaults.save!
    end
  end

  def edit_card_type_defaults_for(project, card_type, options={})
    description = options[:description]
    open_edit_defaults_page_for(project, card_type)
    create_free_hand_macro(description) if description
    click_save_defaults
  end

  def open_edit_defaults_page_for(project, card_type, options={})
    is_error = options[:error] || false
    project = project.identifier if project.respond_to? :identifier
    card_type  = Project.find_by_identifier(project).card_types.find_by_name(card_type) unless card_type.respond_to?(:name)
    @browser.open("/projects/#{project}/card_types/edit_defaults/#{card_type.id}")
    wait_for_wysiwyg_editor_ready unless is_error
  end

  def set_property_defaults_via_inline_value_add(project, property, value)
    add_new_value_to_property_on_card_default(project, property, value)
  end

  def add_new_value_to_property_on_card_default(project, property, value, options={:plv_exists => false})
    add_new_value_to_property_on_card(project, property, value, "defaults", options)
  end

  def type_description_defaults(description)
    enter_text_in_editor(description)
  end

  def set_property_default(property, value)
    @browser.click droplist_link_id(property, "defaults")
    @browser.click droplist_option_id(property, value, "defaults")
  end

  def click_save_defaults
    @browser.click_and_wait(CardTypeAdminPageId::SAVE_DEFAULTS_LINK)
  end

  def preview_card_defaults
    @browser.with_ajax_wait do
      @browser.click(CardShowPageId::PREVIEW_CARD_LINK)
    end
  end

end

module CardTypeAdminAction
  include CardTypeDefaultsAction

  def navigate_to_card_type_management_for(project)
    project = project.identifier if project.respond_to? :identifier
    @browser.open "/projects/#{project}/card_types/list"
  end

  # add properties for one existing card type without UI
  def add_properties_for_card_type(card_type, properties)
    # card_type_object.property_definitions = properties
    properties.each do|property|
      card_type.add_property_definition(property)
    end
  end

  #create card_type without UI:
  #attention: this method won't assgin exsisting card properties to new card type!
  def add_new_card_type_for(project, card_type_name)
    project.card_types.create!(:name => card_type_name)
  end

  def create_card_type_for_project(project, card_type, options = {})
    navigate_to_card_type_management_for(project)
    click_add_card_type_link
    type_card_type_name(card_type)
    clear_all_selected_properties_for_card_type if options[:properties]
    check_the_properties_required_for_card_type(project, options[:properties]) if options[:properties]
    click_create_card_type
  end

  def click_add_card_type_link
    @browser.click_and_wait(CardTypeAdminPageId::CREATE_NEW_CARD_TYPE_LINK)
  end

  def edit_card_type_for_project(project, card_type_name, options ={})
    new_card_type_name = options[:new_card_type_name] || card_type_name
    open_edit_card_type_page(project, card_type_name)
    type_card_type_name(new_card_type_name)
    @browser.type(CardTypeAdminPageId::CARD_TYPE_NAME_TEXT_BOX_ID,new_card_type_name)
    if(options[:properties])  # jem - need to refactor and remove this option
      clear_all_selected_properties_for_card_type
      check_the_properties_required_for_card_type(project, options[:properties])
    elsif(options[:uncheck_properties])
      uncheck_properties_required_for_card_type(project, options[:uncheck_properties])
    elsif(options[:check_properties])
      check_the_properties_required_for_card_type(project, options[:check_properties])
    end
    save_card_type
    if @browser.get_location =~ /card_types\/confirm_update/
      click_continue_to_update_link if options[:wait_on_warning].nil?
    end
  end

  def click_continue_to_update_link
    @browser.click_and_wait(CardTypeAdminPageId::CONTINUE_TO_UPDATE_ID)
  end

  def click_continue_to_update
    @browser.click_and_wait(CardTypeAdminPageId::CONTINUE_TO_UPDATE_LINK)
  end

  def type_card_type_name(name)
    @browser.type CardTypeAdminPageId::CARD_TYPE_NAME_TEXT_BOX_ID, name
  end

  def open_create_new_card_type_page(project)
    project = project.identifier if project.respond_to? :identifier
    @browser.open("/projects/#{project}/card_types/new")
  end

  def open_edit_card_type_page(project, card_type)
    project = project.identifier if project.respond_to? :identifier
    card_type = Project.find_by_identifier(project).card_types.find_by_name(card_type) unless card_type.respond_to?(:name)
    @browser.open("/projects/#{project}/card_types/edit/#{card_type.id}")
  end

  def check_the_properties_required_for_card_type(project, properties)
    project_identifier = project.identifier if project.respond_to? :identifier
    properties.each do |property|
      property_definition = Project.find_by_identifier(project_identifier).find_property_definition_or_nil(property, :with_hidden => true)
      @browser.click property_definition_check_box(property_definition)
    end
  end

  def clear_all_selected_properties_for_card_type
    @browser.click(CardTypeAdminPageId::SELECT_NONE_LINK)
  end

  def uncheck_properties_required_for_card_type(project, properties)
    project = project.identifier if project.respond_to? :identifier
    properties.each do |property|
      property_definition = Project.find_by_identifier(project).find_property_definition_or_nil(property, :with_hidden => true)
      property_check_box_id = property_definition_check_box(property_definition)
      @browser.click(property_check_box_id) if @browser.is_checked(property_check_box_id)
    end
  end

  def click_create_card_type
    @browser.click_and_wait(CardTypeAdminPageId::CREATE_TYPE_LINK)
  end

  def save_card_type
    @browser.click_and_wait(CardTypeAdminPageId::SAVE_TYPE_LINK)
  end



  def click_cancle_deletion
    @browser.click_and_wait(CardTypeAdminPageId::CANCEL_BOTTOM_ID)
  end

  def delete_card_type(project, card_type_name)
    project = project.identifier if project.respond_to? :identifier
    navigate_to_card_type_management_for(project)
    card_type_definition = Project.find_by_identifier(project).card_types.find_by_name(card_type_name)
    @browser.open("/projects/#{project}/card_types/confirm_delete/#{card_type_definition.id}")
    @browser.click_and_wait(CardTypeAdminPageId::CONFIRM_BOTTOM_ID)
  end

  def get_the_delete_confirm_message_for_card_type(project, card_type_name)
    project = project.identifier if project.respond_to? :identifier
    navigate_to_card_type_management_for(project)
    card_type_definition = Project.find_by_identifier(project).card_types.find_by_name(card_type_name)
    @browser.open("/projects/#{project}/card_types/confirm_delete/#{card_type_definition.id}")
    @browser.wait_for_element_visible "link=Continue to delete"
  end

  def drag_and_dorp_card_type_downward(project, card_type1, card_type2)
    with_ajax_wait do
      @browser.with_drag_and_drop_wait do
        @browser.drag_and_drop_downwards(card_type_drag_drop_id(project, card_type1),card_type_drag_drop_id(project, card_type2))
      end
    end
  end

  def drag_and_dorp_card_type_upward(project, card_type1, card_type2)
    with_ajax_wait do
      @browser.with_drag_and_drop_wait do
        @browser.drag_and_drop_upwards(card_type_drag_drop_id(project, card_type1),card_type_drag_drop_id(project, card_type2))
      end
    end
  end

  def drag_and_drop_properties_downward(project, property1, property2)
    with_ajax_wait do
      @browser.with_drag_and_drop_wait do
        @browser.drag_and_drop_downwards(card_property_drag_and_drop_id(project,property1),card_property_drag_and_drop_id(project, property2))
      end
    end
  end

  def drag_and_drop_properties_upward(project, property1, property2)
    with_ajax_wait do
      @browser.with_drag_and_drop_wait do
        @browser.drag_and_drop_upwards(card_property_drag_and_drop_id(project,property1),card_property_drag_and_drop_id(project, property2))
      end
    end
  end

  def get_property_id_on_card_type_edit_page(project, property_name)
    project = project.identifier if project.respond_to? :identifier
    property = Project.find_by_identifier(project).find_property_definition_or_nil(property_name)
    return property.id
  end

  def get_card_type_id(project, card_type_name)
    project = project.identifier if project.respond_to? :identifier
    card_type_definition = Project.find_by_identifier(project).card_types.find_by_name(card_type_name)
    return card_type_definition.id
  end

end
