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

class DatePropertyDefinition < PropertyDefinition

  class << self
    def today
      [PropertyType::DateType::TODAY, PropertyType::DateType::TODAY]
    end
    
    alias_method :current, :today
  end
  
  def describe_type
    'Date'
  end
  alias_method :type_description, :describe_type
  
  def property_values_description
    'Any date'
  end
  
  def property_type
    PropertyType::DateType.new(project)
  end
  
  def db_identifier(card)
    r = card.send(:read_attribute, column_name)
    ActiveRecord::ConnectionAdapters::Column.string_to_time(r)
  end
  def column_type
    :date
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
    connection = ActiveRecord::Base.connection
    connection.select_values("SELECT DISTINCT #{connection.select_date_sql(column_name)} AS #{self.column_name} from #{project.cards_table } ORDER BY #{self.column_name}").compact
  end

  def indexable_value(card)
    nil
  end

  def date?
    true
  end
  
  def available_operators
    return Operator::Equals.name, Operator::NotEquals.name, Operator::LessThan.date_name, Operator::GreaterThan.date_name
  end
  
  def name_values
    []
  end
  alias_method :card_filter_options, :name_values
  alias_method :light_property_values, :name_values

  def support_inline_creating?
    false
  end
  
  def validate_card(card)
    begin
      value(card)
    rescue ArgumentError
      card.errors.add_to_base("Invalid date values have been entered. Please provide valid dates in #{project.humanize_date_format.bold} format.")
    end    
  end  

  def validate_transition_action(action)
    begin
      Date.parse_with_hint(action.value, project.date_format)
    rescue ArgumentError
      action.errors.add_to_base("Invalid date values have been entered. Please provide valid dates in #{project.humanize_date_format.bold} format.")
    end    
  end
  
  def date_by_value_identifier(value_identifier)
    property_type.find_object(value_identifier)
  end  
  alias_method :comparison_value, :date_by_value_identifier
  
  def property_value_on(card)
    value_from_db = db_identifier(card)
    property_value_from_db(value_from_db.is_a?(Time) ? value_from_db.to_date : value_from_db, stale?(card))
  end

  private
    
  def formatted(date)
    property_type.format(date)
  end    
end
