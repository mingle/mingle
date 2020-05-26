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

module CardTreeAdminPageId
  
  
  CREATE_NEW_CARD_TREE_LINK = 'link=Create new card tree'
  TREE_NAME_TEXT_BOX = 'tree_name'
  TREE_DESCRIPTION_TEXT_BOX='tree_description'
  TREE_VIEW_LINK='link=Tree view'
  HIERARCHY_VIEW_LINK='link=Hierarchy view'
  TREE_CONFIGURATION_VIEW='tree_configuration_view'
  
  def warning_box_id
    class_locator('warning-box')
  end
  
  def add_card_type_node_id(type_node_number)
    "#{class_locator('add-button', type_node_number)}"
  end
  
  def remove_card_type_node_id(type_node_number)
    "#{class_locator('remove-button', type_node_number)}"
  end
  
  def select_type_option_on_tree_node_id(type_name,type_node_number)
    "type_node_#{type_node_number}_container_option_#{type_name}"
  end
  
  
  
  def select_type_on_tree_node_id(type_node_number)
    "#{class_locator('select-type', type_node_number)}"
  end
  
  def card_type_dropdown_element(type_node_number)
      "type_node_#{type_node_number}_container_drop_down"
  end
  
  def relationship_name_textbox_on_tree_configuration(type_node_number)   
    "card_types[#{type_node_number}][relationship_name]"
  end
  
  def edit_relationship_link_id(options)
    "edit_relationship_#{options[:type_node_number]}_link"
  end
end
