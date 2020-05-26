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

module PropertyManagementAction

  # following 9 method are for creating properties without UI
  
  def create_property_for_card(property_type, property_name, options={})
    if property_type == PropertyManagementPageId::MANAGED_TEXT_TYPE
      setup_property_definitions("#{property_name}" => ['low', 'medium', 'high', 'very high'])
    elsif property_type == PropertyManagementPageId::FREE_TEXT_TYPE
      setup_text_property_definition property_name
    elsif property_type == PropertyManagementPageId::MANAGED_NUMBER_TYPE
      setup_numeric_property_definition(property_name, [1,2,3,4,5])
    elsif property_type == PropertyManagementPageId::FREE_NUMBER_TYPE
      setup_numeric_text_property_definition(property_name)
    elsif property_type == PropertyManagementPageId::USER_TYPE
      setup_user_definition(property_name)
    elsif property_type == PropertyManagementPageId::DATE_TYPE
      setup_date_property_definition(property_name)
    elsif property_type == PropertyManagementPageId::CARD_TYPE
      setup_card_relationship_property_definition(property_name)
    elsif property_type == PropertyManagementPageId::FORMULA_TYPE
      setup_formula_property_definition(property_name, options[:formula])
    else
      raise "Property type #{property_type} is not supported"
    end       
  end
  
  def create_allow_any_text_property(name)
    setup_allow_any_text_property_definition(name)
  end

  def create_allow_any_number_property(name)
    setup_allow_any_number_property_definition(name)
  end

  def create_managed_number_list_property(name, values)
    setup_numeric_property_definition(name, values)
  end

  def create_date_property(name)
    setup_date_property_definition(name)
  end

  def create_formula_property(name, formula)
    setup_formula_property_definition(name, formula)
  end

  def create_card_type_property(name)
    setup_card_relationship_property_definition(name.to_s)
  end

  def create_team_property(name)
    setup_user_definition(name)
  end 
  
  def create_relationshop_property_for_card(property_name, card_type = "Card")
    parent_card_type = setup_card_type(@project, 'parent')
    child_card_type =  @project.card_types.find_by_name(card_type)
    tree_for_relationship = setup_tree(@project, 'tree', :types => [parent_card_type, child_card_type], :relationship_names => [property_name])
  end
  
  def navigate_to_property_management_page_for(project)
    project = project.identifier if project.respond_to? :identifier
    @browser.open "/projects/#{project}/property_definitions"
  end
  
  def create_managed_text_list_property(name, values)
    setup_managed_text_definition(name, values)
  end
  
  def click_delete_link_for_property(property_def)
    @browser.click_and_wait(delete_property_definition(property_def))
  end
  
  def click_property_values_link_on_property_management_page(property_definition)
    @browser.click_and_wait(enumeration_values_property_definition_id(property_definition))
  end
  
  # create the properties from UI
  def create_property_definition_for(project, property_name, options = {})
    __project = project
    property_type = options[:type].downcase if options[:type] != nil
    project = project.identifier if project.respond_to? :identifier
    @browser.open "/projects/#{project}/property_definitions/new"
    @browser.click(PropertyManagementPageId::PROPERTY_TYPE_ANY_TEXT_ID) if property_type == 'any text'
    @browser.click(PropertyManagementPageId::PROPERTY_TYPE_NUMBER_LIST_ID) if property_type == 'number list'
    @browser.click(PropertyManagementPageId::PROPERTY_TYPE_ANY_NUMBER_ID) if property_type == 'any number'
    @browser.click(PropertyManagementPageId::PROPERTY_TYPE_TEAM_ID) if property_type == 'user'
    @browser.click(PropertyManagementPageId::PROPERTY_TYPE_DATE_ID) if property_type == 'date'
    @browser.click(PropertyManagementPageId::PROPERTY_TYPE_CARD_ID) if property_type == 'card'
    
    if property_type == PropertyManagementPageId::FORMULA_TYPE
      @browser.click(PropertyManagementPageId::PROPERTY_TYPE_FORMULA_ID)
      type_formula(options[:formula])
      if options[:replace_not_set]
        @browser.check(PropertyManagementPageId::PROPERTY_TYPE_FORMULA_CHECKBOX)
      end      
    end
    type_property_name(property_name)
    @browser.type PropertyManagementPageId::PROPERTY_DEFINITION_DESCRIPTION_ID, options[:description] || ''
    check_the_card_types_required_for_property(project, options) if options[:types]
    click_create_property
    __project.reload
    __project.activate
    __project.find_property_definition_or_nil(property_name)
  end
  
  def create_formula_property_definition_for(project, property_name, formula, options={})
    create_property_definition_for(project, property_name, options.merge(:type => PropertyManagementPageId::FORMULA_TYPE, :formula => formula))
  end
  
  def type_property_name(property_name)
    @browser.type PropertyManagementPageId::PROPERTY_DEFINTION_NAME_ID, property_name
  end
  
  def type_property_description(property_description)
    @browser.type(PropertyManagementPageId::PROPERTY_DEFINITION_DESCRIPTION_ID, property_description)
  end
  
  def check_the_card_types_required_for_property(project, options)  
    project = project.identifier if project.respond_to? :identifier
    @browser.click(PropertyManagementPageId::SELECT_NONE_PROPERTY_AVAILABLE_ID)       
    card_types = options[:types] || []
    card_types.each do |card_type_name|
      card_type = Project.find_by_identifier(project).find_card_type(card_type_name)
      @browser.click(card_types_locator(card_type))
    end
  end
  
  def add_properties_for_existing_card_type(project, card_type, property_name)
    open_property_for_edit(project, property_name)
    @browser.click(card_types_locator(card_type))
    click_save_property
  end
  
  def type_formula(formula)
    @browser.type(PropertyManagementPageId::PROPERTY_DEFINITION_FORMULA_TEXT_BOX, formula)
  end
  
  def click_none_for_card_types
    @browser.click(PropertyManagementPageId::SELECT_NONE_PROPERTY_AVAILABLE_ID)
  end
  
  def edit_property_definition_for(project, current_property_name, options = {})
    __project = project
    stop_at_confirmation = options[:stop_at_confirmation]
    new_property_name = options[:new_property_name]
    new_formula = options[:new_formula]
    check_card_types = options[:card_types_to_check]
    uncheck_card_types = options[:card_types_to_uncheck]
    project = project.identifier if project.respond_to? :identifier
    open_property_for_edit(project, current_property_name)
    type_property_name(new_property_name) if new_property_name != nil
    @browser.type PropertyManagementPageId::PROPERTY_DEFINITION_DESCRIPTION_ID, options[:description] || ''
    type_formula(new_formula) if new_formula != nil
    check_the_card_types_required_for_a_property(project, :card_types => check_card_types) if check_card_types != nil
    uncheck_card_types_required_for_a_property(project, :card_types => uncheck_card_types) if uncheck_card_types != nil
    click_save_property
    if @browser.is_element_present(PropertyManagementPageId::CONTINUE_TO_UPDATE_LINK)
      click_continue_update unless stop_at_confirmation != nil
    end
    __project.reload
    __project.activate
    __project.find_property_definition_or_nil(new_property_name)
  end
  
  def click_continue_update
    @browser.click_and_wait PropertyManagementPageId::CONTINUE_UPDATE_BOTTOM_BUTTON
  end
  
  def click_save_property
    @browser.click_and_wait PropertyManagementPageId::SAVE_PROPERTY_LINK
  end
  
  def click_create_property
    @browser.click_and_wait PropertyManagementPageId::CREATE_PROPERTY_LINK
  end
  
  def click_create_new_card_property
    @browser.click_and_wait PropertyManagementPageId::CREATE_NEW_CARD_PROPERTY_LINK
  end
  
  def open_property_for_edit(project, property_name)
    project = Project.find_by_identifier(project) unless project.respond_to? :identifier
    property_definition = project.find_property_definition_or_nil(property_name, :with_hidden => true)
    @browser.open("/projects/#{project.identifier}/property_definitions/edit/#{property_definition.id}")
  end
    
  def open_new_property_create_page_for(project)
    project = project.identifier if project.respond_to? :identifier
    @browser.open "/projects/#{project}/property_definitions/new"
  end
  
  def delete_property_for(project, property_name, options = {})
    stop_at_confirmation = options.delete(:stop_at_confirmation)
    project = project.identifier if project.respond_to? :identifier
    property_def = Project.find_by_identifier(project).find_property_definition_or_nil(property_name, options)
    @browser.click_and_wait(delete_property_definition(property_def))
    click_continue_to_delete_link unless stop_at_confirmation
  end
    
  def click_delete_link_of_property(project, property_name)
    property = project.reload.find_property_definition(property_name)
    @browser.click_and_wait(delete_property_definition(property))
  end
  
  def lock_property(project, property)
    location = @browser.get_location
    navigate_to_property_management_page_for(project) unless location =~ /#{project.identifier}\/property_definitions/
    property = project.reload.find_property_definition(property, :with_hidden => true)
    unless (@browser.is_checked(restricted_property_definition(property)))
      @browser.with_ajax_wait do
        @browser.click(restricted_property_definition(property))
      end
    end
  end
  
  def unlock_property(project, property)
    navigate_to_property_management_page_for(project)
    property = project.reload.find_property_definition(property)
    if (@browser.is_checked(restricted_property_definition(property)))
      @browser.with_ajax_wait do
        @browser.click(restricted_property_definition(property))
      end
    end
  end
  
  def hide_property(project, property, options={})
    stop_at_confirmation = options.delete(:stop_at_confirmation)
    navigate_to_property_management_page_for(project)
    property = project.reload.find_property_definition(property)
    unless (@browser.is_checked(visibility_property_definition(property)))
      @browser.with_ajax_wait do
        @browser.click(visibility_property_definition(property))
      end
      click_hide_property_link unless stop_at_confirmation
    end
  end
  
  def show_hidden_property(project, property)
    navigate_to_property_management_page_for(project)
    property = project.reload.find_property_definition(property, :with_hidden => true)
    if (@browser.is_checked(visibility_property_definition(property)))
      @browser.with_ajax_wait do
        @browser.click(visibility_property_definition(property))
      end
    end
  end
  
  def click_hide_property_link
    @browser.click_and_wait(PropertyManagementPageId::CONFIRM_HIDE_PROPERTY_LINK)
  end
  
  def make_property_transition_only_for(project, property)
    location = @browser.get_location
    navigate_to_property_management_page_for(project) unless location =~ /#{project.identifier}\/property_definitions/
    property = project.reload.find_property_definition(property, :with_hidden => true)
    unless (@browser.is_checked(transitiononly_property_definition(property)))
     @browser.with_ajax_wait do
       @browser.click(transitiononly_property_definition(property))
     end
    end
  end
  
  def make_property_not_transition_only_for(project, property)
      location = @browser.get_location
      navigate_to_property_management_page_for(project) unless location =~ /#{project.identifier}\/property_definitions/
      property = project.reload.find_property_definition(property, :with_hidden => true)
      unless (@browser.is_not_checked(transitiononly_property_definition(property)))
       @browser.with_ajax_wait do
         @browser.click(transitiononly_property_definition(property))
       end
    end
  end
  
  def check_the_card_types_required_for_a_property(project, options)
    project = project.identifier if project.respond_to? :identifier
    card_types = options[:card_types] || []
    card_types.each do |card_type|
      card_type_definition = Project.find_by_identifier(project).card_types.find_by_name(card_type)
      card_type_check_box_id = card_types_definition(card_type_definition)
      @browser.click(card_type_check_box_id) if @browser.is_not_checked(card_type_check_box_id)
    end
  end
  
  def uncheck_card_types_required_for_a_property(project, options)
    project = project.identifier if project.respond_to? :identifier
    card_types = options[:card_types] || []
    card_types.each do |card_type|
      card_type_definition = Project.find_by_identifier(project).card_types.find_by_name(card_type)
      card_type_check_box_id = card_types_definition(card_type_definition)
      @browser.click(card_type_check_box_id) if @browser.is_checked(card_type_check_box_id)
    end
  end
  
  def lock_property_via_model(project, property_name)
    property_definition = Project.find_by_identifier(project.identifier).find_property_definition_or_nil(property_name)
    property_definition.restricted = true
    property_definition.save!
    property_definition
  end
  
  def update_property_by_removing_card_type(project, property_name, *card_types)
    open_property_for_edit(project, property_name) 
    uncheck_card_types_required_for_a_property(project, :card_types => card_types)   
    click_save_property
  end
  
  def values_by_property_definition(project, properties)
    project.reload
    values_by_property_defs = Hash.new
    properties.each do |property, value| 
      property = project.find_property_definition(property, :with_hidden => true) unless property.respond_to?(:name)
      values_by_property_defs[property] = value
    end
    values_by_property_defs
  end
  
end
