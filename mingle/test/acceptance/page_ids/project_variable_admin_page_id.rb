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

module ProjectVariableAdminPageId
  PROJECT_VARIABLE_NAME_ID='project_variable_name'
  PROJECT_VARIABLE_VALUE_ID='project_variable_value'
  ANY_CARD_TYPE_RADIO_BUTTON="project_variable_card_type_id_"
  PROJECT_VARIABLE_DROP_LINK="project_variable_drop_link"
  PROJECT_VARIABLE_EDIT_LINK="project_variable_edit_link"
  PROJECT_VARIABLE_EDITOR_ID='project_variable_editor'
  EDIT_PROJECT_VALUE_DROP_LINK="plv_drop_link"
  EDIT_PROJECT_VALUE_DROP_DOWN="plv_drop_down"
  CONTINUE_TO_DELETE_LINK="link=Continue to delete"
  CONTINUE_TO_UPDATE_LINK="link=Continue to update"
  CREATE_NEW_PROJECT_VARIABLE_LINK="link=Create new project variable"
  CREATE_PROJECT_VARIABLE_LINK="link=Create project variable"
  SAVE_PROJECT_VARIABLE_LINK="link=Save project variable"
  AVAILABLE_PROPERTY_DEFINATION_CONTAINER = 'available_property_definitions_container'
  
  def project_variable_data_type_radio_button(data_type)
    "project_variable_data_type_#{data_type.downcase}"
  end
  
  def card_type_radio_button(card_type)
    "project_variable_card_type_id_#{card_type.id}"
  end
  
  def project_variable_options(value)
    "project_variable_option_#{value.to_s.downcase}"
  end
  
  def property_definitions_check_box(property_definition)
    "property_definitions[#{property_definition.id}]"
  end
  
  def project_variable_delete_link(project_variable_definition)
    "project_variable_#{project_variable_definition.id}"
  end
end
