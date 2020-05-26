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

module TreeFilterPanelPageId

  CARD_EXPLORER_SEARCH_RESULT_FOR_TREE_ID ='card-explorer-search-result-for-tree'
  CARD_DRAG_CANDIDATES_FROM_FILTER_ID = 'card_drag_candidates_from_filter'
  CARD_DRAG_CANDIDATES_FROM_SEARCH_ID = 'card_drag_candidates_from_search'

  def checkbox_id(card_number)
    "checkbox[#{card_number}]"
  end

  def filter_card_child_candidate_id(card_number)
    "filter_card_child_candidate_#{card_number}"
  end

  def search_card_child_candidate_id(card_number)
    "search_card_child_candidate_#{card_number}"
  end

  def search_top_page_id(page_number)
    "search_top_page_#{page_number}"
  end

  def exclude_type_id(card_type_name)
    "exclude-type-#{card_type_name}"
  end

  def filter_widget_cards_filter_property_drop_link(card_type, index)
    "#{card_type.html_id}-filter-widget_cards_filter_#{index}_properties_drop_link"
  end

  def filter_widget_cards_filter_values_drop_link(card_type, index)
    "#{card_type.html_id}-filter-widget_cards_filter_#{index}_values_drop_link"
  end

  def card_type_filter_widget_cards_filter_properties_drop_link(card_type, filter_order_number)
    "cardtype_#{card_type.id}-filter-widget_cards_filter_#{filter_order_number}_properties_drop_link"
  end

  def card_type_filter_widget_cards_filter_values_drop_link(card_type, filter_order_number)
    "cardtype_#{card_type.id}-filter-widget_cards_filter_#{filter_order_number}_values_drop_link"
  end

  def filter_widget_cards_filter_properties(card_type, filter_order_number)
    "#{card_type.html_id}-filter-widget_cards_filter_#{filter_order_number}_properties"
  end
end

module SideBarPanelPageId
  include TreeFilterPanelPageId

  FILTER_TAGS_ID="filter_tags"
  ADD_A_FILTER_LINK="link=Add a filter"
  FILTER_VALUES_DROP_LINK="cards_filter_1_values_drop_link"
  IS_ID='is'
  IS_NOT_ID='is not'
  IS_BEFORE_ID='is before'
  IS_AFTER_ID='is after'
  IS_GREATER_THAN='is greater than'
  IS_LESS_THAN_ID='is less than'
  ADD_FILTER_FOR_EXPLORER_ID='add_a_new_filter_for_explorer'
  FILTER_LINK_ID='filter-link'
  FILTER_LINK='link=Filter'
  CARD_LIST_FILTER_TAGS_ID='card-list-filter-tags'
  APPLY_NOW_BUTTON="//input[@value='Apply now']"
  FILTER_MQL_ID='filter_mql'
  FILTER_WIDGET='filter-widget'
  NEW_FILTER_BUTTON='new_filter'
  MQL_EDIT_VIEW_ID='mql_edit_view'
  MQL_FILTER_EDIT_WINDOW = 'mql_filter_edit_window'
  ADVANCED_FILTER_LINK_ID='advanced-filter-link'
  ADVANCED_FILTER_LINK='link=Advanced Filter'
  MQL_FILTER_EDIT_WINDOW_ID="//textarea[@name='filters[mql]']"
  APPLY_FILTER_BUTTON='finish-editing'
  CLEAR_CONTENT_BUTTON='clear-editing-content'
  CANCEL_EDIT_BUTTON='cancel-editing'
  FIND_CARD_DROP_LINK='find-card-to-drop-link'
  SEARCH_LINK='search-link'
  CARD_EXPLORER_Q_ID='card-explorer-q'
  CARD_EXPLORER_SEARCH_ID='card-explorer-search-commit'
  RESET_FILTER_ID="Reset filter"
  SIDEBAR_CONTROL_ID='sidebar-control'
  SIDEBAR_ICON_EXPAND="sidebar-icon-expand"
  SIDEBAR_ICON_COLLAPSE="sidebar-icon-collapse"
  VIA_EMAIL_LINK="link=via email"
  INDEX_OF_PAGES_LINK='link=Index of pages'
  ADD_CURRENT_VIEW_TEAM_FAVORITES_LINK='link=Add current view to team favorites'
  ADD_CURRENT_VIEW_MY_FAVORITES_LINK='link=Add current view to my favorites'
  ADD_CURRENT_PAGE_MY_FAVORITES_LINK='link=Add current page to my favorites...'
  MANAGE_TEAM_FAVORITES_AND_TABS_LINK="link=Manage team favorites and tabs"
  VIEW_SAVE_PANEL_ID='view-save-panel-team'
  VIEW_SAVE_PANEL_MY_ID='view-save-panel-my'
  FAVORITES_TEAM_ID='favorites-team'
  FAVORITES_PERSONAL_ID='favorites-personal'
  TEAM_FAVORITES_LINK='link=Team favorites'
  MY_FAVORITES_LINK='link=My favorites'
  COLLAPSIBLE_HEADER_FOR_RECENTLY_VIEWED_PAGES_ID='collapsible-header-for-Recently-viewed-pages'
  COLLAPSIBLE_HEADER_FOR_TEAM_FAVORITES_ID='collapsible-header-for-Team-favorites'
  COLLAPSIBLE_HEADER_FOR_FORMATTING_HELP='collapsible-header-for-Formatting-help'
  NEW_VIEW_NAME_TEAM_ID='new-view-name-team'
  SAVE_VIEW_TEAM_ID='name=save-view-team'
  NEW_VIEW_NAME_TEXTBOX="new-view-name-my"
  SAVE_VIEW_NAME_BUTTON= "name=save-view-my"
  UPDATE_SAVED_VIEW_ID="update-saved-view"
  NOT_SET = '(not set)'
  RESET_TAB_DEFAULTS_ID = 'reset_to_tab_default'
  RESUBMIT_BUTTON = 'resubmit-button'
  CARD_SUBSCRIPTIONS ="card_subscriptions"
  PAGE_SUBSCRIPTIONS ="page_subscriptions"
  SUBSCRIBE_VIA_EMAIL='subscribe-via-email'
  FAVORITES_CONTAINER_PERSONAL_ID="favorites-container-personal"

  def subscription_type_id(subscription_type)
    "#{subscription_type}_subscriptions"
  end

  def cards_filter_option(index, value)
    "cards_filter_#{index}_values_option_#{value}"
  end

  def card_filter_value_option(filter_order_number,value)
    "cards_filter_#{filter_order_number}_values_option_#{value}"
  end

  def remove_filter(filter_order_number)
    "cards_filter_#{filter_order_number}_delete"
  end

  def cards_filter_drop_down(filter_order_number)
    "cards_filter_#{filter_order_number}_values_drop_down"
  end

  def cards_filter_properties_drop_link(filter_index)
    "cards_filter_#{filter_index}_properties_drop_link"
  end

  def cards_filter_values_drop_link(filter_position)
    "cards_filter_#{filter_position}_values_drop_link"
  end

  def cards_filter_properties_option(filter_order_number,property)
    "cards_filter_#{filter_order_number}_properties_option_#{property}"
  end

  def cards_filter_properties_drop_down(filter_order_number)
    "cards_filter_#{filter_order_number}_properties_drop_down"
  end

  def card_explorer_filter_widget_drop_link(filter_order_number)
    "card_explorer_filter_widget_cards_filter_#{filter_order_number}_properties_drop_link"
  end

  def card_explorer_filter_widget_property_option(filter_order_number,property_name)
    "card_explorer_filter_widget_cards_filter_#{filter_order_number}_properties_option_#{property_name}"
  end

  def cards_filter_operators_option(filter_order_number,operator)
    "cards_filter_#{filter_order_number}_operators_option_#{operator}"
  end

  def cards_filter_operators_drop_link(filter_order_number)
    "cards_filter_#{filter_order_number}_operators_drop_link"
  end

  def cards_filter_operators_drop_down(filter_order_number)
    "cards_filter_#{filter_order_number}_operators_drop_down"
  end

  def add_filter_for(card_type)
    "add_a_filter_for_#{card_type.id}"
  end

  def exclude_card_type(card_type_name)
    "exclude-type-#{card_type_name}"
  end

  def view_link(view)
    "link=#{view}"
  end

  def value_link(value)
    "link=#{value}"
  end

  def new_view_name(fav_type)
    "new-view-name-#{fav_type}"
  end

  def view_name(view_name)
    "link=#{view_name}"
  end

  def save_view(fav_type)
    "name=save-view-#{fav_type}"
  end

  def favorite_name_link(favorite_name)
    "link=#{favorite_name}"
  end

  def tab_name_link(tab_name)
    "tab_#{tab_name}_link"
  end

end
