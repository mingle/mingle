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

module CardTypeAdminPageId
  CARD_DEFAULTS_DESCRIPTION_TEXT_BOX ='card_defaults[description]'
  SAVE_DEFAULTS_LINK = 'link=Save defaults'
  CREATE_NEW_CARD_TYPE_LINK = "link=Create new card type"
  CARD_TYPE_NAME_TEXT_BOX_ID = 'card_type_name'
  CONTINUE_TO_UPDATE_ID = "continue_update_top"
  SELECT_NONE_LINK = 'select_none'
  CREATE_TYPE_LINK = 'link=Create type'
  SAVE_TYPE_LINK = 'link=Save type'
  CONTINUE_TO_UPDATE_LINK= "link=Continue to update"
  CANCEL_BOTTOM_ID= "cancel_bottom"
  CONFIRM_BOTTOM_ID = 'confirm_bottom'
  EDIT_PROPERTIES_ID='edit-properties'

  def property_definition_check_box(property_definition)
    "property_definitions[#{property_definition.id}]"
  end

  def card_type_drag_drop_id(project, card_type)
    "drag_card_type_#{get_card_type_id(project, card_type)}"
  end

  def card_property_drag_and_drop_id(project, property)
    "drag_property_definition_#{get_property_id_on_card_type_edit_page(project, property)}"
  end

  def card_type_property_name_id(property)
    "card_type_property_name_#{property.id}"
  end

end
