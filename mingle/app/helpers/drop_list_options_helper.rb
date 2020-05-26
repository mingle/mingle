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

module DropListOptionsHelper
  module CardFilterOptions
    def options_for_droplist_for_cards_filter(property_def, options = property_def.card_filter_options)
      options = plv_options_for_droplist(property_def) + options
      options_for_droplist_for_cards_filter_without_plv(property_def, options)
    end

    def options_for_droplist_for_cards_filter_without_plv(property_def, options = property_def.card_filter_options)
      options.unshift PropertyValue::NOT_SET_VALUE_PAIR if property_def && property_def.nullable?
      options.unshift [PropertyValue::ANY, PropertyValue::IGNORED_IDENTIFIER]
    end
  end

  module TransitionOptions
    def droplist_options_for_transition_prerequisite(transition, property_definition)
      options = [[PropertyValue::ANY, PropertyValue::IGNORED_IDENTIFIER]]
      options << transition_value_option(property_definition, transition.value_required_for(property_definition))
      options << PropertyValue::SET_VALUE_PAIR
      options << PropertyValue::NOT_SET_VALUE_PAIR
      options.concat plv_and_name_values_options(property_definition)
      options.compact
    end

    def droplist_options_for_transition_action(transition, property_definition)
      options = [[PropertyValue::NO_CHANGE, PropertyValue::IGNORED_IDENTIFIER]]
      options << transition_value_option(property_definition, transition.value_set_for(property_definition))
      options.concat [PropertyValue::NOT_SET_VALUE_PAIR, [Transition::USER_INPUT_OPTIONAL, Transition::USER_INPUT_OPTIONAL], [Transition::USER_INPUT_REQUIRED, Transition::USER_INPUT_REQUIRED]]
      options.concat plv_and_name_values_options(property_definition)
      options.compact
    end

    def transition_popup_property_editor_options(prop_def, required=false)
      return plv_options_for_droplist(prop_def) if required && prop_def.property_type.instance_of?(PropertyType::CardType)

      options = required ? [] : [PropertyValue::NOT_SET_VALUE_PAIR]
      options.concat plv_and_name_values_options(prop_def)
    end

    def droplist_options_for_tree_with_cascading_delete
      [
        [PropertyValue::NO_CHANGE, PropertyValue::IGNORED_IDENTIFIER],
        [TreeBelongingPropertyDefinition::JUST_THIS_CARD_TEXT, TreeBelongingPropertyDefinition::JUST_THIS_CARD_VALUE],
        [TreeBelongingPropertyDefinition::WITH_CHILDREN_TEXT, TreeBelongingPropertyDefinition::WITH_CHILDREN_VALUE]
      ]
    end

    def droplist_options_for_tree_without_cascading_delete
      [
        [PropertyValue::NO_CHANGE, PropertyValue::IGNORED_IDENTIFIER],
        [TreeBelongingPropertyDefinition::JUST_THIS_CARD_TEXT, TreeBelongingPropertyDefinition::JUST_THIS_CARD_VALUE]
      ]
    end

    def droplist_options_for_tree_belongings_transition_action(transition, property_definition)
      options_for_droplist_with_ignore(property_definition, PropertyValue::NO_CHANGE)
    end

    private
    def transition_value_option(property_definition, transition_value)
      return if [PropertyValue::IGNORED_IDENTIFIER, PropertyValue::SET_VALUE].concat(Transition::USER_INPUT_VALUES).include?(transition_value) || transition_value.blank?

      case property_definition
      when TextPropertyDefinition
        property_definition.property_value_from_db(transition_value).db_value_pair
      when FormulaPropertyDefinition
        [transition_value, transition_value]
      end
    end
  end

  include TransitionOptions
  include CardFilterOptions

  def options_for_lane_droplist(prop_def)
    base_options(prop_def).concat prop_def.lane_values
  end

  def options_for_droplist(prop_def)
    base_options(prop_def).concat plv_and_name_values_options(prop_def)
  end

  def options_for_droplist_with_ignore(prop_def, ignore_display_name, droplist_options = options_for_droplist(prop_def))
    droplist_options.unshift([ignore_display_name, PropertyValue::IGNORED_IDENTIFIER])
  end

  private

  def base_options(prop_def)
    [].tap do |empty_options|
      if prop_def.nullable?
        empty_options << PropertyValue::NOT_SET_VALUE_PAIR
      end
    end
  end

  def plv_options_for_droplist(prop_def)
    return [] unless prop_def.respond_to?(:project_variables)
    options = prop_def.project_variables.collect { |plv| [plv.display_name, plv.display_name] }.smart_sort_by(&:first)
    if prop_def.class.respond_to?(:current)
      options << prop_def.class.current
    end
    options
  end

  def plv_and_name_values_options(prop_def)
    options = []
    options.concat plv_options_for_droplist(prop_def)
    options.concat prop_def.name_values
  end

end
