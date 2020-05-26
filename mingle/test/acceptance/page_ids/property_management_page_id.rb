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

module PropertyManagementPageId

  FORMULA_TYPE = 'formula'
  MANAGED_TEXT_TYPE = "Managed text list"
  FREE_TEXT_TYPE = "Allow any text"
  MANAGED_NUMBER_TYPE = "Managed number list"
  FREE_NUMBER_TYPE = "Allow any number"
  USER_TYPE = "team"
  DATE_TYPE = "date"
  CARD_TYPE = "card"
  PROPERTY_TYPE_ANY_TEXT_ID='definition_type_any_text'
  PROPERTY_TYPE_NUMBER_LIST_ID='definition_type_number_list'
  PROPERTY_TYPE_ANY_NUMBER_ID='definition_type_any_number'
  PROPERTY_TYPE_TEAM_ID='definition_type_user'
  PROPERTY_TYPE_DATE_ID='definition_type_date'
  PROPERTY_TYPE_CARD_ID='definition_type_card_relationship'
  PROPERTY_TYPE_FORMULA_ID='definition_type_formula'
  PROPERTY_TYPE_FORMULA_CHECKBOX="property_definition_null_is_zero"
  PROPERTY_DEFINITION_DESCRIPTION_ID='property_definition_description'
  PROPERTY_DEFINTION_NAME_ID='property_definition_name'
  SELECT_NONE_PROPERTY_AVAILABLE_ID='select_none'
  PROPERTY_DEFINITION_FORMULA_TEXT_BOX='property_definition_formula'
  CONTINUE_TO_UPDATE_LINK="link=Continue to update"
  CONTINUE_UPDATE_BOTTOM_BUTTON='continue_update_bottom'
  SAVE_PROPERTY_LINK='link=Save property'
  CREATE_PROPERTY_LINK='link=Create property'
  CREATE_NEW_CARD_PROPERTY_LINK='link=Create new card property'
  CONFIRM_HIDE_PROPERTY_LINK="confirm_hide"
  UPDATE_SUCCESSFUL_MESSAGE = 'Property was successfully updated.'
  PROPERTY_DEFINATION_TABLE_LIST_ID = "//table[@id='property_definitions']//td"
  PROPERTY_DEFINATIONS_ID = 'property_definitions'

  def property_row_id(property_def)
    "prop_def_row_#{property_def.id}"
  end

  def delete_property_definition(property_def)
    "delete_property_def_#{property_def.id}"
  end

  def enumeration_values_property_definition_id(property_definition)
    "id=enumeration-values-#{property_definition.id}"
  end

  def card_types_locator(card_type)
    "card_types[#{card_type.id}]"
  end

  def restricted_property_definition(property)
    "restricted-#{property.id}"
  end

  def visibility_property_definition(property)
    "visibility-#{property.id}"
  end

  def transitiononly_property_definition(property)
    "transitiononly-#{property.id}"
  end

  def card_types_definition(card_type_definition)
    "card_types[#{card_type_definition.id}]"
  end

end
