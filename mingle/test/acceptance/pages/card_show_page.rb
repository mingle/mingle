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

module CardShowPage


  NOT_SET = '(not set)'

  WARNING_OF_VIEWING_OLD_CARD_CONTENT = "This card has changed since you opened it for viewing. The latest version was opened for editing. You can continue to edit this content, go back to the previous card view or view the latest version."

  def card_selector_result_locator(result_type, card_number)
    "css=#card_selector_#{result_type}_results .card_result[card_number=#{card_number}]"
  end

  def droplist_select_card_action(dropdown_id)
    "css=##{dropdown_id} .droplist-action-option"
  end

  def assert_warning_message_of_expired_card_content_present
    @browser.assert_text_present(WARNING_OF_VIEWING_OLD_CARD_CONTENT)
  end

  def assert_warning_message_of_expired_card_content_not_present
    @browser.assert_text_not_present(WARNING_OF_VIEWING_OLD_CARD_CONTENT)
  end

  def assert_properties_set_on_card_show(properties, options={})
    properties.each { |name, value| assert_property_set_on_card_show(name, value) }
  end

  def assert_history_for(versioned_type, identifier)
    load_card_history
    HistoryAssertion.new(@browser, versioned_type, identifier)
  end

  def assert_card_name_in_show(name)
    @browser.assert_element_matches('card-short-description', /#{name}/)
  end

  def assert_card_location_in_card_show(project, card)
    @browser.assert_location("/projects/#{project.identifier}/cards/#{card.number}")
  end

  def assert_card_name_not_in_show(name)
    @browser.assert_element_does_not_match('card-short-description', /#{name}/)
  end

  def assert_card_description_in_show(description)
    @browser.assert_element_matches('card-description', /#{description}/)
  end

  def assert_card_description_in_show_does_not_match(description)
    @browser.assert_element_does_not_match('card-description', /#{description}/)
  end

  def user_should_see_the_value_on_card_preview(property_value)
    @browser.assert_text_present_in("card-preview", property_value)
  end

  def assert_context_text(options)
    current_card_position = options[:this_is]
    total_cards_in_context = options[:of]
    @browser.assert_text_present("Card #{current_card_position} of #{total_cards_in_context}")
  end

  def assert_mouse_over_message_for_card_context(message)
    message = "Current cards: #{message}"
    assert_equal(message, @browser.get_eval("#{class_locator('text-light', 0)}.title"))
  end

  def assert_card_context_present
    @browser.assert_element_present('list-navigation')
  end

  def assert_card_context_not_present
    @browser.assert_element_not_present('list-navigation')
  end

  def assert_card_comment_not_visible
    @browser.assert_not_visible('current-discussion')
  end

  def show_murmurs_checkbox_is_checked
    assert_equal(@browser.get_eval("this.browserbot.getCurrentWindow().$('show-murmurs-preference').checked"), 'true')
  end

  def show_murmurs_checkbox_is_unchecked
    assert_equal(@browser.get_eval("this.browserbot.getCurrentWindow().$('show-murmurs-preference').checked"), 'false')
  end

  def assert_add_comment_button_not_visible
    @browser.assert_not_visible('add_comment')
  end

  def assert_create_children_link_hover_text_for_tree(tree, hover_text)
    actual_hover_text = @browser.get_eval("this.browserbot.getCurrentWindow().document.getElementById('show-add-children-link-#{tree.id}').title")
    assert_equal(hover_text, actual_hover_text)
  end

  # page_type is 'show' or 'edit
  def assert_card_belongs_to_tree_message_present_for(tree, page_type = 'show')
    @browser.assert_element_matches("#{page_type}_tree_message_treeconfiguration_#{tree.id}", /\(This card belongs to this tree\.\)/)
  end

  def assert_card_available_to_tree_message_present_for(tree, page_type = 'show')
    @browser.assert_element_matches("#{page_type}_tree_message_treeconfiguration_#{tree.id}", /\(This card is available to this tree\.\)/)
  end

  def assert_no_tree_availability_message_present_for(tree, page_type = 'show')
    @browser.assert_element_not_present("#{page_type}_tree_message_treeconfiguration_#{tree.id}")
  end

  def assert_previous_link_is_present
    @browser.assert_element_present('previous-link')
  end

  def assert_next_link_is_present
    @browser.assert_element_present('next-link')
  end

  def assert_remove_card_from_tree_link_is_visible(tree)
    @browser.assert_visible("remove_from_tree_#{tree.id}")
  end

  def assert_remove_card_from_tree_link_is_not_present(tree)
    @browser.assert_element_not_present("remove_from_tree_#{tree.id}")
  end

  def assert_card_belongs_to_tree_on_card_show_for(tree)
    @browser.assert_element_matches("show_tree_message_treeconfiguration_#{tree.id}", /(This card belongs to this tree.)/)
  end

  def assert_card_is_available_to_tree_on_card_show_for(tree)
    @browser.assert_element_matches("show_tree_message_treeconfiguration_#{tree.id}", /(This card is available to this tree.)/)
  end

  def assert_card_present_in_card_selector_filter_result(card_number)
    @browser.assert_element_present(card_selector_result_locator(:filter, card_number))
  end

  def assert_card_present_in_card_selector_search_result(card_number)
    @browser.assert_element_present(card_selector_result_locator(:search, card_number))
  end

  def assert_card_type_not_editable_on_card_show
    @browser.assert_element_not_present(card_type_dropdown_id("show"))
  end

  def assert_properties_not_set_on_card_show(*properties)
    properties.each { |name| assert_property_not_set_on_card_show(name)  }
  end

  def assert_property_not_set_on_card_show(property)
    assert_property_set_on_card_show(property, NOT_SET)
  end

  def assert_property_set_to_card_on_card_show(property, card)
    assert_property_set_on_card_show(property, card.number_and_name)
  end

  def assert_value_not_present_for(property, value)
    @browser.click(property_editor_id(property))
    @browser.assert_element_not_present(droplist_option_id(property, value))
  end

  def assert_values_ordered_in_card_show_property_drop_down(project, property, ordered_values)
    @browser.click(droplist_link_id(property, 'show'))
    ordered_values[0..-2].each_with_index do |value, index|
      next_option_id = droplist_option_id(property, ordered_values[index+1])
      @browser.assert_ordered(droplist_option_id(property, value), next_option_id)
    end
  end

  def assert_property_not_present_on_card_show(property)
    @browser.assert_element_not_present_or_visible(property_editor_property_name_id(property, "show"))
  end

  def assert_property_present_on_card_show(property)
    property = property.name if property.respond_to? :name
    @browser.assert_element_matches('show-properties-container', /#{property}/)
  end

  def assert_property_not_present_on_card(project, card, property)
    location = @browser.get_location
    project = project.identifier if project.respond_to? :identifier
    card_number = card.number if card.respond_to?(:number)
    open_card(project, card_number) unless location =~ /#{project}\/cards\/card_number/
    @browser.assert_element_does_not_match('show-properties-container', /#{property}/)
  end

  def assert_inline_enum_value_add_not_present_on_bulk_edit_properties_for(project, property)
    navigate_to_card_list_for(project)
    select_all
    click_edit_properties_button
    assert_inline_enum_value_add_not_present_for(property, "bulk")
  end

  def assert_properties_not_editable_on_card_show(properties)
    properties.each do |property|
      assert_property_not_editable(property)
    end
  end

  def assert_delete_link_present
    @browser.assert_element_present("link=Delete")
  end

  def assert_delete_link_not_present
    @browser.assert_element_not_present("link=Delete")
  end

  def assert_edit_wysiwyg_link_present
    @browser.assert_element_present(CardShowPageId::EDIT_LINK_ID)
  end

  def assert_delete_link_on_card_show_disabled(project, card_name)
    project = project.identifier if project.respond_to? :identifier
    card = Project.find_by_identifier(project).cards.find_by_name(card_name)
    assert_link_not_present("/projects/#{project}/cards/#{card.number}/destroy")
  end

  def assert_create_new_children_link_present_for(tree)
    @browser.assert_element_present("show-add-children-link-#{tree.id}")
  end

  def assert_create_new_children_link_not_present_for(tree)
    @browser.assert_element_not_present("show-add-children-link-#{tree.id}")
  end

  def assert_view_tree_link_present(tree)
    @browser.assert_element_present "css=.tree_group a[title='View tree: #{tree.name}']"
  end

  def assert_view_tree_link_not_present(tree)
    @browser.assert_element_not_present "css=.tree_group a[title='View tree: #{tree.name}']"
  end

  def assert_card_belongs_to_or_not_message_on_card_show_for(tree, message)
    @browser.assert_text("show_tree_message_treeconfiguration_#{tree.id}", message)
  end

  def assert_tree_position_on_card_default(tree_name, position)
    actural_tree = @browser.get_eval("this.browserbot.getCurrentWindow().$$('.tree_properties_widget')[#{position}].down().innerHTML.unescapeHTML()")
    assert_equal_ignore_cr("from #{tree_name} tree", actural_tree)
  end

  def assert_value_present_in_card_show_property_drop_down(property_name, value)
    @browser.assert_visible droplist_link_id(property_name, 'show')
    @browser.click droplist_link_id(property_name, 'show')
    @browser.assert_text_present_in(droplist_link_id(property_name, 'show'), value)
  end

  def assert_free_text_does_not_have_drop_down(property_name, context)
    if context == 'show'
      @browser.click droplist_link_id(property_name, 'show')
      @browser.assert_element_not_present droplist_dropdown_id(property_name, "show")
    else
      # todo #14979:
      # push context transition_lightbox to lower level
      if context == 'transition_lightbox'
        @browser.assert_element_not_present lightbox_requires_droplist_link_id(property_name)
      else
        @browser.assert_element_not_present droplist_link_id(property_name, 'show')
      end
    end
  end

  def assert_value_present_in_property_drop_down_on_card_show(property,values)
    values.each do |value|
      @browser.assert_visible(droplist_option_id(property,value,'show'))
    end
  end

  def assert_value_not_present_in_property_drop_down_on_card_show(property,values)
    values.each do |value|
      locator = droplist_option_id(property, value, 'show')
      @browser.is_element_present(locator) && @browser.assert_not_visible(locator)
    end
  end

  def assert_toggle_hidden_properties_checkbox_unchecked
    @browser.assert_not_checked('toggle_hidden_properties')
  end

  def assert_toggle_hidden_properties_checkbox_checked
    @browser.assert_checked('toggle_hidden_properties')
  end

  def assert_toggle_hidden_properties_checkbox_present
    @browser.assert_element_present('toggle_hidden_properties')
  end

  def assert_toggle_hidden_properties_checkbox_not_present
    @browser.assert_element_not_present('toggle_hidden_properties')
  end

  def assert_card_navigation_icon_displayed_for_readonly_property(property_name)
    id = @project.all_property_definitions.find_by_name(property_name).html_id
    @browser.assert_visible "css=##{id} + .card-relationship-link"
  end

  def assert_card_navigation_icon_not_displayed_for_readonly_property(property_name)
    id = @project.all_property_definitions.find_by_name(property_name).html_id
    @browser.assert_not_visible "css=##{id} + .card-relationship-link"
  end

  def assert_card_navigation_icon_displayed_for_property(property_name)
    id = @project.all_property_definitions.find_by_name(property_name).html_id
    @browser.assert_visible "css=##{id} ~ .card-relationship-link"
  end

  def assert_card_navigation_icon_not_displayed_for_property(property_name)
    id = @project.all_property_definitions.find_by_name(property_name).html_id
    @browser.assert_not_visible "css=##{id} ~ .card-relationship-link"
  end

  def assert_blank_property_value_not_allowed(property_def)
    @browser.click "#{property_def.html_id}_sets_drop_link"
    @browser.click "#{property_def.html_id}_sets_action_adding_value"
    submit_property_inline("#{property_def.html_id}_sets_inline_editor", true)
    @browser.assert_element_present("#{property_def.html_id}_sets_inline_editor")
    @browser.type "#{property_def.html_id}_sets_inline_editor", "blank value was allowed"
    submit_property_inline("#{property_def.html_id}_sets_inline_editor", true)
  end

  def assert_transition_present_on_card(transition)
    transition = transition.name if transition.respond_to?(:name)
    @browser.assert_element_present("link=#{transition}")
  end

  def assert_transition_not_present_on_card(transition)
    transition = transition.name if transition.respond_to?(:name)
    @browser.assert_element_not_present("link=#{transition}")
  end

  def assert_transition_ordered_in_card_show(*transitions)
    assert_ordered(transitions.collect {|transition| "transition_#{transition.id}"})
  end

  def assert_transition_success_message(transition_name, card_number)
    assert_notice_message("#{transition_name} successfully applied to card ##{card_number}")
  end

  def assert_transition_complete_button_enabled
    assert_enabled('complete_transition')
  end

  def assert_transition_complete_button_disabled
    assert_disabled('complete_transition')
  end

  def assert_value_present_in_property_drop_down_in_transition_lightbox(property,values)
    values.each do |value|
      @browser.assert_visible(droplist_lightbox_option_id(property,value))
    end
  end

  def assert_value_not_present_in_property_drop_down_in_transition_lightbox(property,values)
    values.each do |value|
      locator = droplist_lightbox_option_id(property, value)
      @browser.is_element_present(locator) && @browser.assert_not_visible(locator)
    end
  end

  def assert_value_for_property_in_transition_lightbox(property,value)
    @browser.assert_text(lightbox_droplist_link_id(property),value)
  end

  def assert_transition_light_box_present
    @browser.assert_element_present css_locator('.lightbox #transition_popup_div')
  end

  def assert_transition_selection_light_box_present
    @browser.assert_element_present css_locator('.lightbox')
  end

  def assert_transition_light_box_not_present
    @browser.assert_element_not_present css_locator('.lightbox #transition_popup_div')
  end

  def assert_transition_options_present_in_transition_light_box(transitions)
    transitions.each do |transition|
      @browser.assert_element_present("link=#{transition.name}")
    end
  end

  def assert_property_have_values_in_transiton_light_box(property_name, property_value)
    # @browser.click lightbox_droplist_link_id(property_name, '')
    @browser.assert_element_present(droplist_lightbox_option_id(property_name, property_value))
  end

  def assert_property_does_not_have_values_in_transiton_light_box(property_name, property_value)
    # @browser.click lightbox_droplist_link_id(property_name, '')
    @browser.assert_element_not_present(droplist_lightbox_option_id(property_name, property_value))
  end

  def assert_version_info_on_card_show(message)
    @browser.assert_element_matches('version-info', /#{message}/)
  end

  def assert_order_of_properties_on_card_show(project, *properties)
    project = project.identifier if project.respond_to? :identifier
    next_property = Hash.new
    properties.each_with_index do |property, index|
      if (property != properties.last)
        property = Project.find_by_identifier(project).find_property_definition(property, :with_hidden => true)
        next_property[index] = Project.find_by_identifier(project).find_property_definition_or_nil(properties[index.next], :with_hidden => true) if property != properties.last
        assert_ordered(property_editor_panel_id(property), property_editor_panel_id(next_property[index])) unless property == properties.last
      end
    end
  end
  alias_method :assert_order_of_properties_on_card_edit, :assert_order_of_properties_on_card_show

  def assert_property_tooltip_on_card_show(property_name)
    property = @project.all_property_definitions.find_by_name(property_name)
    assert_equal property.tooltip, get_property_tooltip(property, 'show')
  end

  def assert_property_tooltip_on_old_card_version(property_name)
    property = @project.all_property_definitions.find_by_name(property_name)
    @browser.assert_attribute_equal("#{css_locator("div#show-properties span span.property-name")}@title", property.tooltip)
  end
  alias_method :assert_property_tooltip_on_card_show_for_anon_user, :assert_property_tooltip_on_old_card_version
  alias_method :assert_property_tooltip_on_card_show_for_read_only_user, :assert_property_tooltip_on_old_card_version

  def assert_property_tooltip_on_transition_lightbox(property_name)
    property = @project.all_property_definitions.find_by_name(property_name)
    property_tooltip = property_name + ': ' + property.description
    @browser.assert_element_present("css=##{droplist_part_id(property_name, "sets_span")} span[title='#{property_tooltip}']")
  end

  def assert_on_card(project, card, url_options='')
    project = project.identifier if project.respond_to? :identifier
    @browser.assert_location("/projects/#{project}/cards/#{card.number}#{url_options}")
  end


  def assert_card_delete_confirm_light_box_present
    @browser.assert_element_present("confirm-delete-div")
  end

  def assert_card_update_successfully_message(card)
    assert_notice_message("Card ##{card.number} was successfully updated.")
  end

  def assert_card_create_successfully_message(card)
    assert_notice_message("Card ##{card.number} was successfully created.")
  end

  def assert_card_deleted_successfully_message(card)
    assert_notice_message("Card ##{card.number} deleted successfully.")
  end

  def assert_no_card_for_current_project_message(project)
    assert_info_message("There are no cards for #{project.name}")
  end

  def assert_date_property_set_to_todays_date(project, property_def_of_type_date)
    date_now = project.utc_to_local(Clock.now)
    assert_property_set_on_card_show(property_def_of_type_date, date_now.strftime('%d %b %Y'))
  end

  def assert_inline_enum_value_add_for_light_box_not_present_for(project, property_name)
    property = project.reload.find_property_definition(property_name)
    @browser.assert_element_not_present("#{property.html_id}_sets_action_adding_value")
  end

  def assert_murmur_this_comment_is_checked_on_card_show
    @browser.assert_checked("murmur-this-show")
  end

  def assert_murmur_this_comment_is_unchecked_on_card_show
    @browser.assert_not_checked("murmur-this-show")
  end

  def should_not_see_the_murmur_this_comment_checkbox_on_card_show
    @browser.assert_element_not_present("murmur-this-show")
  end

  def should_see_warning_message_the_relationship_property_will_not_be_copied(relationship_name)
    assert_info_box_light_message("Tree membership and tree relationship property value for #{relationship_name} will not be copied", :id => "confirm-copy-div")
  end


  def should_see_warning_message_the_aggregate_will_not_be_copied(aggregate_propery_name)
    assert_info_box_light_message("Aggregate property value for #{aggregate_propery_name} will not be copied.", :id => "confirm-copy-div")
  end

  def should_see_clone_card_link
    @browser.assert_element_present('link=Copy to...')
  end

  def should_not_see_clone_card_link
    @browser.assert_element_not_present('link=Copy to...')
  end

  def assert_murmur_this_transition_is_checked
    @browser.assert_checked(CardShowPageId::MURMUR_THIS_TRANSITION_CHECKBOX)
  end

  def assert_murmur_this_transition_is_not_checked
    @browser.assert_not_checked(CardShowPageId::MURMUR_THIS_TRANSITION_CHECKBOX)
  end

  def assert_checklist_items_on_card_show(incomplete_checklist_items, completed_checklist_items)
    incomplete_checklist_items.each_with_index do |incomplete_item, index|
      @browser.assert_element_matches("css=ul.items-list li:nth-child(#{index+1}) div span.item-name", /#{incomplete_item}/)
    end
    completed_checklist_items.each_with_index do |completed_item, index|
      @browser.assert_element_matches("css=ul.completed-items-list li:nth-child(#{index+1}) div span.item-name", /#{completed_item}/)
    end
  end

  private

  def show_property_span_id(property_definition)
    "show_#{property_definition.class.name.downcase}_#{property_definition.id}_span"
  end
end
