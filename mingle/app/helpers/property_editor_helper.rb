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

module PropertyEditorHelper
  SHARED_PROPERTY_EDITOR = 'shared/property_editor'
  QUICK_ADD_PROPERTY_EDITOR = "quick_add_cards/property_editor"

  include TransitionPropertyEditorHelper

  def property_editor_locals(property, card, mode, opts={})
    {
      :card     => card,
      :property => property,
      :mode     => mode,
      :attrs    => property_editor_attributes(property, card, opts)
    }
  end

  def property_editor_attributes(property_definition, card, opts={})
    property_value = card.property_value(property_definition)
    read_only = property_definition.calculated? || property_definition.transition_only_for_updating_card?(card) || hidden_protected(property_definition, User.current)
    value = property_definition.calculated? ? property_value.db_identifier : property_value.field_value

    attrs = {
      :id => property_definition.html_id.downcase,
      :class => read_only ? "transition-hidden-protected" : "property-value-widget"
    }

    editor_config = {
      :value               => value.nil? ? "" : value,
      :display_value       => property_value.display_value,
      :read_only           => read_only,
      :hidden_property     => property_definition.hidden?,
      :inline_text_editor  => property_definition.is_a?(TextPropertyDefinition) && property_definition.project_variables.size == 0
    }

    editor_config.merge!({
      :inline_add_option_action_title   => new_value_dropdown_message(property_definition),
      :appended_actions    => droplist_appended_actions(:edit, property_definition, prefilter_fields(property_definition, nil)),
      :select_options      => options_for_droplist(property_definition),
      :support_inline_edit => property_definition.is_a?(DatePropertyDefinition) || property_definition.support_inline_creating?,
      :support_filter      => property_definition.support_filter?,
      :numeric             => property_definition.numeric?,
      :onchange            => opts[:onchange]
    }) unless read_only

    editor_config.merge!(:date_format => card.project.date_format) if property_definition.is_a?(DatePropertyDefinition)

    if property_definition.calculated? && property_definition.stale?(card)
      attrs[:class] << " stale-calculation"
      attrs.merge!(:title => "This value may be out of date. Refresh this page to view updated aggregates.")
    end

    attrs.merge(html_data_attrs(editor_config)).merge(opts)
  end

  def card_type_editor_attributes(card, mode, opts={})
    property_definition = Project.card_type_definition
    property_value = card.property_value(property_definition)

    attrs = {
      :id => property_definition.html_id.downcase,
      :class => "property-value-widget"
    }

    editor_config = {
      :value               => property_value.field_value,
      :display_value       => property_value.display_value,
      :select_options      => options_for_droplist(property_definition),
      :support_inline_edit => property_definition.support_inline_creating?,
      :support_filter      => property_definition.support_filter?,
      :inline_text_editor  => false
    }

    if mode == "edit"
      editor_config[:onchange] = remote_function(:url => {:action => 'refresh_properties', :project_id => @project.identifier, :card => card.id, :tab => @tab_name},
                                 :with => "Form.serialize($('card-type-properties-container').up('form'))",
                                 :before => "$('spinner').show(); linkHandler.disableLinks();",
                                 :complete => "$('spinner').hide(); linkHandler.enableLinks();"
                               )
    else
      editor_config[:onchange] = "InputingContexts.push(new LightboxInputingContext()); InputingContexts.update($('change_card_type_confirmation_actions_container').innerHTML);"
    end

    attrs.merge(html_data_attrs(editor_config).merge(opts))
  end

  def html_data_attrs(hash)
    hash.inject({}) do |result, pair|
      k = "data-#{pair[0].to_s.dasherize}"
      v = pair[1]
      v = v.to_json unless v.is_a?(String) || v.is_a?(Symbol) || v.is_a?(BigDecimal)
      result[k] = v
      result
    end
  end

  def card_relationship_link(property_value, mode)
    return unless mode == CardsHelper::CARD_SHOW_MODE

    url_params = { :controller => "cards", :action => "show", :number => property_value.url_identifier }
    html_attrs = {
      :class => 'card-relationship-link',
      :title => 'Click to go to this card',
      :style => "float:none;"
    }
    html_attrs.merge!(:style => "display: none") if property_value.field_value.blank?

    link_to("", url_params, html_attrs)
  end

  def property_display_name(property_definition)
    name = truncate_words(property_definition.name, 40)
    name += " tree" if property_definition.is_a? TreeBelongingPropertyDefinition
    "#{name}:"
  end

  def property_field_name(property_definition)
    "properties[#{property_definition.field_name}]"
  end

  def bulk_edit_property_editor(prop_def, card_selection)
    return bulk_edit_formula_property_editor(prop_def, card_selection) if prop_def.calculated?

    options = {
     :html_id_prefix      => "bulk_#{prop_def.html_id}".downcase,
     :onchange            => "SetChangedProperty.update(#{prop_def.name.to_json}); $('bulk-set-properties-form').onsubmit()",
     :field_name          => property_field_name(prop_def),
     :display_value       => card_selection.display_value_for(prop_def),
     :value               => card_selection.value_identifier_for(prop_def),
     :select_options      => options_for_droplist(prop_def),
     :is_mixed_value      => card_selection.mixed_value?(prop_def),
     :support_inline_edit => prop_def.support_inline_creating?,
     :support_filter      => prop_def.support_filter?,
     :appended_actions    => droplist_appended_actions(:edit, prop_def, prefilter_fields(prop_def, 'bulk')),
     :read_only           => prop_def.transition_only_for_updating_card?
    }
    options.merge!(:input_partial => 'shared/enumerated_property_definition_input') if show_input_partial?(prop_def)

    assemble_date_property_definition_options(prop_def, options)
  end


  def bulk_edit_formula_property_editor(prop_def, card_selection)
    {:partial => SHARED_PROPERTY_EDITOR,
      :locals => { :prop_def => prop_def, :options => {
        :input_partial       => "shared/text_property_definition_input",
        :html_id_prefix      => "bulk_#{prop_def.html_id}".downcase,
        :field_name          => property_field_name(prop_def),
        :display_value       => card_selection.display_value_for(prop_def),
        :value               => card_selection.value_identifier_for(prop_def),
        :select_options      => options_for_droplist(prop_def),
        :is_mixed_value      => card_selection.mixed_value?(prop_def),
        :support_inline_edit => prop_def.support_inline_creating?,
        :support_filter      => prop_def.support_filter?,
        :read_only           => true
      }}}
  end

  def bulk_edit_card_type_property_editor(card_selection)
    prop_def = Project.card_type_definition
    {:partial => SHARED_PROPERTY_EDITOR,
      :locals => { :prop_def => prop_def, :options => {
       :html_id_prefix      => "bulk_edit_card_type",
       :onchange            => "SetChangedProperty.update(#{prop_def.name.to_json});InputingContexts.push(new LightboxInputingContext()); InputingContexts.update($('change_card_type_confirmation_actions_container').innerHTML);",
       :field_name          => "properties[#{prop_def.name}]",
       :display_value       => card_selection.display_value_for(prop_def),
       :value               => card_selection.value_identifier_for(prop_def),
       :select_options      => prop_def.card_type_options,
       :is_mixed_value      => card_selection.mixed_value?(prop_def),
       :support_inline_edit => prop_def.support_inline_creating?,
       :support_filter      => prop_def.support_filter?,
       :read_only           => prop_def.transition_only_for_updating_card?
      }}}
  end

  def card_edit_formula_property_editor(prop_def, card, html_id_prefix)
    property_value = card.property_value(prop_def)
    {:partial => SHARED_PROPERTY_EDITOR,
     :locals => { :prop_def => prop_def, :options => {
       :input_partial       => "shared/text_property_definition_input",
       :html_id_prefix      => "#{html_id_prefix}_#{prop_def.html_id}".downcase,
       :field_name          => property_field_name(prop_def),
       :display_value       => prop_def.value(card),
       :value               => property_value.db_identifier,
       :stale               => prop_def.stale?(card),
       :select_options      => options_for_droplist(prop_def),
       :support_inline_edit => prop_def.support_inline_creating?,
       :support_filter      => prop_def.support_filter?,
       :read_only           => true,
       :hidden_highlight    => prop_def.hidden?
     }}}
  end

  def card_edit_property_editor(prop_def, card, onchange, html_id_prefix, quick_add=false)
    mode = {}
    if quick_add
      mode[:partial] = QUICK_ADD_PROPERTY_EDITOR
    end
    return card_edit_formula_property_editor(prop_def, card, html_id_prefix).merge!(mode) if prop_def.calculated?
    property_value = card.property_value(prop_def)
    options = {
       :html_id_prefix      => "#{html_id_prefix}_#{prop_def.html_id}".downcase,
       :field_name          => property_field_name(prop_def),
       :display_value       => property_value.display_value,
       :value               => property_value.field_value,
       :new_value_message   => new_value_dropdown_message(prop_def),
       :appended_actions    => droplist_appended_actions(:edit, prop_def, prefilter_fields(prop_def, html_id_prefix)),
       :onchange            => onchange,
       :select_options      => options_for_droplist(prop_def),
       :support_inline_edit => prop_def.support_inline_creating?,
       :support_filter      => prop_def.support_filter?,
       :read_only           => prop_def.transition_only_for_updating_card?(card) || hidden_protected(prop_def, User.current),
       :hidden_highlight    => prop_def.hidden?,
       :hidden_property     => prop_def.hidden?,
       :property_value      => property_value
     }

     if prop_def.is_a?(TextPropertyDefinition) && prop_def.project_variables.size != 0
       options.merge!(:input_partial => 'shared/enumerated_property_definition_input').merge!(mode)
     end

     assemble_date_property_definition_options(prop_def, options).merge!(mode)
  end

  def hidden_protected(prop_def, user)
    prop_def.hidden? && !@project.admin?(user)
  end

  def card_defaults_property_editor(prop_def, card_defaults, onchange, html_id_prefix, readonly = false)
    return card_defaults_formula_property_editor(prop_def, card_defaults, html_id_prefix) if prop_def.calculated?
    property_value = card_defaults.property_value_for(prop_def.name) || PropertyValue.create_from_db_identifier(prop_def, nil)
    drop_options = options_for_droplist(prop_def)
    common_local_options = {
      :html_id_prefix      => "#{html_id_prefix}_#{prop_def.html_id}".downcase,
      :onchange            => onchange,
      :field_name          => property_field_name(prop_def),
      :display_value       => property_value.display_value,
      :value               => property_value.db_identifier,
      :select_options      => drop_options,
      :new_value_message   => new_value_dropdown_message(prop_def),
      :support_inline_edit => prop_def.support_inline_creating?,
      :support_filter      => prop_def.support_filter?,
      :hidden_highlight    => prop_def.hidden?,
      :hidden_property     => false,
      :read_only           => readonly
    }
    extra_options = {}

    extra_options.merge!(:input_partial => 'shared/enumerated_property_definition_input') if show_input_partial?(prop_def)

    if prop_def.is_a?(TreeRelationshipPropertyDefinition)
      extra_options.merge!({
        :onchange => "RelationshipPropertiesController.instance.onChange('#{common_local_options[:html_id_prefix]}'); #{onchange}",
        :input_partial => 'shared/tree_relationship_property_definition_with_disable_input'
      })
    end

    extra_options.merge!({:appended_actions => droplist_appended_actions(:edit, prop_def)})

    {:partial => SHARED_PROPERTY_EDITOR,
     :locals => {
       :prop_def => prop_def,
       :options => common_local_options.merge(extra_options)
     }}
  end

  def card_readonly_property_editor(prop_def, card, onchange, html_id_prefix)
    return card_readonly_formula_property_editor(prop_def, card, html_id_prefix) if prop_def.calculated?
    property_value = card.property_value(prop_def)
    {:partial => SHARED_PROPERTY_EDITOR,
     :locals => { :prop_def => prop_def, :options => {
       :html_id_prefix      => "#{html_id_prefix}_#{prop_def.html_id}".downcase,
       :field_name          => property_field_name(prop_def),
       :display_value       => property_value.display_value,
       :value               => property_value.db_identifier,
       :onchange            => onchange,
       :select_options      => options_for_droplist(prop_def),
       :support_inline_edit => prop_def.support_inline_creating?,
       :support_filter      => prop_def.support_filter?,
       :read_only           => true
     }}}
  end

  def card_readonly_formula_property_editor(prop_def, card, html_id_prefix)
    {:partial => SHARED_PROPERTY_EDITOR,
     :locals => { :prop_def => prop_def, :options => {
       :html_id_prefix   => "#{html_id_prefix}_#{prop_def.html_id}".downcase,
       :input_partial    => "shared/text_property_definition_input",
       :field_name       => property_field_name(prop_def),
       :display_value    => '(calculated)',
       :value            => '(calculated)',
       :hidden_highlight => prop_def.hidden?,
       :read_only        => true
     }}}
  end
  alias :card_defaults_formula_property_editor :card_readonly_formula_property_editor

  def history_filter_property_editor(prop_def, html_id_prefix, onchange, field_name, filters, with_any_change)
    dropdown_options = [PropertyValue::NOT_SET_VALUE_PAIR] + prop_def.name_values
    dropdown_options.unshift(PropertyValue::ANY_CHANGE_PAIR) if with_any_change
    select_options   = options_for_droplist_with_ignore(prop_def, PropertyValue::ANY, dropdown_options)
    value            = filters.find_ignore_case(prop_def.name) || PropertyValue::IGNORED_IDENTIFIER
    chosen_option    = [PropertyValue::ANY_VALUE_PAIR, PropertyValue::ANY_CHANGE_PAIR, PropertyValue::NOT_SET_VALUE_PAIR].detect { |option| option.last == value }
    display_value    = chosen_option ? chosen_option.flatten.first : PropertyValue.create_from_db_identifier(prop_def, value).display_value
    { :partial => SHARED_PROPERTY_EDITOR,
      :locals => { :prop_def => prop_def, :options =>  {
        :html_id_prefix      => html_id_prefix + prop_def.html_id,
        :prop_def            => prop_def,
        :onchange            => onchange,
        :field_name          => field_name + "[#{prop_def.name}]",
        :display_value       => display_value,
        :value               => value,
        :select_options      => select_options,
        :support_inline_edit => false,
        :support_filter      => prop_def.support_filter?,
        :appended_actions    => droplist_appended_actions(:history_filter, prop_def),
        :input_partial       => 'shared/enumerated_property_definition_input'
    }}}
  end

  def prop_input_partial(prop_def)
    "shared/#{prop_def.class.name.underscore}_input"
  end

  def property_value_for_inline_editor(name, is_mixed_value = false)
    if (is_mixed_value || name.blank?)
      return ''
    else
      return name
    end
  end

  def prefilter_fields(prop_def, field_prefix, field_suffix='field')
    return [] unless prop_def.is_a?(TreeRelationshipPropertyDefinition)
    results = []
    prop_def.tree_configuration.relationship_map.each_before(prop_def.valid_card_type) do |pd|
      results << { 'parent' => pd.name, 'field_id' => [field_prefix, pd.html_id, field_suffix].compact.join("_") }
    end
    results
  end

  protected

  def assemble_date_property_definition_options(prop_def, options)
    options.merge!(:input_partial => 'shared/date_property_definition_input_with_dropdown', :support_inline_edit => true) if prop_def.is_a?(DatePropertyDefinition)
    {
      :partial => SHARED_PROPERTY_EDITOR,
      :locals => {
        :prop_def => prop_def,
        :options => options
      }
    }
  end


end
