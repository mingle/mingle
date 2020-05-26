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

class TextPropertyDefinition < PropertyDefinition
  additionally_serialize :complete, [:is_managed?], 'v2'
  def describe_type
    "Any #{is_numeric ? 'number' : 'text'}"
  end
  alias_method :type_description, :describe_type
  alias_method :property_values_description, :describe_type

  def is_managed?
    false
  end

  def property_type
    is_numeric ? PropertyType::NumericType.new(project) : PropertyType::StringType.new
  end

  def groupable?
    false
  end

  def colorable?
    false
  end

  def finite_valued?
    false
  end
  alias_method :lockable?, :finite_valued?

  def values
    rows = self.connection.select_all(values_sql)
    rows.map { |row| row['value'] }.compact
  end

  def light_property_values
    []
  end

  def make_uniq(values)
    property_type.make_uniq(values)
  end

  def available_operators
    return Operator::Equals.name, Operator::NotEquals.name, Operator::LessThan.name, Operator::GreaterThan.name if numeric?
    super
  end

  def validate_card(card)
    card.errors.add_to_base("#{value(card).bold} is too long. #{self.name.bold} values should be less than 256 characters long.") if value(card).to_s.strip.size > 255
    type_validation_errors = property_type.validate(value(card))
    card.errors.add_to_base(type_validation_errors.to_sentence) if type_validation_errors.any?
    card.errors.add_to_base(attemped_to_create_plv(value(card))) if type_validation_errors.empty? && value(card).to_s.opens_and_closes_with_parentheses
  end

  def card_filter_condition(bind_value_identifier, operator = Operator.equals)
    operator.to_sql("#{Card.quoted_table_name}.#{column_name}", bind_value_identifier)
  end

  def name_values
    []
  end

  alias_method :card_filter_options, :name_values

  def support_inline_creating?
    true
  end

  def numeric_comparison_for?(value)
    numeric? && value && value.numeric?
  end

  def numeric?
    is_numeric
  end

  def filterable?
    false
  end

  protected

  def values_sql
    if is_numeric
      "SELECT DISTINCT #{self.column_name} AS value, #{self.connection.as_number(self.column_name)} FROM #{Card.quoted_table_name} ORDER BY #{self.connection.as_number(self.column_name)}"
    else
      "SELECT DISTINCT #{self.column_name} AS value FROM #{Card.quoted_table_name} ORDER BY #{self.column_name}"
    end
  end

end
