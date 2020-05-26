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

module AbstractAdapterExtensions
  include ::SQLBulkMethods

  attr_accessor :config

  def supports_constraints?
    true
  end

  def safe_table_name(proposed_name)
    "#{ActiveRecord::Base.table_name_prefix}#{proposed_name}"
  end

  def case_sensitive_inequality(value_one, value_two)
    "#{value_one} != #{value_two}"
  end

  def case_insensitive_inequality(value_one, value_two)
    "LOWER(#{value_one}) != LOWER(#{value_two})"
  end

  def max_precision
    38
  end

  def string_limit
    65535
  end

  def supports_sequences?
    false
  end

  def not_null_or_empty(column)
    "#{column} != ''"
  end

  def datetime_insert_sql(value)
    if value.blank?
      'NULL'
    elsif value.acts_like?(:time) && value.respond_to?(:usec)
      "'#{value.to_formatted_s(:db)}.#{sprintf('%06d', value.usec)}'"
    else
      "'#{value}'"
    end
  end

  def date_insert_sql(value)
    return 'NULL' if value.blank?
    "date '#{value}'"
  end

  def select_date_sql(column_name)
    "CAST(#{column_name} AS DATE)"
  end

  def alias_if_necessary_as(alias_name)
    "as #{alias_name}"
  end

  def as_char(value, size)
    value = 'NULL' if value.blank?
    "CAST(#{value} AS CHAR(#{size}))"
  end

  def as_boolean(value)
    "CAST(#{value} AS BOOLEAN)"
  end

  def as_date(value)
    "TO_DATE(TO_CHAR(#{value}, 'YYYY-MM-DD'), 'YYYY-MM-DD')"
  end

  def as_number(value, scale=nil)
    value = 'NULL' if value.blank?
    scale = Project.current.precision if scale.nil? && Project.activated?
    "CAST(#{value} AS DECIMAL(#{max_precision}, #{scale || 0}))"
  end

  def as_high_precision_number(value)
    value = 'NULL' if value.blank?
    "CAST(#{value} AS #{high_precision_number_type})"
  end

  def as_padded_number(value, precision)
    as_number(value, precision)
  end

  def quote_value(value)
    return 'NULL' if value.blank?
    %{#{quote_character}#{value}#{quote_character}}
  end

  def quote_character
    '"'
  end

  def db_specific_table_name(table_name)
    table_name
  end

  def true_value
    1
  end

  def false_value
    0
  end

  def quote_identifier(identifier)
    quote_value(identifier)
  end

  def identifier(identifier)
    identifier
  end

  def limit(limit)
    limit
  end

  def cards_table_options
    {}
  end

  def quote_column_names(column_names)
    column_names.collect { |column_name| quote_column_name(column_name) }
  end

  def column_name(column_name)
    column_name
  end

  def insert_large_objects(table, record, new_id, columns=table.columns); end
end

ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval do
  include AbstractAdapterExtensions
end
