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

module ListViewPageId

  LIST_VIEW_LINK='link=List'
  SELECT_ALL_ID='select_all'
  BULK_SET_PROPERTIES_BUTTON='bulk-set-properties-button'
  ADD_OR_REMOVE_COLUMNS_LINK='link=Add / remove columns'
  APPLY_TO_SELECTED_COLUMN_ID="apply_selected_column"
  SELECT_NONE_ID='select_none'
  BULK_SET_PROPERTIES_PANEL='bulk-set-properties-panel'
  BULK_TRANSITION_ID='bulk_transitions'
  BULK_DELETE_ID='bulk-delete-button'
  CONFIRM_DELETE_ID="confirm_delete"
  BULK_TAGS_BUTTON='bulk-tag-button'
  BULK_TAGS_TEXT_BOX='bulk_tags'
  SUBMIT_BULK_TAGS_ID='submit_bulk_tags'
  BULK_EDIT_CARD_TYPE_LINK="bulk_edit_card_type_drop_link"
  CONTINUE_BUTTON="continue"
  CANCEL_BUTTON="cancel"
  SELECT_ALL_LANES_ID="select_all_lanes"
  COLUMN_SELECTOR_LINK='column-selector-link'
  BULK_OPTIONS_ID='bulk-options'


  def toggle_column_id(project,propertydef)
    "toggle_column_#{project.reload.find_property_definition(propertydef).html_id}"
  end


  def select_all_cards_id(number_of_cards)
    "link=Select all #{number_of_cards} cards in current view"
  end

  def remove_tag_id(tag_id)
    "remove-tag-#{tag_id}"
  end

  def bulk_edit_card_type_option(card_type)
     "bulk_edit_card_type_option_#{card_type}"
  end

  def bulk_edit_property_drop_link(property)
    "bulk_#{property.html_id}_drop_link"
  end

  def bulk_edit_property_drop_down(property)
    "bulk_#{property.html_id}_drop_down"
  end

  def bulk_property_option(property,property_value)
    "bulk_#{property.html_id}_option_#{property_value}"
  end

  def list_transition_link(transition)
    "#{transition.html_id}_link"
  end

  def bulk_drop_list_drop_down_id(property)
    css_locator("##{droplist_dropdown_id(property, 'bulk')}  .dropdown-options-filter")
  end

  def select_card_id(card)
    css_locator("input[value = #{card.id}]")
  end

  def card_on_list_id(card)
    "card-number-#{card}"
  end

  def card_list_column_id(name)
    "//a[@class='column-header-link sortable_wrapper']/span[text()='#{name}']"
  end

  def column_header_link(position)
    class_locator('column-header-link', position)
  end

  def list_view_card_id(card)
    card.html_id
  end
end
