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

module PropertyValuesPageId

  ENUMERATION_VALUE_INPUT_BOX_ID='enumeration_value_input_box'
  CARD_PROPERTIES_ADD_BUTTON='name=commit'
  CARD_PROPERTIES_QUICK_ADD_BUTTON='submit-quick-add'

  def edit_enum_value(enum_value)
    "id=edit-value-#{enum_value.id}"
  end

  def enum_value_name_editor(enum_value)
    "enumeration_value_#{enum_value.id}_name_editor"
  end

  def enumeration_values_id(property_definition)
    "enumeration-values-#{property_definition.id}"
  end

  def save_enum_value(enum_value)
    "id=save-value-#{enum_value.id}"
  end

  def delete_enum_value_id(enum_value)
    "delete-value-#{enum_value.id}"
  end

  def enumeration_value_id(enum_value)
    "enumeration_value_#{enum_value.id}"
  end

  def color_panel_id(enum_value)
    "color_panel_#{enum_value.id}"
  end

  def color_provider_text_box(enum_value)
    "color_provider_color_#{enum_value.id}"
  end

  def ok_button_to_choose_color(enum_value)
    "commit_color_#{enum_value.id}"
  end

  def enum_values_on_mgmt_page(value)
    "//span[text()='#{value}']"
  end

end
