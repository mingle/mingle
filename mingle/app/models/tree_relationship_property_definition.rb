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

class TreeRelationshipPropertyDefinition < CardPropertyDefinition
  include SqlHelper, CardPropertyMqlSupport

  belongs_to :tree_configuration
  validates_presence_of :tree_configuration

  def update_card_by_obj(card, value_card)
    return unless property_value_on(card) != property_value_from_db(value_card ? value_card.id : nil)
    unless self.has_card_type?(card.card_type)
      return if value_card.blank?
      raise PropertyDefinition::InvalidValueException.new("Property #{self.tree_configuration.name.bold}:#{self.name.bold} is not applicable for card type #{card.card_type_name.bold}")
    end
    card.temp_store_tree_property_value(tree_configuration.name, property_value_on(card))
    super(card, value_card)
  end

  def index_column?
    true
  end

  def tree_special?
     true
  end

  def card_filter_options
    []
  end

  def add_card_to_tree(card)
    if parent = value(card)
      tree_configuration.add_child(parent, :to => :root) unless tree_configuration.include_card?(parent)
      tree_configuration.validate_including_card(parent)
    end
    tree_configuration.add_card(card)
  end

  def abbreviated_display_values
    tree_configuration.abbreviated_card_names(valid_card_type.is_type_card_query_condition)
  end
  memoize :abbreviated_display_values

  def expanded_display_values
    tree_configuration.expanded_card_names(valid_card_type.is_type_card_query_condition)
  end
  memoize :expanded_display_values

  def to_s
    "#{valid_card_type.name} => #{card_types.collect(&:name)}"
  end

  def refers_to_cards?
    true
  end

  def describe_type
    "Any card used in tree"
  end
  alias_method :type_description, :describe_type
  alias_method :property_values_description, :describe_type

  def to_card_query(value, operator)
    CardQuery::Condition.comparison_between_column_and_number(CardQuery::Column.new(name), operator, value)
  end

  def name_values
    []
  end
  alias_method :light_property_values, :name_values

  def lane_values
    values.collect{|card| [expanded_display_values[card.id], card.number.to_s] }.smart_sort_by {|pair| pair.first }
  end

  def weak_ordered?
    true
  end

  def sort(property_values)
    property_values.smart_sort_by do |property_value|
      property_value.tree_relationship_display_value(true)
    end
  end

  def valid_card_type
    project.find_card_type_by_id(self.valid_card_type_id)
  end

  def url_display_value(url_identifier)
    url_identifier =~ /#(\d+)/ ? $1 : url_identifier
  end

  def lane_identifier(card_number)
    return ' ' if card_number.blank?
    card = values.detect {|c| c.number.to_s == card_number.to_s}
    card ? card.number.to_s : nil
  end

  private
  def update_card_to_same_value(card, value_card)
    old_db_identifier = db_identifier(card)
    (value_card.nil? && old_db_identifier.nil?) || (!value_card.nil? && old_db_identifier == value_card.id)
  end
end
