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

module TransitionPropertyEditorHelper
  
  SHARED_PROPERTY_EDITOR = PropertyEditorHelper::SHARED_PROPERTY_EDITOR

  def transition_prerequisite_card_type_property_editor(transition)
    prop_def = Project.card_type_definition
    {:partial => SHARED_PROPERTY_EDITOR, 
      :locals => { :prop_def => prop_def, :options => {
        :html_id_prefix => "edit_#{prop_def.html_id}", 
        :onchange => "var selection = arguments[0]; window.cardTypePropertiesController.changeCardTypeEditor('cp' + selection.value); window.cardTypeTreePropertiesController.updateTreeOptions(selection.value);",
        :field_name => "transition[card_type_name]", 
        :value => @transition.card_type_name,
        :select_options => options_for_droplist(prop_def).unshift(['(any)', '']),
        :support_inline_edit => false
    }}}
  end
  
  def transition_prerequisite_property_editor(prop_def, transition)
    return {:text => ""} if prop_def.is_a?(TreeBelongingPropertyDefinition)
    drop_options = droplist_options_for_transition_prerequisite(transition, prop_def)
    value = transition.value_required_for(prop_def)
    
    if PropertyType::CardType === prop_def.property_type
      chosen_option = drop_options.detect { |option| option.last == value }
      display_value = chosen_option ? chosen_option.flatten.first : PropertyValue.create_from_db_identifier(prop_def, value).display_value
    elsif prop_def.is_a?(UserPropertyDefinition)
      display_value = prop_def.values.find{|user| user.id == value.to_i}.try(:name)
    else
      display_value = initial_value_for_drop_list(value, drop_options).first
    end
    
    {:partial => SHARED_PROPERTY_EDITOR, 
      :locals => { :prop_def => prop_def, :options => {
        :html_id_prefix => "#{prop_def.html_id}_requires", 
        :field_name => "requires_properties[#{prop_def.field_name}]", 
        :display_value => display_value,
        :value => value,
        :select_options => drop_options,
        :support_inline_edit => prop_def.support_inline_creating?,
        :support_filter      => prop_def.support_filter?,
        :new_value_message => new_value_dropdown_message(prop_def),
        :appended_actions => droplist_appended_actions(:edit, prop_def),
        :input_partial => 'shared/enumerated_property_definition_input',
        :hidden_highlight => prop_def.hidden?
    }}}
  end

  
  def transition_action_property_editor(prop_def, transition)
    return transition_action_tree_belongings_property_editor(prop_def, transition) if prop_def.is_a?(TreeBelongingPropertyDefinition)
    return transition_action_formula_property_editor(prop_def, transition) if prop_def.calculated?

    drop_options = droplist_options_for_transition_action(transition, prop_def)
    value = transition.value_set_for(prop_def)
    
    tree_options = {}
    if PropertyType::CardType === prop_def.property_type
      chosen_option = drop_options.detect { |option| option.last == value }
      display_value = chosen_option ? chosen_option.flatten.first : PropertyValue.create_from_db_identifier(prop_def, value).display_value
      
      if prop_def.is_a?(TreeRelationshipPropertyDefinition)
        tree_options = {
          :input_partial => 'shared/tree_relationship_property_definition_with_disable_input',
          :onchange => "RelationshipPropertiesController.instance.onChange('#{prop_def.html_id}_sets')"
        }
      end
    elsif prop_def.is_a?(UserPropertyDefinition)
      display_value = prop_def.values.find{|user| user.id == value.to_i}.try(:name)
    else
      display_value = initial_value_for_drop_list(value, drop_options).first
    end
    {:partial => SHARED_PROPERTY_EDITOR, 
     :locals => { :prop_def => prop_def, :options => {
        :html_id_prefix => "#{prop_def.html_id}_sets",
        :field_name => "sets_properties[#{prop_def.field_name}]", 
        :display_value => display_value,
        :value => value,
        :select_options => drop_options,
        :support_inline_edit => prop_def.support_inline_creating?,
        :support_filter      => prop_def.support_filter?,
        :new_value_message => new_value_dropdown_message(prop_def),
        :input_partial => 'shared/enumerated_property_definition_input',
        :appended_actions => droplist_appended_actions(:edit, prop_def),
        :hidden_highlight => prop_def.hidden?
     }.merge(tree_options)}}
  end
  
  def transition_action_tree_belongings_property_editor(prop_def, transition)
    drop_options = droplist_options_for_tree_belongings_transition_action(transition, prop_def)
    value = transition.value_set_for(prop_def)
    display_value = initial_value_for_drop_list(value, drop_options).first
    {:partial => SHARED_PROPERTY_EDITOR,
      :locals => { :prop_def => prop_def, :options => {
        :html_id_prefix => "#{prop_def.html_id}_sets",
        :field_name => "sets_tree_belongings[#{prop_def.field_name}]", 
        :display_value => display_value,
        :value => value,
        :select_options => drop_options,
        :support_inline_edit => false,
        :input_partial => 'shared/enumerated_property_definition_with_disable_input',
        :hidden_highlight => prop_def.hidden?,
        :onchange => "RelationshipPropertiesController.instance.onChange('#{prop_def.html_id}_sets')",
        :add_droplists_to_array => true
    }}}
  end
  
  def transition_action_formula_property_editor(prop_def, transition)
    drop_options = [['(calculated)', PropertyValue::IGNORED_IDENTIFIER]]
    {:partial => SHARED_PROPERTY_EDITOR, 
     :locals => { :prop_def => prop_def, :options => {
        :html_id_prefix => "#{prop_def.html_id}_sets",
        :display_value => '(calculated)',
        :input_partial => 'shared/readonly_property_value',
        :hidden_highlight => prop_def.hidden?,
     }}}  
  end
  
  
  def transition_popup_property_editor(prop_def, transition, card, field_name, required_properties)
    is_required_property = required_properties.include?(prop_def)
    select_options = transition_popup_property_editor_options(prop_def, is_required_property)
    property_value = card.property_value(prop_def)
    display_value = if !property_value.db_identifier && is_required_property
      "(Select...)"
    else
      property_value.display_value
    end
    parent_constraints_fields = card ? prefilter_fields(prop_def, CardsHelper::TRANSITION_HTML_ID_PREFIX) : []
    options = {:partial => SHARED_PROPERTY_EDITOR, 
     :locals => { :prop_def => prop_def, :options => {
       :html_id_prefix => prop_def.html_id + '_sets',
       :onchange => "TransitionPopupForm.instance.onChange()", 
       :field_name => field_name,
       :display_value => display_value,
       :value =>  property_value.db_identifier,
       :select_options => select_options,
       :support_inline_edit => prop_def.support_inline_creating?,
       :support_filter      => prop_def.support_filter?,
       :new_value_message => new_value_dropdown_message(prop_def),
       :appended_actions => droplist_appended_actions(:edit, prop_def, parent_constraints_fields),
       :input_required => is_required_property
     }}}

     options[:locals][:options].merge!(:input_partial => 'shared/enumerated_property_definition_input') if show_input_partial?(prop_def)

     if prop_def.is_a?(DatePropertyDefinition)
       options[:locals][:options].merge!(:input_partial => 'shared/date_property_definition_input_with_dropdown', :support_inline_edit => true)
     end
     options
  end
  
  protected
  
  def show_input_partial?(property_definition)
    !(property_definition.is_a?(TextPropertyDefinition) && property_definition.project_variables.size == 0)
  end
end
