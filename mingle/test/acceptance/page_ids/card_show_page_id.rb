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

module CardShowPageId

  COMPLETE_TRANSITION_BUTTON = 'complete_transition'
  TRANSITION_POPUP_COMMENT_BOX = 'popup-comment'
  MURMUR_THIS_TRANSITION_CHECKBOX="murmur-this-transition"
  CLONE_CARD_LINK='link=Copy to...'
  CONTINUE_BUTTON ="continue"
  CONTINUE_TO_COPY_ID= "continue-copy-to"
  CONFIRM_CONTINUE_TO_COPY_ID = 'link=Continue to copy'
  CANCEL_COPY='cancel-copying'
  SELECT_PROJECT_ON_CLONE_CARD_DROP_LINK='select_project_drop_link'
  CARD_RELATIONSHIP_PROPERTY_DEF_ID = "CardRelationshipPropertyDefinition"
  USER_PROPERTY_DEF_ID = "UserPropertyDefinition"
  LIGHTBOX_ID='lightbox'
  HISTORY_LINK_ID_ON_CARD ='history-link'
  REFRESH_LINK_ID_ON_CARD = 'link=refresh'
  CARD_COMMENT_BOX_ID='card_comment'
  NEXT_LINK_ID = 'next-link'
  PREVIOUS_LINK_ID = 'previous-link'
  ADD_WITH_MORE_DETAILS_BUTTON_ID='quick-add-more-detail'
  ADD_COMMENT_BUTTON_ID = 'add_comment'
  CARD_DISCUSSION_LINK = "discussion-link"
  SHOW_MURMUR_PREF_CHECKBOX_ID ="show-murmurs-preference"
  MURMUR_THIS_CARD_CHECKBOX_ID = "murmur-this-show"
  TREE_CARDS_QUICK_ADD_ID = "tree_cards_quick_add"
  SEARCH_LINK_ON_CARD = 'search-link'
  SEARCH_CARD_TEXT_BOX = 'card-selector-q'
  CARD_SELECTOR_SEARCH_COMMIT_BUTTON = 'card-selector-search-commit'
  CARD_EXPLORER_FILTER_FIRST_CARD_TYPE_VALUE_DROP_LINK = "card_explorer_filter_widget_cards_filter_0_values_drop_link"
  TOGGLE_HIDDEN_PROPERTIES_CHECKBOX="toggle_hidden_properties"
  CANCEL_BUTTON = "cancel"
  EDIT_LINK_ID = "link=Edit"
  CONFIRM_DELETE_ID='confirm_delete'

  PREVIEW_CARD_LINK = "link=Preview"

  def transition_cancel_link_id
    "link=Cancel"
  end

  def transition_popup_property_drop_link_id(property,context)
    "#{property.html_id}_#{context}_drop_link"
  end

  def transition_popup_property_add_value_id(property,context)
    "#{property.html_id}_#{context}_action_adding_value"
  end

  def transition_popup_property_inline_editor_id(property,context)
     "#{property.html_id}_#{context}_inline_editor"
  end

  def transition_popup_anytext_or_number_or_date_property_drop_link_id(property,context)
    "textpropertydefinition_#{property.id}_#{context}_drop_link"
  end

  def transition_popup_anytext_or_number_or_date_property_option_notset_id(property,context)
  "textpropertydefinition_#{property.id}_#{context}_option_(not set)"
  end

  def transition_popup_anytext_or_number_or_date_property_add_value_id(property,context)
  "textpropertydefinition_#{property.id}_#{context}_action_adding_value"
  end

  def transition_popup_anytext_or_number_or_date_property_inline_editor_id(property,context)
    "textpropertydefinition_#{property.id}_#{context}_inline_editor"
  end

  def transition_popup_tree_relationship_sets_drop_link_id(property)
    droplist_part_id(property, "sets_drop_link")
  end

  def transition_popup_tree_relationship_dropdown_value_id(property)
    "css=##{droplist_part_id(property, "sets_drop_down")} .droplist-action-option"
  end

  def transition_link_id(transition)
    "transition_#{transition.id}"
  end

  def transition_popup_dropdown_filter_id(property)
    css_locator("##{droplist_lightbox_dropdown_id(property, '')}  .dropdown-options-filter")
  end

  def card_selector_drop_down_id(property, context)
    "css=##{droplist_dropdown_id(property, context)} .droplist-action-option"
  end

  def card_delete_link_id
    'link=Delete'
  end

  def history_version_link_id(options)
    "link-to-card-#{options[:card_number]}-#{options[:version_number]}"
  end

  def show_property_drop_down_search_text_field_id(property)
    css_locator("##{droplist_dropdown_id(property,'show')}  .dropdown-options-filter")
  end

  def show_add_children_link(tree)
    "show-add-children-link-#{tree.id}"
  end

  def remove_from_tree_id(tree)
    "remove_from_tree_#{tree.id}"
  end

  def card_explorer_filter_first_value_option_id(card_type_name)
    "card_explorer_filter_widget_cards_filter_0_values_option_#{card_type_name}"
  end

  def card_navigation_icon_for_readonly_property_id(id)
    "css=##{id} + .card-relationship-link"
  end

  def card_navigation_icon_for_property_id(id)
    "css=##{id} ~ .card-relationship-link"
  end

  def select_project_option_to_clone_card_id(project)
    "select_project_option_#{project.name}"
  end

  def plus_drop_link_on_grid
    "css=.add-dimension-drop-down"
  end

  def add_new_value_id(id)
    "#{id}_action_adding_value"
  end

  def add_new_value_text_field_id(id)
    "#{id}_inline_editor"
  end

end
