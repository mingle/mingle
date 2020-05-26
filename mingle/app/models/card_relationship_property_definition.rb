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

class CardRelationshipPropertyDefinition < AssociationPropertyDefinition
  include CardPropertyMqlSupport

  def index_column?
    true
  end

  def reference_class
    Card
  end

  def describe_type
    'Card'
  end
  alias_method :type_description, :describe_type

  def property_values_description
    'Any card'
  end

  def card_filter_options
    []
  end

  def indexable_value(card)
    nil
  end

  def name_values
    []
  end
  alias_method :light_property_values, :name_values

  def property_type
    PropertyType::CardType.new(project)
  end

  def to_card_query(value, operator)
    CardQuery::Condition.comparison_between_column_and_number(CardQuery::Column.new(name), operator, value)
  end

  def url_display_value(url_identifier)
    url_identifier =~ /#(\d+)/ ? $1 : url_identifier
  end

  def all_db_identifiers
    ActiveRecord::Base.connection.select_values "SELECT id FROM #{Card.quoted_table_name}"
  end

  def refers_to_cards?
    true
  end

  def groupable?
    false
  end
end
