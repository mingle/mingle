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

module CardFilterPage

  def assert_property_tooltip_on_card_filter_panel(filter_number,property_name)
    property = @project.all_property_definitions.find_by_name(property_name)
    property_tooltip = property_name + ': ' + property.description
    @browser.assert_element_present("css=#cards_filter_#{filter_number}_filter_container a[title='#{property_tooltip}']")
  end

  def assert_property_tooltip_in_first_filter_widget(property_name)
    property = @project.all_property_definitions.find_by_name(property_name)
    property_tooltip = property_name + ': ' + property.description
    @browser.assert_element_present("css=##{droplist_part_id(property_name, 'span')} span[title='#{property_tooltip}']")
  end

  def assert_property_tooltip_in_second_filter_widget(property_name)
    property = @project.all_property_definitions.find_by_name(property_name)
    property_tooltip = property_name + ': ' + property.description
    @browser.assert_element_present("css=##{droplist_part_id(property_name, 'span', 'acquired')} span[title='#{property_tooltip}']")
  end

  def assert_properties_in_widget(properties)
    properties.each do |property_name, property_value|
      @browser.assert_text droplist_link_id(property_name), property_value
    end
  end

  def assert_properties_not_in_widget(properties)
    properties.each do |property_name, property_value|
      @browser.assert_text droplist_link_id(property_name), SideBarPanelPageId::NOT_SET
    end
  end

  def assert_properties_present_on_card_list_filter(properties)
    card_type = properties.delete(:type)
    if card_type
      assert_equal 'type', @browser.get_text("cards_filter_0_properties_drop_link").downcase
      @browser.assert_text "cards_filter_0_values_drop_link", card_type
    end
    properties.each_with_index do |property_name_value_pair, index|
      expected_property_name, expected_property_value = property_name_value_pair
      assert_equal expected_property_name.to_s.downcase, @browser.get_text("cards_filter_#{index + 1}_properties_drop_link").downcase
      @browser.assert_text "cards_filter_#{index + 1}_values_drop_link", expected_property_value
    end
  end

  def assert_filter_set_for(filter_order_number, properties)
    properties.each do |property, value|
      assert_selected_property_for_the_filter(filter_order_number, property)
      assert_selected_value_for_the_filter(filter_order_number, value)
    end
  end

  def assert_mql_filter(mql)
    assert_include mql, @browser.get_inner_html(SideBarPanelPageId::FILTER_MQL_ID)
  end

  def assert_raw_mql_filter(mql)
    @browser.assert_raw_text_present(SideBarPanelPageId::FILTER_MQL_ID, mql)
  end

  def assert_property_not_present_on_card_list_filter(property)
    @browser.assert_element_does_not_match(SideBarPanelPageId::FILTER_WIDGET, /#{property}/)
    @browser.assert_element_does_not_match(SideBarPanelPageId::NEW_FILTER_BUTTON, /#{property}/)
  end

  def assert_selected_value_for_the_filter(filter_order_number, value)
    @browser.assert_text(cards_filter_values_drop_link(filter_order_number), value)
  end

  def assert_value_not_selected_for_the_filter(filter_order_number, value)
    @browser.assert_element_does_not_match(cards_filter_values_drop_link(filter_order_number), /#{value}/)
  end

  def assert_selected_property_for_the_filter(filter_order_number, property_selected)
    @browser.assert_text(cards_filter_properties_drop_link(filter_order_number), property_selected) unless filter_order_number == 0
  end

  def assert_type_present_with_default_selected_as_any
    @browser.assert_element_present('cards_filter_0_properties_text')
    assert_selected_value_for_the_filter(0, '(any)')
  end

  def assert_filter_cannot_be_deleted(filter_order_number)
    @browser.assert_element_not_present(remove_filter(filter_order_number))
  end

  def assert_filter_can_be_deleted(filter_order_number)
    @browser.assert_element_present(remove_filter(filter_order_number))
  end

  def assert_filter_value_present_on(filter_order_number, options = {})
    property_values = options[:property_values] || ['(any)']
    open_filter_value_list(filter_order_number)
    if options[:search_term]
      @browser.type_in_property_search_filter("css=##{cards_filter_drop_down(filter_order_number)} .dropdown-options-filter", options[:search_term])
    end
    property_values.each do |value|
      @browser.assert_element_present(card_filter_value_option(filter_order_number,value))
    end
  end

  def assert_filter_value_not_present_on(filter_order_number, options = {})
    property_values = options[:property_values] || '(any)'
    open_filter_value_list(filter_order_number)
    property_values.each do |value|
      @browser.assert_element_not_present(card_filter_value_option(filter_order_number,value))
    end
  end

  def assert_filter_property_present_on(filter_order_number, options = {})
    properties = options[:properties]
    open_filter_property_list(filter_order_number)
    properties.each do |property|
      @browser.assert_element_present(cards_filter_properties_option(filter_order_number,property))
    end
  end

  def assert_filter_property_not_present_on(filter_order_number, options = {})
    properties = options[:properties]
    open_filter_property_list(filter_order_number)
    properties.each do |property|
      @browser.assert_element_not_present(cards_filter_properties_option(filter_order_number,property))
    end
  end

  def assert_filter_operator_set_to(filter_order_number, operator)
    @browser.assert_text(cards_filter_operators_drop_link(filter_order_number), operator)
  end

  def assert_filter_operator_present(filter_order_number, operators = {})
    open_filter_operator_list(filter_order_number)
    operators[:operators].each do |operator|
      @browser.assert_element_present(cards_filter_operators_option(filter_order_number,operator))
    end
  end

  def assert_filter_operator_not_present(filter_order_number, operators = {})
    open_filter_operator_list(filter_order_number)
    operators[:operators].each do |operator|
      @browser.assert_element_not_present(cards_filter_operators_option(filter_order_number,operator))
    end
  end

  def open_filter_property_list(filter_order_number)
    ensure_sidebar_open
    unless @browser.is_visible(cards_filter_properties_drop_down(filter_order_number))
      @browser.click(cards_filter_properties_drop_link(filter_order_number))
      @browser.wait_for_element_visible(cards_filter_properties_drop_down(filter_order_number))
    end
  end

  def open_filter_value_list(filter_order_number)
    ensure_sidebar_open
    unless @browser.is_element_present(cards_filter_drop_down(filter_order_number)) && @browser.is_visible(cards_filter_drop_down(filter_order_number))
      @browser.click(cards_filter_values_drop_link(filter_order_number))
      @browser.wait_for_element_visible(cards_filter_drop_down(filter_order_number))
    end
  end

  def open_filter_operator_list(filter_order_number)
    ensure_sidebar_open
    unless @browser.is_visible(cards_filter_operators_drop_down(filter_order_number))
      @browser.click(cards_filter_operators_drop_link(filter_order_number))
      @browser.wait_for_element_visible(cards_filter_operators_drop_down(filter_order_number))
    end
  end

  def assert_filter_not_present_for(filter_order_number)
    @browser.assert_element_not_present(cards_filter_values_drop_link(filter_order_number))
  end

  def assert_filter_present_for(filter_order_number)
    @browser.assert_element_present(cards_filter_values_drop_link(filter_order_number))
  end

  def assert_reset_to_tab_default_link_present
    @browser.assert_element_present(SideBarPanelPageId::RESET_TAB_DEFAULTS_ID)
  end

  def assert_reset_to_tab_default_link_not_present
    @browser.assert_element_not_present(SideBarPanelPageId::RESET_TAB_DEFAULTS_ID)
  end

  def assert_properties_ordered_in_filter_property_dropdown(filter_number, *properties)
    @browser.click(cards_filter_properties_drop_link(filter_number))
    properties.each_with_index do |property, index|
      assert_ordered(cards_filter_properties_option(filter_number,property), cards_filter_properties_option(filter_number,properties[index + 1])) unless property == properties.last
    end
    @browser.click(cards_filter_properties_drop_link(filter_number))
  end

  def assert_filter_properties_options_ordered(filter_order_number, *properties)
    open_filter_property_list(filter_order_number)
    properties.each_with_index do |property, index|
      property_first =  cards_filter_properties_option(filter_order_number,property)
      property_next = cards_filter_properties_option(filter_order_number,properties[index + 1])
      @browser.assert_ordered(property_first, property_next) unless property == properties.last
    end
  end

  def assert_enum_values_are_ordered_according_to_the_order_set_in_management_page(filter_number, *enum_values)
    @browser.click cards_filter_values_drop_link(filter_number)
    enum_values.each_with_index do |enum, index|
      assert_ordered(card_filter_value_option(filter_number,enum), card_filter_value_option(filter_number, enum_values[index + 1])) unless enum == enum_values.last
    end
  end

  def assert_mql_filter_is_empty
    assert_mql_filter('Click here to input MQL')
  end

  def assert_apply_button_displayed_on_interactive_filter
    @browser.assert_visible(class_locator(SideBarPanelPageId::RESUBMIT_BUTTON, 0))
  end

  def assert_apply_button_displayed_on_mql_filter
    @browser.assert_visible(class_locator(SideBarPanelPageId::RESUBMIT_BUTTON, 1))
  end

  def assert_apply_button_not_displayed_on_interactive_filter
    @browser.assert_not_visible(class_locator(SideBarPanelPageId::RESUBMIT_BUTTON, 0))
  end

  def assert_apply_button_not_displayed_on_mql_filter
    @browser.assert_not_visible(class_locator(SideBarPanelPageId::RESUBMIT_BUTTON, 1))
  end

  def assert_mql_window_content(text)
    @browser.assert_value(SideBarPanelPageId::MQL_FILTER_EDIT_WINDOW, text)
  end

  def assert_mql_window_empty
    @browser.assert_value(SideBarPanelPageId::MQL_FILTER_EDIT_WINDOW,'')
  end

  def assert_filter_is(filter_order_number, expected_property, expected_operator, expected_value)
    assert_selected_property_for_the_filter(filter_order_number, expected_property) unless filter_order_number == 0
    assert_filter_operator_set_to(filter_order_number, expected_operator)
    assert_selected_value_for_the_filter(filter_order_number, expected_value)
  end

  def assert_tags_set(*tags)
    actual_tags = @browser.get_text("css=div.tag-list").gsub(/\s/, '').split(",")
    tags.each {|tag| assert actual_tags.include?(tag) }
  end
end


module TreeFilterPanelPage

  def assert_card_selected_in_explorer(card)
    @browser.assert_checked(checkbox_id(card.number))
  end

  def assert_card_not_selected_in_explorer(card)
    @browser.assert_not_checked(checkbox_id(card.number))
  end

  def assert_card_present_in_explorer_filter_results(card)
    @browser.assert_element_present(filter_card_child_candidate_id(card.number))
  end

  def assert_card_not_present_in_explorer_filter_results(card)
    @browser.assert_element_not_present(filter_card_child_candidate_id(card.number))
  end

  def assert_card_disabled_in_card_explorer_filter_results(card)
    assert_element_has_css_class(filter_card_child_candidate_id(card.number), 'card-child-disabled')
  end

  def assert_card_enabled_in_card_explorer_filter_results(card)
    assert_card_present_in_explorer_filter_results(card)
    assert_element_has_css_class(filter_card_child_candidate_id(card.number), 'card-child-candidate')
  end

  def assert_first_filter_cannot_be_deleted
    assert_filter_cannot_be_deleted(0)
  end

  def assert_value_present_in_filter(type, filter_position)
    open_property_values_drop_down_in_filter(filter_position)
    @browser.assert_element_present(card_filter_value_option(filter_position,type))
  end

  def assert_value_not_present_in_filter(type, filter_position)
    open_property_values_drop_down_in_filter(filter_position)
    @browser.assert_element_not_present(card_filter_value_option(filter_position,type))
  end

  def assert_explorer_results_message(message)
    @browser.assert_element_matches( TreeFilterPanelPageId::CARD_EXPLORER_SEARCH_RESULT_FOR_TREE_ID, /#{message}/)
  end

  def assert_explorer_refresh_link_is_present
    @browser.assert_element_matches(TreeFilterPanelPageId::CARD_DRAG_CANDIDATES_FROM_FILTER_ID, /Refresh/)
  end

  def assert_no_match_found_for_the_tree_for(search_string)
    search_result = @browser.get_eval(%{
      this.browserbot.getCurrentWindow().$('#{TreeFilterPanelPageId::CARD_DRAG_CANDIDATES_FROM_SEARCH_ID}').firstDescendant().innerHTML.unescapeHTML().strip()
    });
    search_string = "Your search #{search_string} did not match any cards for the current tree."
    assert(search_result.include?(search_string))
  end

  def assert_count_of_cards_should_be_in_search_result(card_count, searched_for_string)
    card_count = "Showing #{card_count} result"
    search_results = @browser.get_eval(%{
      this.browserbot.getCurrentWindow().$('#{TreeFilterPanelPageId::CARD_EXPLORER_SEARCH_RESULT_FOR_TREE_ID}').innerHTML.unescapeHTML().strip()
    });
    assert(search_results.include?(card_count), "Card count was not #{card_count} for search string #{searched_for_string}")
  end

  def assert_searched_cards_enabled_for_drag(card)
    result = @browser.get_eval(%{
      this.browserbot.getCurrentWindow().$('#{search_card_child_candidate_id(card.number)}').hasClassName('card-child card-child-candidate')
    });
    assert_equal("true", result)
  end

  def assert_searched_cards_disabled_for_drag(card)
    result = @browser.get_eval(%{
      this.browserbot.getCurrentWindow().$('#{search_card_child_candidate_id(card.number)}').hasClassName('card-child card-child-disabled')
    });
    assert_equal("true", result)
    return result
  end

  def assert_card_present_in_search_result(card)
    if(@browser.is_element_present(search_card_child_candidate_id(card.number)) != true)
      @browser.assert_element_present(search_card_child_candidate_id(card.number))
    end
  end

  def assert_card_not_present_in_search_result(card)
    @browser.assert_element_not_present(search_card_child_candidate_id(card.number))
    @browser.assert_element_not_present(search_card_child_candidate_id(card.number))
  end

  def assert_card_explorer_search_page_link_present(*page_numbers)
    page_numbers.each{|page_number| @browser.assert_element_present(search_top_page_id(page_number))}
  end

  def assert_card_explorer_search_page_link_not_present(*page_numbers)
    page_numbers.each{|page_number| @browser.assert_element_not_present(search_top_page_id(page_number))}
  end

  def assert_card_type_excluded(card_type)
    card_type_name = get_card_type_name(card_type)
    @browser.assert_checked(exclude_type_id(card_type_name))
  end

  def assert_card_type_not_excluded(card_type)
    card_type_name = get_card_type_name(card_type)
    @browser.assert_not_checked(exclude_type_id(card_type_name))
  end

  def assert_properties_present_on_card_tree_filter(card_type, filter_order_number, properties)
    properties.each_with_index do |property_name_value_pair, index|
      expected_property_name, expected_property_value = property_name_value_pair
      assert_equal expected_property_name.to_s.downcase,        @browser.get_text(filter_widget_cards_filter_property_drop_link(card_type, index)).downcase
      @browser.assert_text filter_widget_cards_filter_values_drop_link(card_type, index), expected_property_value
    end
  end

  def assert_card_tree_filter_not_present_for(card_type, filter_order_number)
    @browser.assert_element_not_present(properties_drop_link_id(card_type, filter_order_number))
  end

  def assert_filter_property_available(card_type, filter_order_number, property_name)
    @browser.assert_element_matches(properties_droplist_option(card_type, filter_order_number, property_name), /#{property_name}/)
  end

  def assert_filter_property_not_available(card_type, filter_order_number, property_name)
    @browser.assert_element_not_present(properties_droplist_option(card_type, filter_order_number, property_name))
  end

  def assert_selected_property_for_the_tree_filter(card_type, filter_order_number, expected_property)
    @browser.assert_text(card_type_filter_widget_cards_filter_properties_drop_link(card_type, filter_order_number), expected_property)
  end

  def assert_selected_value_for_the_tree_filter(card_type, filter_order_number, expected_value)
    @browser.assert_text(card_type_filter_widget_cards_filter_values_drop_link(card_type, filter_order_number), expected_value)
  end

  def assert_property_tooltip_on_tree_filter_panel(card_type_name,filter_number,property_name)
    card_type = @project.card_types.find_by_name(card_type_name)
    property = @project.all_property_definitions.find_by_name(property_name)

    if property.type == "TreeRelationshipPropertyDefinition"
      property_tooltip = property_name
    else
      property_tooltip = property_name + ': ' + property.description
    end
    @browser.assert_element_present("css=##{card_type.html_id}-filter-widget_cards_filter_#{filter_number}_properties a[title='#{property_tooltip}']")
  end

  def assert_property_tooltip_on_card_explore_panel(filter_order_number, property_name)
    property = @project.all_property_definitions.find_by_name(property_name)
    property_tooltip = property.name + ': ' + property.description
    @browser.click("css=#card_explorer_filter_widget_cards_filter_#{filter_order_number}_properties a[title='#{property_tooltip}']")
  end

  private

  def get_card_type_name(card_type)
    card_type.respond_to?(:name) ? card_type.name : card_type
  end

  def properties_prefix(card_type, filter_order_number)
    filter_widget_cards_filter_properties(card_type, filter_order_number)
  end

  def properties_drop_link_id(card_type, filter_order_number)
    "#{properties_prefix(card_type, filter_order_number)}_drop_link"
  end

  def properties_droplist_option(card_type, filter_order_number, property_name)
    "#{properties_prefix(card_type, filter_order_number)}_option_#{property_name}"
  end
end

module SideBarPanelPage
  include TreeFilterPanelPage
  include CardFilterPage

  def assert_content_on_subscription_table(subscription_type, row, column, content)
    assert_table_values(subscription_type_id(subscription_type), row, column, content)
  end

  def assert_card_subscription_present(row, card_number)
    assert_table_values(SideBarPanelPageId::CARD_SUBSCRIPTIONS, "#{row}", 1, "##{card_number}")
  end

  def assert_page_subscription_present(row, page_name)
    assert_table_values(SideBarPanelPageId::PAGE_SUBSCRIPTIONS, "#{row}", 1, "#{page_name}")
  end

  def assert_card_name_on_subscription_page(row, card_name)
    assert_table_values(SideBarPanelPageId::CARD_SUBSCRIPTIONS, "#{row}", 2, "#{card_name}")
  end

  def assert_project_name_on_subscription_table(subscription_type, index, project_name)
    assert_table_values(subscription_type_id(subscription_type), index, 0, project_name)
  end

  def assert_current_content_subscribable
    @browser.assert_text_not_present("You have subscribed to this via email.")
    @browser.assert_element_present(SideBarPanelPageId::VIA_EMAIL_LINK)
  end

  def assert_current_highlighted_option_on_side_bar_of_management_page(highlighted_option)
    highlighted = @browser.get_eval("#{class_locator('current-selection', 0)}.innerHTML.unescapeHTML()")
    assert_equal(highlighted_option, highlighted.strip)
  end

  def assert_links_present_on_recently_viewed_page_for(project, *wiki_links)
    project = project.identifier if project.respond_to? :identifier
    click_on_recently_viewed_pages_panel
    wiki_links.each do |wiki_link|
      assert_link_present("/projects/#{project}/wiki/#{wiki_link.to_s.gsub("\s", '_')}/show")
    end
  end

  def assert_links_not_present_on_recently_viewed_page_for(project, *wiki_links)
    project = project.identifier if project.respond_to? :identifier
    click_on_recently_viewed_pages_panel
    wiki_links.each do |wiki_link|
      assert_link_not_present("/projects/#{project}/wiki/#{wiki_link.to_s.gsub("\s", '_')}/show")
    end
  end

  def assert_no_recently_viewed_pages_present
    click_on_recently_viewed_pages_panel
    @browser.assert_text_present('(No recently viewed pages)')
  end

  def assert_order_of_recenlty_viewed_pages(*page_links)
    page_links_as_read = @browser.get_eval(%{
      this.browserbot.getCurrentWindow().$('recently-viewed-pages').innerHTML.unescapeHTML()
    })
    links_order_as_required  = ''
    page_links << 'Index of pages'
    page_links.each { |links| links_order_as_required << links }
    assert_equal(page_links_as_read.strip_all, links_order_as_required.strip_all)
  end

  def assert_index_of_pages_link_present
    @browser.assert_element_present(SideBarPanelPageId::INDEX_OF_PAGES_LINK)
  end

  def assert_url_shown_as_link_on_comment(link)
    @browser.assert_element_present("css=#discussion div.comment a[href=#{link.to_s.inspect}]")
  end

  def assert_red_error_link_present_on_comment
    @browser.assert_element_present("css=#discussion div.comment a.error_link")
  end

  def assert_link_with_a_red_cross_present_on_comment
    @browser.assert_element_present("css=#discussion div.comment a.non-existent-wiki-page-link")
  end

  def assert_save_icon_for_favorites_present(favorite_name, order)
    title = @browser.get_eval("#{class_locator("icon", order)}.title")
    assert_equal("Save current view as '#{favorite_name}'", title)
  end

  def assert_update_icon_not_present_for_wiki(wiki_name, order)
    assert_equal(false, @browser.is_element_present(class_locator('icon', order)))
  end

  def assert_manage_favorites_and_tabs_link_present
    @browser.assert_element_present(SideBarPanelPageId::MANAGE_TEAM_FAVORITES_AND_TABS_LINK)
  end

  def assert_manage_favorites_and_tabs_link_not_present
    @browser.assert_element_not_present(SideBarPanelPageId::MANAGE_TEAM_FAVORITES_AND_TABS_LINK)
  end

  def assert_my_favorites_drop_down_not_present
    @browser.assert_element_not_present(SideBarPanelPageId::ADD_CURRENT_VIEW_MY_FAVORITES_LINK)
  end

  def assert_updated_tab_has_star(tab_name)
    @browser.assert_element_matches(tab_name_link(tab_name), /#{tab_name}*/)
  end

  def assert_via_email_not_present
    @browser.assert_element_not_present(SideBarPanelPageId::SUBSCRIBE_VIA_EMAIL)
  end

  def assert_formatting_help_side_bar_not_present
    @browser.assert_element_not_present(SideBarPanelPageId::COLLAPSIBLE_HEADER_FOR_FORMATTING_HELP)
  end

  def assert_personal_favorites_names_present(*saved_view_names)
    saved_view_names.each do |saved_view_name|
      @browser.assert_text_present_in(SideBarPanelPageId::FAVORITES_PERSONAL_ID, saved_view_name)
    end
  end

  def assert_personal_favorites_names_not_present(*saved_view_names)
    unless @browser.is_element_present(SideBarPanelPageId::FAVORITES_PERSONAL_ID)
      @browser.click_and_wait(SideBarPanelPageId::MY_FAVORITES_LINK)
    end
    saved_view_names.each do |saved_view_name|
      @browser.assert_text_not_present_in(SideBarPanelPageId::FAVORITES_PERSONAL_ID, saved_view_name)
    end
  end

  def assert_no_personal_favorite_for_current_user
    @browser.assert_element_present(SideBarPanelPageId::ADD_CURRENT_VIEW_MY_FAVORITES_LINK)
    unless @browser.is_visible(SideBarPanelPageId::VIEW_SAVE_PANEL_MY_ID)
      @browser.click(SideBarPanelPageId::ADD_CURRENT_VIEW_MY_FAVORITES_LINK)
    end
    @browser.assert_element_not_present(SideBarPanelPageId::FAVORITES_PERSONAL_ID)
  end

  def should_not_see_my_favorite_section
    @browser.assert_element_not_present(SideBarPanelPageId::MY_FAVORITES_LINK)
    @browser.assert_element_not_present(SideBarPanelPageId::FAVORITES_PERSONAL_ID)
  end

  def should_see_manage_favorite_and_tabs_link_in_personal_favorite_section
    @browser.assert_text_not_present_in(SideBarPanelPageId::FAVORITES_CONTAINER_PERSONAL_ID, "Manage team favorites and tabs")
  end

  def assert_side_bar_collapsed
    @browser.assert_visible(SideBarPanelPageId::SIDEBAR_ICON_EXPAND)
  end

  def assert_side_bar_expanded
    @browser.assert_visible(SideBarPanelPageId::SIDEBAR_ICON_COLLAPSE)
  end

  def expand_collapse_sidebar_icon_should_not_be_displayed
    @browser.assert_element_not_present(SideBarPanelPageId::SIDEBAR_CONTROL_ID)
  end
end
