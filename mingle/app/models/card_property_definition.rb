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

class CardPropertyDefinition < AssociationPropertyDefinition  
  belongs_to :valid_card_type, :class_name => 'CardType', :foreign_key => 'valid_card_type_id'
  
  def reference_class
    Card
  end
    
  def property_type
    PropertyType::CardType.new(project)
  end

  def validate_card(card)
    value_card = value(card)
    raise "cannot find card with id #{db_identifier(card)}" if db_identifier(card) && !value(card)
    card.errors.add_to_base("you cannot assign a card to itself") if value_card == card
    card.errors.add_to_base("only #{valid_card_type.name} type is allowed for #{name}") unless valid_card_type == value_card.card_type
  end
  
  def all_db_identifiers
    valid_card_type.card_ids
  end

  def values
    valid_card_type.cards
  end
  
  def indexable_value(card)
    nil
  end
  
end
