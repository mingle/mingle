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

module EditAggregatePropertyPageId
  EDIT_TREE_STRUCTURE_LINK = "link=Edit tree structure"
  AGGREGARE_PROPERTY_NAME_TEXT_BOX = 'aggregate_property_definition_name'
  AGGREGATE_PROPERTY_CONDITION_TEXT_BOX = 'aggregate_property_definition_aggregate_condition'
  AGGREGATE_PROPERTY_TYPE_DROPDOWN = 'aggregate_property_definition_aggregate_type'
  AGGREGATE_PROPERTY_SCOPE_CARD_TYPE_DROPDOWN = 'aggregate_property_definition_aggregate_scope_card_type_id'
  AGGREGATE_PROPERTY_AGGREGATE_TARGET_DROPDOWN = 'aggregate_property_definition_aggregate_target_id'
  COMMIT_LINK ='commit'
  AGGREGATE_LIST_ID='aggregate_list'
  
  def edit_aggregare_property_id(aggregate_property)
    "edit-aggregate-property-#{aggregate_property.id}"
  end
  
  def edit_aggregate_link_id(card_type_node)
    "edit-aggregates-link-#{card_type_node.id}"
  end
  
  def delete_aggregate_property_id(aggregate_property)
    "delete-aggregate-property-#{aggregate_property.id}"
  end
  
  def aggregate_description_id(index)
  "aggregate_description_#{index}"
  end
end
