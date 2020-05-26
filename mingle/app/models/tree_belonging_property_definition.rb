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

class TreeBelongingPropertyDefinition
  WITH_CHILDREN_VALUE = ':with_children'
  JUST_THIS_CARD_VALUE = ':just_this_card'
  
  WITH_CHILDREN_TEXT = '(remove card and its children from this tree)'
  JUST_THIS_CARD_TEXT = '(remove card from this tree)'
  
  TEXT_AND_VALUES = { WITH_CHILDREN_VALUE => WITH_CHILDREN_TEXT, JUST_THIS_CARD_VALUE => JUST_THIS_CARD_TEXT}
  JUST_THIS_CARD_PAIR = [JUST_THIS_CARD_TEXT, JUST_THIS_CARD_VALUE]
  
  def initialize(tree_config, property_type = PropertyType::BooleanType.new)
    @tree_config = tree_config
    @property_type = property_type
  end

  def tooltip
    name
  end

  def project
    Project.current
  end
  
  def ==(other)
    other.is_a?(TreeBelongingPropertyDefinition) && (tree_configuration_id == other.tree_configuration_id)
  end
  
  def name
    @tree_config.name
  end
  
  def property_type
    @property_type
  end
  
  def property_value_on(card)
    PropertyValue.new(self, @tree_config.include_card?(card))
  end
  
  def sort_value(property_value)
    property_type.sort_value(property_value)
  end
  
  def tree_special?
    true
  end
  
  def groupable?
    false
  end
  
  def global?
    false
  end
  
  def nullable?
    false
  end
  
  def field_name
    tree_configuration_id
  end
  
  def hidden?
    false
  end
  
  def numeric?
    false
  end
  
  def calculated?
    false
  end
  
  def update_card(card, value, options={:just_change_version => false})
    if value && @tree_config.invalid_card_type?(card)
      card.register_after_save_callback { @tree_config.add_card(card)}
    else
      if options[:just_change_version]
        card.register_remove_card_after_save_callback_without_creating_new_version(@tree_config)
      else
        card.register_after_save_callback { @tree_config.remove_card(card, nil) }
      end
    end
  end

  def transition_only_for_updating_card?(card=nil)
    false
  end
  def transition_only?
    false
  end

  def tree_configuration_id
    @tree_config.id
  end
  
  def tree_configuration
    @tree_config
  end
  
  def html_id
    "tree_belonging_property_definition_#{@tree_config.id}"
  end
  
  def name_values
    [JUST_THIS_CARD_PAIR, [WITH_CHILDREN_TEXT, WITH_CHILDREN_VALUE]]
  end
end
