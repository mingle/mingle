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

class CardTree::CardNode < CardTree::Node
  acts_like :card, :keep_methods => [:to_json, :to_json_properties, :returning, :tap]
  attr_reader :card

  def initialize(card, tree_config, card_tree, partial_tree_card_count, full_tree_card_count, position, level_offset)
    @card = card
    super(card.name, card.number, tree_config, card_tree, partial_tree_card_count, full_tree_card_count, position, level_offset)
  end

  def html_id
    card.html_id
  end
  
  def card_type_index
    @tree_config.card_type_index(card_type)
  end
  memoize :card_type_index
  
  def color(*args)
    ret = @card.color(CardTypeDefinition::INSTANCE) 
    ret.blank? ? "#fff" : ret
  end
  
  def can_be_parent?
    !@tree_config.card_types_after(card_type).empty?
  end
  memoize :can_be_parent?

  def to_json_properties(options={})
    super.merge(:acceptableChildCardTypes => @tree_config.card_types_after(card_type).collect(&:html_id))
  end
  
  def project
    card.project
  end
  
  def card_type_name
    card.card_type_name
  end
  
  def card_type
    card.card_type
  end    

  def id
    card.id
  end  
end
