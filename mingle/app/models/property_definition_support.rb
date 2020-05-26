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

module PropertyDefinitionSupport
  include SqlHelper

  def numeric?
    false
  end

  def refers_to_cards?
    false
  end

  def available_operators
    return Operator::Equals.name, Operator::NotEquals.name
  end

  def operator_options
    available_operators.inject([]) { |result, operator_name| result << [operator_name, operator_name] }
  end

  def finite_valued?
    true
  end

  def to_card_query(value, operator)
    CardQuery::Condition.comparison_between_column_and_value(CardQuery::Column.new(name), operator, value)
  end

  def make_uniq(values)
    values.uniq
  end

  def date?
    false
  end

  def filterable?
    true
  end

  def weak_ordered?
    false
  end

  def sort_position(db_identifier)
    db_identifier
  end

  def sort(property_values)
    property_values.sort_by(&:sort_position)
  end

  def property_value_from_url(url_identifier)
    PropertyValue.create_from_url_identifier(self, url_display_value(url_identifier))
  end

  def property_value_from_db(db_identifier, stale=false)
    PropertyValue.create_from_db_identifier(self, db_identifier, stale)
  end

  def property_values_from_url(url_identifiers)
    PropertyValueCollection.new(url_identifiers.collect{ |url_identifier| property_value_from_url(url_identifier) })
  end

  def property_values_from_db(db_identifiers)
    PropertyValueCollection.new(db_identifiers.collect{ |db_identifier| property_value_from_db(db_identifier) })
  end

  def property_value_on(card)
    property_value_from_db(db_identifier(card), stale?(card))
  end

  def url_display_value(url_identifier)
    url_identifier
  end

  def label_value_for_charting(url_identifier)
    property_type.format_value_for_card_query(url_identifier)
  end

  def different?(card_one, card_two)
    property_value_on(card_one) != property_value_on(card_two)
  end

  def stale?(card)
    stalable? && card.stale_property?(self)
  end

  def card_count_for(value, query=CardQuery.empty_query)
    value = value.blank? ? nil : value.to_s
    value_to_card_count_map(query)[value] || 0
  end

  #do not modify this perf enhancement without doing a profiling of a grid view grouped by
  #a relationship property with a large number of values
  def value_to_card_count_map(query=CardQuery.empty_query)
    return {} unless project.card_schema.column_defined_in_card_table?(column_name)
    sql = "SELECT #{Card.quoted_table_name}.#{self.quoted_column_name}, COUNT(*) AS count_column FROM #{Card.quoted_table_name} #{query.joins_clause_sql} #{query.where_clause_sql} GROUP BY #{Card.quoted_table_name}.#{self.column_name}"
    connection.select_all(sql).inject({}) {|memo, row| memo[row[column_name].nil? ? nil : row[column_name].to_s] = row['count_column'].to_i; memo }
  end
  memoize :value_to_card_count_map

  def aggregated?
    false
  end

  def formulaic?
    false
  end

  def stalable?
    aggregated? || formulaic?
  end
end
