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

module CardFilterAction

  def filter_card_list_by(project, properties={})
    unless properties.delete(:keep_filters)
      reset_existing_filters
    end
    index = existing_filter_count

    card_type = properties.delete(:type)
    if card_type
      filter_card_list_by_property(project, :type, card_type, 0)
    end

    properties.each do |property, value|
      if property == :tags
        filter_list_by_tags(value, SideBarPanelPageId::FILTER_TAGS_ID)
      else
        filter_card_list_by_property(project, property, value, index)
        index += 1
      end
    end
  end

  def click_add_a_filter_link
    ensure_sidebar_open
    @browser.click SideBarPanelPageId::ADD_A_FILTER_LINK
  end

  def add_new_filter
    ensure_sidebar_open
    @browser.click(SideBarPanelPageId::ADD_A_FILTER_LINK)
  end

  def remove_a_filter_set(filter_order_number)
    ensure_sidebar_open
    @browser.with_ajax_wait do
      @browser.click(remove_filter(filter_order_number))
    end
  end

  def set_the_filter_property_option(filter_order_number, property)
    ensure_sidebar_open
    filter_tester.set_property(filter_order_number, property) unless filter_order_number == 0
  end

  def set_the_filter_value_option(filter_order_number, filter_value)
    ensure_sidebar_open
    filter_tester.set_value(filter_order_number, filter_value)
  end

  def set_the_filter_value_using_select_lightbox(filter_order_number, filter_value_card)
    ensure_sidebar_open
    card_number_to_set = filter_value_card.number
    @browser.with_ajax_wait do
      @browser.click SideBarPanelPageId::FILTER_VALUES_DROP_LINK
      @browser.click droplist_select_card_action(cards_filter_drop_down(filter_order_number))
      @browser.click card_selector_result_locator(:filter, card_number_to_set)
    end
  end

  def set_the_filter_property_and_value(filter_number, options = {})
    set_the_filter_property_option(filter_number, options[:property])
    select_operator(filter_number, options[:operator]) if options[:operator]
    set_the_filter_value_option(filter_number, options[:value])
  end

  def open_filter_property_list(filter_order_number)
    filter_tester.open_property_list(filter_order_number)
  end

  def open_filter_value_list(filter_order_number)
    filter_tester.open_value_list(filter_order_number)
  end

  def open_filter_operator_list(filter_order_number)
    filter_tester.open_operator_list(filter_order_number)
  end

  def select_is(filter_number)
    select_operator(filter_number, SideBarPanelPageId::IS_ID)
  end

  def select_is_not(filter_number)
    select_operator(filter_number, SideBarPanelPageId::IS_NOT_ID)
  end

  def select_is_before(filter_number)
    select_operator(filter_number, SideBarPanelPageId::IS_BEFORE_ID)
  end

  def select_is_after(filter_number)
    select_operator(filter_number, SideBarPanelPageId::IS_AFTER_ID)
  end

  def select_is_greater_than(filter_number)
    select_operator(filter_number, SideBarPanelPageId::IS_GREATER_THAN)
  end

  def select_is_less_than(filter_number)
    select_operator(filter_number, SideBarPanelPageId::IS_LESS_THAN_ID)
  end

  def add_new_filter_on_card_explore_panel
    @browser.click(SideBarPanelPageId::ADD_FILTER_FOR_EXPLORER_ID)
  end

  def set_the_filter_property_option_on_card_explore_panel(filter_order_number, property_name)
    unless filter_order_number == 0
      @browser.with_ajax_wait do
        @browser.click(card_explorer_filter_widget_drop_link(filter_order_number))
        @browser.click(card_explorer_filter_widget_property_option(filter_order_number,property_name))
      end
    end
  end

  private
  def select_operator(filter_number, operator)
    filter_tester.select_operator(filter_number, operator)
  end

  def filter_tester
    ensure_sidebar_open
    filter_prefix = lambda { |filter_number| "cards_filter_#{filter_number}" }
    FilterTester.new(@browser, filter_prefix)
  end

  def click_on_interactive_filter_tab
    ensure_sidebar_open
    @browser.click(SideBarPanelPageId::FILTER_LINK_ID) if @browser.is_element_present(SideBarPanelPageId::FILTER_LINK)
    @browser.wait_for_element_visible(SideBarPanelPageId::CARD_LIST_FILTER_TAGS_ID)
  end
end

module MqlFilterAction

  def set_mql_filter_for(condition)
    click_on_edit_mql_filter
    input_mql_conditions(condition)
    click_submit_mql
  end

  def click_apply_this_filter
    ensure_sidebar_open
    @browser.with_ajax_wait do
      @browser.click(SideBarPanelPageId::APPLY_NOW_BUTTON)
    end
  end

  def click_on_edit_mql_filter
    click_on_mql_filter_tab
    @browser.click(SideBarPanelPageId::FILTER_MQL_ID)
    @browser.wait_for_element_visible(SideBarPanelPageId::MQL_EDIT_VIEW_ID)
  end

  def click_on_mql_filter_tab
    ensure_sidebar_open
    @browser.click(SideBarPanelPageId::ADVANCED_FILTER_LINK_ID) if @browser.is_element_present(SideBarPanelPageId::ADVANCED_FILTER_LINK)
    @browser.wait_for_element_visible(SideBarPanelPageId::FILTER_MQL_ID)
  end

  def input_mql_conditions(conditions)
    ensure_sidebar_open
    @browser.type(SideBarPanelPageId::MQL_FILTER_EDIT_WINDOW_ID, conditions)
  end

  def click_submit_mql
    ensure_sidebar_open
    @browser.with_ajax_wait do
      @browser.click(class_locator(SideBarPanelPageId::APPLY_FILTER_BUTTON))
    end
  end

  def click_clear_mql
    ensure_sidebar_open
    @browser.click(class_locator(SideBarPanelPageId::CLEAR_CONTENT_BUTTON))
  end

  def click_cancel_mql
    ensure_sidebar_open
    @browser.with_ajax_wait do
      @browser.click(class_locator(SideBarPanelPageId::CANCEL_EDIT_BUTTON))
    end
  end

  def reset_mql_filter_by
    click_on_edit_mql_filter
    click_clear_mql
    click_submit_mql
  end

end

module TreeFilterPanelAction

  def open_card_explorer_for(project, tree)
    navigate_to_tree_view_for(project, tree.name)
    @browser.click(SideBarPanelPageId::FIND_CARD_DROP_LINK)
    @browser.wait_for_all_ajax_finished
  end

  def search_through_card_explorer_text_search(search_string)
    @browser.click(SideBarPanelPageId::FIND_CARD_DROP_LINK)
    @browser.click(SideBarPanelPageId::SEARCH_LINK)
    @browser.type(SideBarPanelPageId::CARD_EXPLORER_Q_ID, search_string)
    @browser.with_ajax_wait do
      @browser.click(SideBarPanelPageId::CARD_EXPLORER_SEARCH_ID)
    end
  end

  def add_new_filter_for_explorer
    @browser.click(SideBarPanelPageId::ADD_FILTER_FOR_EXPLORER_ID)
  end

  def open_property_values_drop_down_in_filter(filter_position)
    unless @browser.is_visible(cards_filter_drop_down(filter_position))
      @browser.click(cards_filter_values_drop_link(filter_position))
      @browser.wait_for_element_visible(cards_filter_drop_down(filter_position))
    end
  end

  def open_filter_values_widget_for_relationship_property(filter_position)
    @browser.click cards_filter_values_drop_link(filter_position)
    @browser.click droplist_select_card_action(cards_filter_drop_down(filter_position))
    @browser.with_ajax_wait do
      @browser.click(cards_filter_values_drop_link(filter_position))
    end
  end


  def set_tree_filter_for(card_type, filter_order_number, options={})
    property = options[:property]
    value = options[:value] || nil
    plv_value = options[:plv_value] || nil
    add_new_tree_filter_for(card_type)
    set_the_tree_filter_property_option(card_type, filter_order_number, property)
    if value.is_a?(Numeric) || value == nil
      set_the_tree_filter_value_option_to_card_number(card_type, filter_order_number, value) if value != nil
      set_the_tree_filter_value_option_card_picker_to_a_plv(card_type, filter_order_number, plv_value, options) if plv_value != nil
    elsif value == '(not set)'
      set_the_tree_filter_value_option_card_picker_to_not_set(card_type,filter_order_number, options)
    else
      set_the_tree_filter_value_option(card_type, filter_order_number, value, options)
    end
  end

  def add_new_tree_filter_for(card_type)
    @browser.click(add_filter_for(card_type))
  end

  def set_the_tree_filter_property_option(card_type, filter_order_number, property)
    tree_filter_tester(card_type).set_property(filter_order_number, property)
  end

  def set_the_tree_filter_value_option(card_type, filter_order_number, filter_value, options={:wait => false})
    tree_filter_tester(card_type).set_value(filter_order_number, filter_value, options)
  end

  def set_the_tree_filter_value_option_to_card_number(card_type, filter_order_number, card_number)
    tree_filter_tester(card_type).set_card_number_value(filter_order_number, card_number)
  end

  def set_the_tree_filter_value_option_card_picker_to_a_plv(card_type, filter_order_number, plv, options={:wait => false})
    tree_filter_tester(card_type).set_card_number_value_to_plv(filter_order_number, plv, options)
  end

  def set_the_tree_filter_value_option_card_picker_to_not_set(card_type, filter_order_number, options={:wait => false})
    tree_filter_tester(card_type).set_card_number_value_to_not_set(filter_order_number, options)
  end

  def remove_filter_set(card_type, filter_order_number, options={:wait => true})
    @browser.with_ajax_wait do
      tree_filter_tester(card_type).remove_filter(filter_order_number, options)
    end
  end

  def click_exclude_card_type_checkbox(*card_types)
    card_types.each do |card_type|
      card_type_name = card_type.respond_to?(:name) ? card_type.name : card_type
      @browser.with_ajax_wait do
        @browser.click(exclude_card_type(card_type_name))
      end
    end
  end

  def open_tree_filter_property_list(card_type, filter_order_number)
    tree_filter_tester(card_type).open_property_list(filter_order_number)
  end

  def open_tree_filter_operator_list(card_type, filter_order_number)
    tree_filter_tester(card_type).open_operator_list(filter_order_number)
  end

  def open_tree_filter_value_list(card_type, filter_order_number)
    tree_filter_tester(card_type).open_value_list(filter_order_number)
  end

  def reset_tree_filter
    click_link(SideBarPanelPageId::RESET_FILTER_ID)
  end

  private

  def tree_filter_tester(card_type)
    ensure_sidebar_open
    filter_prefix = lambda { |filter_number| "#{card_type.html_id}-filter-widget_cards_filter_#{filter_number}" }
    FilterTester.new(@browser, filter_prefix)
  end

end


module SideBarPanelAction
  include TreeFilterPanelAction
  include CardFilterAction
  include MqlFilterAction

  def collapse_and_expand_side_bar
    (1..2).each{@browser.click(SideBarPanelPageId::SIDEBAR_CONTROL_ID)}
  end

  def navigate_to_saved_view(view)
    view = view.name if view.respond_to? :name
    @browser.click_and_wait(view_link(view))
  end

  def create_card_list_view_for(project, view_name, options = {})
    fav_type = options[:personal] ? 'my' : 'team'
    if fav_type == 'my'
      expand_my_favorites_menu
    else
      expand_favorites_menu
    end
    @browser.type new_view_name(fav_type), view_name
    @browser.click_and_wait save_view(fav_type)
    project.card_list_views.find_by_name(view_name)
  end

  def open_saved_view(view_name)
    ensure_sidebar_open
    @browser.click_and_wait(view_name(view_name))
    @browser.wait_for_all_ajax_finished
  end

  def click_subscribe_via_email
    @browser.with_ajax_wait do
      @browser.click(SideBarPanelPageId::VIA_EMAIL_LINK)
    end
  end

  def click_unsubscribe_on_subscriptions_table(subscription_type, index)
    @browser.with_ajax_wait do
      @browser.click(css_locator("table##{subscription_type}_subscriptions a[onclick]",index))
    end
  end

  def ensure_sidebar_open
    return unless @browser.is_element_present(SideBarPanelPageId::SIDEBAR_CONTROL_ID)
    unless @browser.is_element_present("css=.sidebar.expanded")
      @browser.click(SideBarPanelPageId::SIDEBAR_CONTROL_ID)
      wait_for_sidebar_is_expanded
    end
  end

  def ensure_sidebar_closed
    return unless @browser.is_element_present(SideBarPanelPageId::SIDEBAR_CONTROL_ID)
    if @browser.is_element_present("css=.sidebar.expanded")
      @browser.click(SideBarPanelPageId::SIDEBAR_CONTROL_ID)
      wait_for_sidebar_is_collpased
    end
  end

  def expand_favorites_menu
    ensure_sidebar_open
    if @browser.is_element_present SideBarPanelPageId::ADD_CURRENT_VIEW_TEAM_FAVORITES_LINK
      unless @browser.is_visible SideBarPanelPageId::VIEW_SAVE_PANEL_ID
        @browser.with_ajax_wait do
          @browser.click SideBarPanelPageId::ADD_CURRENT_VIEW_TEAM_FAVORITES_LINK
          @browser.wait_for_element_visible SideBarPanelPageId::VIEW_SAVE_PANEL_ID
        end
      end
    else
      unless @browser.is_visible SideBarPanelPageId::FAVORITES_TEAM_ID
        @browser.click SideBarPanelPageId::TEAM_FAVORITES_LINK
        @browser.wait_for_element_visible SideBarPanelPageId::FAVORITES_TEAM_ID
      end
      unless @browser.is_visible SideBarPanelPageId::VIEW_SAVE_PANEL_ID
        @browser.with_ajax_wait do
          @browser.click 'link=Add current view to team favorites...'
          @browser.wait_for_element_visible SideBarPanelPageId::VIEW_SAVE_PANEL_ID
        end
      end
    end
  end

  def set_filter_by_url(project, filters_to_set, style='list', tab="All")
    @browser.open("/projects/#{project.identifier}/cards/#{style}?#{filters_to_set}&tab=#{tab}")
  end

  def click_on_recently_viewed_pages_panel
    ensure_sidebar_open
    @browser.click(SideBarPanelPageId::COLLAPSIBLE_HEADER_FOR_RECENTLY_VIEWED_PAGES_ID)
  end

  def click_on_wiki_page_link_through_recently_viewed_panel_for(project, link)
    @browser.open("projects/#{project.identifier}/wiki/#{link}/show")
  end

  def update_tab_with_current_view(view_name)
    expand_favorites_menu
    @browser.type SideBarPanelPageId::NEW_VIEW_NAME_TEAM_ID, view_name
    @browser.click_and_wait SideBarPanelPageId::SAVE_VIEW_TEAM_ID
  end

  def save_tab(view_name)
    @browser.click_and_wait "tab_#{view_name.downcase.gsub(" ", "_")}_save"
  end

  def open_favorites_for(project, saved_view_name)
    project = project.identifier if project.respond_to? :identifier
    url = "/projects/#{project}/cards?view=#{saved_view_name.gsub(/[" "]/, '+')}"
    @browser.open(url)
  end

  def update_saved_view_with_current_view(project, saved_view_name, filter_link_url)
    url = "/projects/#{project.identifier}/cards/create_view?#{filter_link_url}&view[name]=#{saved_view_name.gsub(/[" "]/, '+')}"
    @browser.open(url)
  end

  def update_favorites_for(saved_view_order_number)
    expand_the_saved_views
    @browser.with_ajax_wait { @browser.click("css=.favorites .update-saved-view:nth-child(#{saved_view_order_number})") }
  end

  def expand_the_saved_views
    ensure_sidebar_open
    @browser.click(SideBarPanelPageId::COLLAPSIBLE_HEADER_FOR_TEAM_FAVORITES_ID)
  end

  def expand_my_favorites_menu
    ensure_sidebar_open
    if @browser.is_element_present(SideBarPanelPageId::ADD_CURRENT_VIEW_MY_FAVORITES_LINK)
      unless @browser.is_visible(SideBarPanelPageId::VIEW_SAVE_PANEL_MY_ID)
        @browser.click(SideBarPanelPageId::ADD_CURRENT_VIEW_MY_FAVORITES_LINK)
        @browser.wait_for_element_visible(SideBarPanelPageId::VIEW_SAVE_PANEL_MY_ID)
      end
    else
      unless @browser.is_visible(SideBarPanelPageId::FAVORITES_PERSONAL_ID)
        @browser.click(SideBarPanelPageId::MY_FAVORITES_LINK)
      end
        @browser.wait_for_element_visible(SideBarPanelPageId::FAVORITES_PERSONAL_ID)
      unless @browser.is_visible(SideBarPanelPageId::VIEW_SAVE_PANEL_MY_ID)
        @browser.click('link=Add current view to my favorites...')
        @browser.wait_for_element_visible(SideBarPanelPageId::VIEW_SAVE_PANEL_MY_ID)
      end
    end
  end

  def save_current_view_as_my_favorite(favorite_name)
    expand_my_favorites_menu
    @browser.type(SideBarPanelPageId::NEW_VIEW_NAME_TEXTBOX, favorite_name)
    @browser.click_and_wait SideBarPanelPageId::SAVE_VIEW_NAME_BUTTON
  end

  def open_the_personal_favorite(favorite_name)
    ensure_sidebar_open
    if @browser.is_element_present(SideBarPanelPageId::FAVORITES_PERSONAL_ID)
      @browser.click_and_wait(favorite_name_link(favorite_name))
    else
      @browser.click_and_wait(SideBarPanelPageId::MY_FAVORITES_LINK)
      @browser.click_and_wait(favorite_name_link(favorite_name))
    end
  end

  def create_personal_favorite_using_mql_condition(project, mql_condition, personal_favorite_name)
    navigate_to_grid_view_for(project)
    set_mql_filter_for(mql_condition)
    save_current_view_as_my_favorite(personal_favorite_name)
  end

  def open_my_favorite(favorite_name)
    ensure_sidebar_open
    @browser.click_and_wait(favorite_name_link(favorite_name))
  end

  def update_my_favorite_for(favorite_order_number)
    ensure_sidebar_open
    ensure_favorites_expanded
    container_id_suffix = @browser.is_element_present('css=#favorites-container-personal') ? 'personal' : 'my'
    selector="#favorites-container-#{container_id_suffix} .#{SideBarPanelPageId::UPDATE_SAVED_VIEW_ID}:nth-child(#{favorite_order_number})"
    @browser.click("css=#{selector}")
    @browser.wait_for_element_present('css=.favorite-update-success')
  end

  def ensure_favorites_expanded
    favorites_section_selector='css=#favorites-container .section-expand:nth-child(1)'
    while @browser.is_element_present(favorites_section_selector)
      @browser.click(favorites_section_selector)
    end
  end

  def save_current_page_as_my_favorite
    ensure_sidebar_open
    @browser.click SideBarPanelPageId::ADD_CURRENT_PAGE_MY_FAVORITES_LINK
  end

  def collapse_the_side_bar_on_maximized_view
    maximize_current_view
    ensure_sidebar_closed
  end

  def wait_for_sidebar_is_expanded
    @browser.wait_for_all_ajax_finished
    @browser.wait_for_element_present("css=.sidebar.expanded")

    # wait for the animation to complete so coordinates can be calculated correctly
    # for things like drag and drop
    sleep 1
  end

  def wait_for_sidebar_is_collpased
    @browser.wait_for_all_ajax_finished
    @browser.wait_for_element_not_present("css=.sidebar.expanded")

    # wait for the animation to complete so coordinates can be calculated correctly
    # for things like drag and drop
    sleep 1
  end

  def expand_the_side_bar_on_maximized_view
    maximize_current_view
    ensure_sidebar_open
  end

  def click_sidebar_control_icon
    @browser.with_ajax_wait { @browser.click(SideBarPanelPageId::SIDEBAR_CONTROL_ID) }
  end


  private
  def filter_card_list_by_property(project, property, value, filter_index)
    project = Project.find_by_name(project) unless project.respond_to?(:name)
    property = project.find_property_definition_or_nil(property) unless property.respond_to?(:name)
    property_type = property.attributes['type'] unless property.is_a?(CardTypeDefinition)
    unless existing_filter_count == 1 && property.to_s.downcase == Project.current.reload.card_type_definition.name.downcase
      click_add_a_filter_link
      @browser.click cards_filter_properties_drop_link(filter_index) unless filter_index == 0
      @browser.click "cards_filter_#{filter_index}_properties_option_#{Project.current.reload.find_property_definition(property).name}" unless filter_index == 0
    end

    unless value == PropertyValue::ANY
      if need_popup_card_selector?(property_type, value)
        open_filter_values_widget_for_relationship_property(filter_index)
        @browser.with_ajax_wait do
          @browser.click(value_link(value))
        end
      else

        @browser.click cards_filter_values_drop_link(filter_index)
        @browser.with_ajax_wait do
          @browser.click "cards_filter_#{filter_index}_values_option_#{value}"
        end
      end
    end
  end

end
