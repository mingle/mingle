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

module TreeViewPageId

  REMOVE_THIS_CARD_AND_ITS_CHILDREN_XPATH = "//input[@value='#{'Remove Parent and Children'}']"
  REMOVE_JUST_THIS_CARD_XPATH = "//input[@value='#{'Remove Parent Card'}']"
  CANCEL_XPATH = "//input[@value='#{'Cancel'}']"
  TREE_LINK='link=Tree'
  TREE_RESULTS_SPINNER_ID='tree_result_spinner'
  CONFIRM_BOX_ID='confirm-box'
  DOC_OVERLAY_ID="doc_overlay"
  TREE_CONFIGURE_WIDGET_BUTTON='tree-configure-widget-button'
  CONFIGURE_LINK='link=configure'
  WORKSPACE_SELECTOR_LINK='workspace_selector_link'
  WORKSPACE_SELECTOR_PANEL_ID='workspace_selector_panel'
  TREE_NONE_SELECT_ID="tree-none"
  NODE_ADD_NEW_CARDS_ID="node_add_new_cards_node_0"
   NODE_ADD_NEW_CARD_NODE_ID="node_add_new_cards_card_0"
  TREE_CARDS_QUICK_ADD_FORM='tree_cards_quick_add_form'
  TREE_CARDS_QUICK_ADD_SAVE_BUTTON="tree_cards_quick_add_save_button"
  TREE_CARD_QUICK_ADD_CANCEL_BUTTON="tree_cards_quick_add_cancel_button"
  REMOVE_BUTTON_CLASS_LOCATOR='remove-button'
  ADD_BUTTON_CLASS_LOCATOR='add-button'
  CARD_NAME_CLASS_LOCATOR='card-name-input'
  CARD_TYPE_SELECT_DROPDOWN='card_type_select_link'
  LIST_LINK='link=List'
  TREE_INCREMENTAL_SEARCH_INPUT='tree_incremental_search_input'
  DROP_CARD_HERE_BUBBLE_ID="no-children-hint"
  CONFIGURE_LINK_ID='link=configure'
  TREE_INCREMENTAL_SEARCH_ID="tree_incremental_search"
  TREE_FILTER_CONTAINER='tree-filter-container'
  TREE_VIEW_TOOL_BAR_ID='tree_view_tool_bar'
  HIRERARCHY_LINK_ID='link=Hierarchy'

  def card_on_tree_id(card)
    "id=#{card.html_id}"
  end

  def node_card_remove_link(card)
    "node-#{card.html_id}-remove-link"
  end

  def tree_selector_id(tree)
    "tree-#{tree.id}"
  end

  def card_inner_element(card)
    "#{card.html_id}_inner_element"
  end

  def node_add_new_cards(card)
    "node_add_new_cards_#{card.html_id}"
  end

  def quick_add_card_type_option(type_name)
    "card_tree_quick_add_card_type_option_#{type_name}"

  end

  def card_type_node_option_id(card_type_node,type)
  "type_node_#{card_type_node}_container_option_#{type}"
  end

  def card_popup_outer_box(card)
    "card_show_lightbox_content"
  end

  def transition_id(transition)
    "id=transition_#{transition.id}"
  end

  def node_card_remove_link(card)
    "node-#{card.html_id}-remove-link"
  end

  def twisty_between_nodes_in_cards(card)
    css_locator("#twisty_for_card_#{card.number} > .twisty")
  end

  def search_child_card_candidate_id(card)
     "search_card_child_candidate_#{card.number}"
   end

end
