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

class RemoveFromTreeTransitionAction < TransitionAction
  belongs_to :tree_configuration, :foreign_key => "target_id"
  
  def self.create_with_children_action(options)
    RemoveFromTreeTransitionAction.new(:executor => options[:executor], :tree_configuration => options[:tree], :value => TreeBelongingPropertyDefinition::WITH_CHILDREN_VALUE)
  end
  
  def self.create_without_children_action(options)
    RemoveFromTreeTransitionAction.new(:executor => options[:executor], :tree_configuration => options[:tree], :value => TreeBelongingPropertyDefinition::JUST_THIS_CARD_VALUE)
  end
  
  def property_definition
    TreeBelongingPropertyDefinition.new(tree_configuration, PropertyType::TreeBelongingType.new)
  end
  
  def execute(card, options={})
    with_children? ? tree_configuration.remove_card_and_its_children(card, :do_not_persist_parent => true) : tree_configuration.remove_card(card, nil, :do_not_persist => true)
  end
  
  def target_property
    PropertyValue.new(property_definition, with_children? ? TreeBelongingPropertyDefinition::WITH_CHILDREN_VALUE : TreeBelongingPropertyDefinition::JUST_THIS_CARD_VALUE)
  end
  
  def uses?(property_definition)
    false
  end
  
  def uses_tree?(configuration)
    configuration == self.tree_configuration
  end
  
  def validate
    card_type = self.executor.card_type
    if card_type.nil?
      self.errors.add_to_base("Tree card type must be present when removing cards from trees") 
    elsif !tree_configuration.include_card_type?(card_type)
      self.errors.add_to_base("Card type #{card_type.name.bold} must be a valid type for the tree #{tree_configuration.name.bold}")
    end
  end
  
  def display_value
    self.target_property.display_value
  end
  
  def display_name
    self.target_property.name
  end
  
  def to_s
    "Removes card from tree #{tree_configuration.name}".tap do |str|
      str += " (with children)" if with_children?
    end
  end
  
  private
  
  def with_children?
    self.value == TreeBelongingPropertyDefinition::WITH_CHILDREN_VALUE
  end
end
