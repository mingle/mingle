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

module TransitionManagementPageId
  
  NULL_VALUE = '(not set)'
  CARD_TYPES_FILTER_LABEL='card-types-filter'
  SHOW_WORKFLOW_FOR_LABEL='property-definitions-of-card-type-filter'
  CREATE_NEW_CARD_TRANSITION_LINK='link=Create new card transition'
  CREATE_TRANSITION_TOP_BUTTON='create_transition_top'
  SAVE_TRANSITION_TOP_BUTTON='save_transition_top'
  TRANSITION_NAME_FIELD='transition_name'
  CANCEL_LINK="link=Cancel"
  EDIT_CARD_TYPE_NAME_DROP_LINK='edit_card_type_name_drop_link'
  EDIT_CARD_TYPE_NAME_DROP_DOWN='edit_card_type_name_drop_down'
  TYPE_PROPERTY_ID='type'
  REQUIRES_PROPERTY_ID='requires'
  SETS_PROPERTY_ID='sets'
  TEXT_PROPERTY_DEFINITION_HTML_ID_PREFIX='TextPropertyDefinition'
  TRANSITION_REQUIRE_COMMENT_CHECKBOX="transition_require_comment"
  ONLY_SELECTED_MEMBERS_RADIO_BUTTON='show-members'
  ONLY_SELECTED_USER_GROUPS_RADIO_BUTTON='show-groups'
  STORY_POINTS_PROPERTY_DROP_DOWN='EnumeratedPropertyDefinition'
  DATE_PROPERTY_DEFINITION_DROP_DOWN='DatePropertyDefinition'
  TEXT_PROPERTY_DEFINITION_DROP_DOWN='TextPropertyDefinition'
  CREATE_NEW_TRANSITION_WORKFLOW_BUTTON="Create new transition workflow"
  GENERATE_TRANSITION_WORKFLOW_LINK="link=Generate transition workflow"
  CARD_TYPE_ID='card_type_id'
  PROPERTY_DEFINITION_ID='property_definition_id'
  GENERATE_WORKFLOW_TOP_ID ='generate-workflow-top'
  GENERATE_WORKFLOW_BOTTOM_ID='generate-workflow-bottom'
  
  TRANSITION_PAGE_CONTENT_ID = 'content-simple'
  SETS_PROPERTIES_CARD_TYPE_ID = "sets-properties-card-type"
  NO_TRANSITION_MESSAGE = 'no-transition-message'
  
  def tree_belonging_property_drop_link(tree) 
    "tree_belonging_property_definition_#{tree.id}_sets_drop_link"
  end
  
  def tree_belonging_property_drop_down(tree)
    "tree_belonging_property_definition_#{tree.id}_sets_drop_down"
  end
  
  def tree_belonging_property_option(tree,option)
    "tree_belonging_property_definition_#{tree.id}_sets_option_#{option}"
  end
  
  def transition_element_id(transition)
    "transition-#{transition.id}"
  end
  
  def delete_transition(transition)
    "delete_#{transition.id}"
  end
  
  def edit_transition(transition)
    "#transition-#{transition.id} .edit-transition"
  end
  
  def edit_card_type_name_option(type)
    "edit_card_type_name_option_#{type}"
  end
  
  # todo for #14979: make the following 4 methods consistent with methods in property_editors_page_ids.rb
  def property_drop_link(property,widget_name)
    "#{property.html_id}_#{widget_name}_drop_link"
  end
  
  def property_def_with_hidden_requires_drop_link_id(property_name) 
    "#{property_def_with_hidden(property_name).html_id}_requires_drop_link"
  end
  
  def property_def_with_hidden_sets_drop_link_id(property_name)
    "#{property_def_with_hidden(property_name).html_id}_sets_drop_link"
  end

  def property_drop_down(property,widget_name)
    "#{property.html_id}_#{widget_name}_drop_down"
  end
  
  def value_link(value)
    "link=#{value}"
  end
  
  def property_value_option(property,widget_name,value)
    "#{property.html_id}_#{widget_name}_option_#{value}"
  end
  
  def checkbox_to_add_team_members_to_transition(team_member)
    "user_prerequisites_#{team_member.id}"
  end
  
  def checkbox_to_add_groups_to_transition(group)
    "group_prerequisites_#{group.id}"
  end
  
  def no_transitions_presnet_id
    class_locator('no-transition-message')
  end
  
  def property_sets_action_adding_value(property)
    "#{property.html_id}_sets_action_adding_value"
  end
  
  def property_requires_action_adding_value(property) 
    "#{property.html_id}_requires_action_adding_value"
  end
  
end
