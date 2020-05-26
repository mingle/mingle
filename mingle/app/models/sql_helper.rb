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

module SqlHelper
  include SecureRandomHelper
  extend self

  def sanitize_sql(sql, *values)
    ActiveRecord::Base.send :sanitize_sql, [sql, *values], nil
  end
  module_function :sanitize_sql

  def join_with_and(sql_conditions)
    ret = sql_conditions.collect do |condition|
      if condition.is_a?(Array)
        sanitize_sql(condition[0], *condition[1..-1])
      else
        condition.to_s
      end
    end
    ret.collect { |con| "(#{con})" }.join(" AND ")
  end

  def as_char(value, size=128)
    connection.as_char(value, size)
  end

  def as_boolean(value)
    connection.as_boolean(value)
  end

  def lower(value)
    connection.lower(value)
  end

  def lower_with_cast(value)
    return "NULL" if value.blank?
    "LOWER(#{as_char(value)})"
  end

  def as_text(value)
    value = "NULL" if value.blank?
    "CAST(#{value} AS TEXT)"
  end

  def as_number(value, scale=10)
    connection.as_number(value, scale)
  end

  def as_date(value, column_type=:date)
    case column_type
    when :date # to shake off the hour and minute part
      "TO_DATE(TO_CHAR(#{value}, 'YYYY-MM-DD'), 'YYYY-MM-DD')"
    when :string
      "TO_DATE(#{value}, 'YYYY-MM-DD')"
    else
      raise "type #{column_type} cannot be converted to date sql expression"
    end

  end

  def as_integer(column_name)
    ActiveRecord::Base.connection.cast_as_integer(column_name)
  end

  def case_when(expression, true_value, false_value)
    "(CASE WHEN (#{expression}) THEN #{true_value} ELSE #{false_value} END)"
  end

  def select_all_rows(sql)
    ActiveRecord::Base.connection.select_all(sql)
  end
  module_function :select_all_rows

  def select_value(sql)
    ActiveRecord::Base.connection.select_value(sql)
  end
  module_function :select_value

  def select_values(sql)
    ActiveRecord::Base.connection.select_values(sql)
  end

  def execute(sql)
    ActiveRecord::Base.connection.execute(sql)
  end

  def connection
    ActiveRecord::Base.connection
  end

  def number_comparison_sql(left, operator, right, scale=10)
    as_number(left, scale) + operator + as_number(right, scale)
  end

  # useful because NULLs get wacky when it comes to inequality
  def not_equal_condition(column, value, options = {})
    if value
      inequality = options[:case_insensitive] ? connection.case_insensitive_inequality(column, "?") : connection.case_sensitive_inequality(column, "?")
      sanitize_sql("((#{inequality}) OR #{quote_column_name column} IS NULL)", value)
    else
      "(#{quote_column_name column} IS NOT NULL)"
    end
  end

  def formula_not_equal_condition(column, value)
    value.blank? ? not_equal_condition(column, as_char(value)) : column_vs_column_not_equal_condition(column, as_char(value))
  end

  # use to compare two columns, two sql formulas, or a combination of those
  def column_vs_column_not_equal_condition(column_one, column_two, options = {})
    inequality = if options[:case_insensitive]
      connection.case_insensitive_inequality("(#{column_one})", "(#{column_two})")
    else
      connection.case_sensitive_inequality("(#{column_one})", "(#{column_two})")
    end
    %{ ((#{inequality}) OR
       (#{column_one} IS NULL AND #{column_two} IS NOT NULL)
       OR (#{column_one} IS NOT NULL AND #{column_two} IS NULL)) }
  end

  def not_null_or_empty(column)
    connection.not_null_or_empty(column)
  end

  def quote_column_names(names)
    names.collect { |name| quote_column_name(name) }
  end

  def quote_column_name(name)
    name.split(".").map(&connection.method(:quote_column_name)).join('.')
  end

  def quote_table_name(name)
    connection.quote_table_name(name)
  end
end
