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


module ProjectHomeAction

  def open_project(project)
    project = project.identifier if project.respond_to? :identifier
    @browser.open "/projects/#{project}"
  rescue Exception => e
  end

  def search_with(text = nil)
    type_search_text(text)
    click_search_button
  end

  def search_card_with_number(card_number)
    type_search_text("##{card_number}")

    @browser.click(search_button)
    @browser.wait_for_card_popup(card_number)
  end

  def click_search_button
    @browser.click_and_wait(search_button)
  end

  def type_search_text(text)
    @browser.type(search_text_box, text)
  end


  def click_source_tab
      @browser.wait_for_element_visible tab_link_id('Source')
      click_tab('Source')
  end

  def click_tab(tab)
    tab = tab.name if tab.respond_to? :name
    @browser.click_and_wait(tab_link_id(tab))
    @browser.wait_for_all_ajax_finished
  end

  def reset_view
    @browser.click_and_wait(ProjectHomePageId::RESET_TO_DEFAULT_TAB)
  end

  def reset_view_if_needed
    reset_view if @browser.is_element_present(ProjectHomePageId::RESET_TO_DEFAULT_TAB)
  end

  def reset_all_filters_return_to_all_tab
    click_all_tab
    reset_view_if_needed
  end

  def click_all_tab
    click_tab('All')
  end

  def add_card_via_quick_add(name, options={})
    open_add_card_via_quick_add
    submit_card_name_and_type(name, options)
  end

  def click_add_with_detail_button
    @browser.click_and_wait ProjectHomePageId::QUICK_ADD_MORE_DETAIL_ID
    wait_for_wysiwyg_editor_ready
  end

  def open_add_card_via_quick_add
    @browser.with_ajax_wait{@browser.click(ProjectHomePageId::ADD_CARD_LINK)}
    wait_for_wysiwyg_editor_ready
  end

  def submit_card_name_and_type(name, options={})
    set_quick_add_card_type_to(options[:type]) if options[:type]
    type_card_name(name)
    submit_quick_add_card(options)
    @browser.wait_for_element_not_present("css=.lightbox_actions .progress")
    card = find_card_by_name(name)
    return card.number
  end

  def add_card_with_detail_via_quick_add(name='', options={})
    open_add_card_via_quick_add
    set_quick_add_card_type_to(options[:type]) if options[:type]
    type_card_name(name)
  end

  def set_quick_add_card_type_to(type)
    @browser.wait_for_element_visible(QuickAddCardPageId::CARD_TYPE_VALUE_SELECTOR)
    @browser.click(QuickAddCardPageId::CARD_TYPE_VALUE_SELECTOR)
    @browser.with_ajax_wait do
      @browser.click([QuickAddCardPageId::CARD_TYPE_NAME_OPTION_PREFIX, type].join("_"))
    end
  end

  def type_card_name(name)
    @browser.with_ajax_wait{@browser.type(ProjectHomePageId::QUICK_ADD_CARD_NAME, name)}
    assert_equal name.trim, @browser.get_value(ProjectHomePageId::QUICK_ADD_CARD_NAME)
  end

  def submit_quick_add_card(options={:wait => false})
    locator = "css=#add_card_popup input[value='Add']"
    @browser.wait_for_element_present(locator)

    @browser.with_ajax_wait do
      if options[:wait]
        @browser.click_and_wait locator
      else
        @browser.click locator
      end
    end
  end

  def create_new_card(project, orginal_attributes)
    attributes = orginal_attributes.clone

    name = attributes.delete(:name) || 'Card name'
    description = attributes.delete(:description) || ''
    attachments = attributes.delete(:attachments) || []

    click_all_tab
    add_card_with_detail_via_quick_add(name)
    type_card_description(description)
    set_properties_in_card_edit attributes
    save_card
    card_list_location = @browser.get_location
    card = find_card_by_name(name.trim)
    click_card_on_list(card.number)
    attachments.each do |file|
      card.attach_files(sample_attachment(file))
    end
    card.reload.save!
    @browser.open card_list_location
    card.number
  end

  def prepare_new_card(name='')
    add_card_with_detail_via_quick_add(name)
  end

  def add_new_card(name='', options={})
    add_card_with_detail_via_quick_add(name, options)
    save_card
    tries = 0
    card = find_card_by_name(name)
    while tries < 3 && card.nil? do
      card = find_card_by_name(name)
      sleep(1)
    end
    card.number
  end

  def cancel_quick_add_card_creation
    @browser.with_ajax_wait{@browser.click(ProjectHomePageId::DISMISS_LIGHTBOX_BUTTON_ID)}
  end

  def open_card_selector_for_property_on_quick_add_lightbox(property)
    open_card_selector_for_property(property, '')
  end

  def set_properties_on_quick_add_card(property_values)
    property_values.each {|prop, value| set_managed_text_prop_on_quick_add_card(prop, value)}
  end

  def set_managed_text_prop_on_quick_add_card(prop_name, prop_value)
    property = @project.all_property_definitions.find_by_name(prop_name)

    with_ajax_wait { @browser.click(property_value_widget(prop_name))}
    with_ajax_wait { @browser.click(droplist_option_id(prop_name, prop_value))}
  end

  def set_unmanaged_propertes_on_quick_add_card(project, property_and_values)
    property_and_values.each {|prop_name, prop_value| set_unmanaged_property_on_quick_add_card(project, prop_name, prop_value)}
  end

  def set_unmanaged_property_on_quick_add_card(project, property_name, property_value)
    property = @project.all_property_definitions.find_by_name(property_name)
    @browser.with_ajax_wait {add_new_value_to_property_on_card(project, property_name, property_value)}
  end

  def extract_card_number
    if @browser.is_element_present('notice')
      success_message = @browser.get_text 'notice'
      success_message =~ /(Card #)(\d+)( was successfully created)/
      $2
    else
      nil
    end
  end

  def click_to_reset_current_tab
    @browser.click(ProjectHomePageId::RESET_TO_DEFAULT_TAB)
    @browser.wait_for_page_to_load
  end

  def click_history_tab
    @browser.click_and_wait(ProjectHomePageId::HISTORY_LINK)
  end

  def open_card_via_card_link_in_message
    @browser.click_and_wait(open_card_link())
  end

  def find_card_by_name(name)
    Card.find_by_name(name)
  end
end
