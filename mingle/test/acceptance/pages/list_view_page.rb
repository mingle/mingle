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

module ListViewPage

  NOT_SET = '(not set)'

  def list_view_delete_link_id(view_name)
    view = Project.current.reload.card_list_views.find_by_name(view_name)
    "destroy-#{view.html_id}"
  end

  def assert_card_present_in_list(card)
     @browser.assert_element_present(list_view_card_id(card))
     @browser.assert_element_matches(list_view_card_id(card), /#{card.name}/)
   end

   def assert_card_not_present_in_list(card)
      @browser.assert_element_not_present(list_view_card_id(card))
      @browser.assert_element_does_not_match("cards", /#{card.name}/)
    end


  def assert_properties_set_in_bulk_edit_panel(project, properties)
    properties.each { |name, value| assert_property_set_in_bulk_edit_panel(project, name, value)  }
  end

  def assert_property_set_in_bulk_edit_panel(project, property, value)
    project = Project.find_by_identifier(project) unless project.respond_to?(:identifier)
    project.reload.with_active_project do |active_project|
      property = active_project.reload.find_property_definition(property, :with_hidden => true)
      property_type = property.attributes['type']
      if(property_type == 'EnumeratedPropertyDefinition' || property_type == 'UserPropertyDefinition' || (property_type == 'TextPropertyDefinition' && property.project_variables.size != 0))
        @browser.assert_text(droplist_link_id(property.name, "bulk"), value)
      elsif(property_type == 'DatePropertyDefinition')
        @browser.assert_text(droplist_link_id(property.name, 'bulk'), value)
      elsif(property_type == 'TextPropertyDefinition')
        @browser.assert_text(editlist_link_id(property.name, 'bulk'), value)
      elsif(property_type == 'FormulaPropertyDefinition')
        @browser.assert_text(editlist_link_id(property.name, "bulk"), value)
      elsif(property_type == 'TreeRelationshipPropertyDefinition')
        value = card_number_and_name(value) if value.respond_to?(:name)
        @browser.assert_text(droplist_link_id(property.name, "bulk"), value)
      else
        raise "Property type #{property_type} is not supported"
      end
    end
  end

  def assert_type_in_bulk_panel_set_to(card_type)
    @browser.assert_text(ListViewPageId::BULK_EDIT_CARD_TYPE_LINK, card_type)
  end

  def assert_property_present_in_bulk_edit_panel(property)
    @browser.assert_element_matches(ListViewPageId::BULK_SET_PROPERTIES_PANEL, /#{property}/)
  end

  def assert_property_not_present_in_bulk_edit_panel(property)
    @browser.assert_element_does_not_match(ListViewPageId::BULK_SET_PROPERTIES_PANEL, /#{property}/)
  end

  def assert_properties_in_order(project, property, value_order, context='edit')
    project = project.identifier if project.respond_to? :identifier
    property = Project.find_by_identifier(project).find_property_definition_or_nil(property) unless property.respond_to?(:name)
    @browser.click  droplist_link_id(property, context)
    comparing_pairs = Hash.new
    value_order.each_with_index do |value, i|
      comparing_pairs[value] = value_order[i.next] if value != value_order.last
    end
    comparing_pairs.each do |key, value|
      @browser.assert_ordered droplist_option_id(property, key, context), droplist_option_id(property, value, context)
    end
  end

  def assert_properties_not_in_set_properties_panel(properties)
    properties.each do |property_name, property_value|
      @browser.assert_text droplist_link_id(property_name, "bulk"), NOT_SET
    end
  end

  def assert_inline_enum_value_add_present_on_bulk_edit_properties_for(project, property)
    navigate_to_card_list_for(project)
    select_all
    click_edit_properties_button
    assert_inline_enum_value_add_present_for(property, "bulk")
  end

  def assert_property_not_editable_in_bulk_edit_properties_panel(project, property)
    assert_property_not_editable_in('bulk', project, property)
  end

  def assert_bulk_set_properties_button_enabled
    assert_equal 'false', @browser.get_eval("selenium.browserbot.getCurrentWindow().$('bulk-set-properties-button').hasClassName('tab-disabled')")
  end

  def assert_bulk_set_properties_button_disabled
    assert_equal 'true', @browser.get_eval("selenium.browserbot.getCurrentWindow().$('bulk-set-properties-button').hasClassName('tab-disabled')")
  end

  def assert_bulk_set_properties_panel_visible
    @browser.assert_visible ListViewPageId::BULK_SET_PROPERTIES_PANEL
  end

  def assert_bulk_set_properties_panel_not_visible
    @browser.assert_not_visible ListViewPageId::BULK_SET_PROPERTIES_PANEL
  end

  def assert_bulk_set_properties_panel_present
    @browser.assert_element_present(ListViewPageId::BULK_SET_PROPERTIES_PANEL)
  end

  def assert_bulk_set_properties_panel_not_present
    @browser.assert_element_not_present(ListViewPageId::BULK_SET_PROPERTIES_PANEL)
  end

  def assert_bulk_delete_button_enabled
    assert_enabled(ListViewPageId::BULK_DELETE_ID)
  end

  def assert_bulk_delete_button_disabled
    assert_disabled(ListViewPageId::BULK_DELETE_ID)
  end

  def assert_property_have_values_in_bulk_edit_action_bar(project, property_name, property_value)
    property = project.reload.find_property_definition(property_name)
    @browser.click(bulk_edit_property_drop_link(property))
    @browser.assert_element_present(bulk_property_option(property,property_value))
  end

  def assert_property_does_not_have_values_in_bulk_edit_action_bar(project, property_name, property_value)
    property = project.reload.find_property_definition(property_name)
    @browser.click(bulk_edit_property_drop_link(property))
    @browser.assert_element_not_present(bulk_property_option(property,property_value))
  end

  def assert_value_not_present_in_property_drop_down_on_bulk_edit_panel(property,values)
    values.each do |value|
      locator = droplist_option_id(property, value, "bulk")
      @browser.is_element_present(locator) && @browser.assert_not_visible(locator)
    end
  end

  def assert_value_present_in_property_drop_down_on_bulk_edit_panel(property,values)
      values.each do |value|
        @browser.assert_visible(droplist_option_id(property,value,'bulk'))
      end
  end

  def assert_card_created_by_user(card, username)
    @browser.assert_element_matches(list_view_card_id(card), /#{username}/)
  end

  def assert_cards_not_present_in_list(*cards)
    cards.each do |card|
      assert_card_not_present_in_list(card)
    end
  end

  def assert_cards_present_in_list(*cards)
    cards.each do |card|
      assert_card_present_in_list(card)
    end
  end

  def assert_card_checked(card)
    @browser.assert_checked(get_card_checkbox_id(card))
  end

  def assert_card_not_checked(card)
    @browser.assert_not_checked(get_card_checkbox_id(card))
  end

  def assert_column_present_for(*properties)
    properties.each {|property| @browser.assert_element_matches(css_locator(".table-column-header"), /#{property}/)}
  end

  def assert_column_not_present_for(*properties)
    properties.each {|property| @browser.assert_element_does_not_match(css_locator(".table-column-header"), /#{property}/)}
  end

  def assert_transition_drop_down_enabled
    assert_element_doesnt_have_css_class(ListViewPageId::BULK_TRANSITION_ID, 'disabled')
  end

  def assert_transition_drop_down_disabled
    assert_element_has_css_class(ListViewPageId::BULK_TRANSITION_ID, "disabled")
  end

  def assert_no_bulk_transitions_available
    open_bulk_transitions
    @browser.assert_visible(class_locator('no_transition_message'))
  end

  def assert_bulk_transition_available(transition)
    open_bulk_transitions
    @browser.assert_visible(css_locator("##{transition.html_id}"))
  end

  def assert_bulk_transition_not_available(transition)
    open_bulk_transitions
    @browser.assert_element_not_present(css_locator("##{transition.html_id}"))
  end

  def assert_properties_present_on_add_remove_column_dropdown(project, property_defs)
    @browser.click ListViewPageId::ADD_OR_REMOVE_COLUMNS_LINK
    property_defs.each do |property_def|
      @browser.assert_element_present "toggle_column_#{project.reload.find_property_definition(property_def).html_id}"
    end
    @browser.click ListViewPageId::ADD_OR_REMOVE_COLUMNS_LINK
  end

  def assert_created_by_modified_by_present_on_add_remove_column_dropdown
    @browser.click ListViewPageId::ADD_OR_REMOVE_COLUMNS_LINK
    @browser.assert_element_present("toggle_column_userpropertydefinition_Modified by")
    @browser.assert_element_present("toggle_column_userpropertydefinition_Created by")
    @browser.click ListViewPageId::ADD_OR_REMOVE_COLUMNS_LINK
  end

  def assert_properties_not_present_on_add_remove_column_dropdown(project, property_defs)
    @browser.click ListViewPageId::ADD_OR_REMOVE_COLUMNS_LINK
    property_defs.each do |property_def|
      @browser.assert_element_not_present "toggle_column_#{project.reload.find_property_definition(property_def, :with_hidden => true).html_id}"
    end
    @browser.click ListViewPageId::ADD_OR_REMOVE_COLUMNS_LINK
  end

  def assert_properties_order_in_bulk_edit(project, *properties)
    project = project.identifier if project.respond_to? :identifier
    next_property = Hash.new
    properties.each_with_index do |property, index|
      if (property != properties.last)
        property = Project.find_by_identifier(project).find_property_definition(property, :with_hidden => true)
        next_property[index] = Project.find_by_identifier(project).find_property_definition_or_nil(properties[index.next], :with_hidden => true) if property != properties.last
        assert_ordered("bulk_enumeratedpropertydefinition_#{property.id}_span", "bulk_enumeratedpropertydefinition_#{next_property[index].id}_span") unless property == properties.last
      end
    end
  end

  def assert_properties_ordered_in_add_remove_columns_in_card_list(project, *properties)
    @browser.click(ListViewPageId::COLUMN_SELECTOR_LINK)
    project = project.identifier if project.respond_to? :identifier
    comma_joined_values = @browser.get_eval(%{
      this.browserbot.getCurrentWindow().document.getElementById('column-selector').select('input[type=checkbox][name=columns]').pluck('id').join(',');
    })
    properties_actual_order = comma_joined_values.split(',').select{|value|value.include?('propertydefinition')}.compact
    properties.each_with_index do |property, index|
      owner_project = Project.find_by_identifier(project)
      property_def = owner_project.find_property_definition(property, :with_hidden => true)

      expected_property_id = properties_actual_order[index].gsub(/[^\d]/, '')

      expected_property = owner_project.all_property_definitions.find_by_id(expected_property_id)
      assert_equal(property_def.name, expected_property.name)
    end
  end

  # this will work for both list and hierarchy views
  def assert_stale_indicator_for_column(aggregate_property_definition, card)
    @browser.assert_element_matches("#{aggregate_property_definition.html_id}-cell-for-card-#{card.number}",/\* \d+/)
  end

  def assert_card_list_property_value(property_definition, card, value)
    @browser.assert_element_text("#{property_definition.html_id}-cell-for-card-#{card.number}", value)
  end

  def assert_bulk_edit_action_not_present_on_list_view
    @browser.assert_element_not_present(ListViewPageId::BULK_OPTIONS_ID)
  end

  def assert_print_link_to_this_page_and_add_remove_columns_links_present_for_list_view
    @browser.assert_element_present(class_locator('print'))
    assert_link_to_this_page_link_present
    @browser.assert_element_present(ListViewPageId::COLUMN_SELECTOR_LINK)
  end

   def assert_can_add_and_remove_column_for(project, property)
     add_column_for(project, [property])
     assert_column_present_for(property)
     remove_column_for(project, [property])
     assert_column_not_present_for(property)
   end

   def assert_can_add_and_remove_columns_for(project, properties)
     properties.each do |property|
      assert_can_add_and_remove_column_for(project,property)
     end
   end

   def assert_select_all_columns_checked
     @browser.assert_checked(ListViewPageId::SELECT_ALL_LANES_ID)
   end

   def assert_select_all_columns_not_checked
     @browser.assert_not_checked(ListViewPageId::SELECT_ALL_LANES_ID)
   end

   def assert_columns_selected(project,columns)
     columns.each do |column|
       @browser.assert_checked("toggle_column_#{project.reload.find_property_definition(column).html_id}")
     end
   end

   def assert_columns_ordered(*columns)
     names = []
     n=columns.length+1
     2.upto(n) do |i|
       names[i] = @browser.get_text(class_locator('column-header-link',i))
     end
     names.slice!(0..1)
     assert_equal(columns,names)
   end

   def assert_transition_ordered_in_bulk_edit(transition1, transition2, transition3)
     open_bulk_transitions
     assert_ordered(transition1.html_id, transition2.html_id)
     assert_ordered(transition2.html_id, transition3.html_id)
   end

   def assert_bulk_action_for_transitions_applied_for_selected_card(transtion_name, card_number)
     @browser.wait_for_element_visible 'notice'
     @browser.assert_element_matches('notice', /(<b>)?#{transtion_name}(<\/b>)? successfully applied to card ##{card_number}/)
   end

   def assert_bulk_action_for_transitions_applied_for_selected_cards(transition_name, *card_number)
     @browser.wait_for_element_visible 'notice'
     card_numbers = card_number.join(', #')
     @browser.assert_element_matches('notice', /(<b>)?#{transition_name}(<\/b>)? successfully applied to cards ##{card_numbers}/)
   end

   def assert_bulk_transition_message_on_transition_list_for(transition, message)
     actual_message = @browser.get_eval(%{this.browserbot.getCurrentWindow().$('transition-#{transition.id}').select('.transition-comments')[0].innerHTML.unescapeHTML()})
     assert_equal(message, actual_message.trim)
   end

   def assert_property_tooltip_on_bulk_edit_panel(property_name)
     property = @project.all_property_definitions.find_by_name(property_name)
     property_tooltip = property_name + ': ' + property.description
     @browser.assert_element_present("css=##{droplist_part_id(property_name, 'span', 'bulk')} span[title='#{property_tooltip}']")
   end

   def assert_card_favorites_link_present(*saved_view_names)
     saved_view_names.each do |saved_view_name|
       @browser.assert_element_present("css=.favorites a:contains('#{saved_view_name}')")
     end
   end

   def assert_card_favorites_links_not_present(project, *saved_view_names)
     saved_view_names.each do |saved_view_name|
       @browser.assert_element_not_present("css=.favorites a:contains('#{saved_view_name}')")
     end
   end

   def assert_order_of_cards_in_list_or_hierarchy_view(*cards)
     index = 2
     cards.each do |card|
       if(@browser.get_eval(%{this.browserbot.getCurrentWindow().$('cards').select('TR')[#{index}].visible()}) != 'true')
         begin
           index += 1
         end while @browser.get_eval(%{this.browserbot.getCurrentWindow().$('cards').select('TR')[#{index}].visible()}) != 'true'
       end
         actual_card = @browser.get_eval(%{this.browserbot.getCurrentWindow().$('cards').select('TR')[#{index}].id})
         assert_equal(list_view_card_id(card), actual_card)
         index += 1
     end
   end
end
