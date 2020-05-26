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

module Operator

  def parse(operator_symbol)
    @operators ||= {
      'is' => equals,
      'is not' => not_equals,
      '=' => equals,
      '!=' => not_equals,
      '<' => less_than,
      'is less than' => less_than,
      '<=' => less_than_or_equals,
      'is less than or equal to' => less_than_or_equals,
      '>' => greater_than,
      'is greater than' => greater_than,
      '>=' => greater_than_or_equals,
      'is greater than or equal to' => greater_than_or_equals,
      'is before' => less_than,
      'is after' => greater_than
    }
    @operators[operator_symbol.to_s.downcase]
  end

  def self.method_missing(method, *args, &block)
    "Operator::#{method.to_s.camelize}".constantize.new
  rescue NameError
    super
  end

  module_function :parse

  class Base
    include SqlHelper

    def to_sql(column_name, value, is_numeric=false)
      if value.blank?
        sanitize_sql *is_null_sql(column_name)
      elsif is_numeric
        column_name = as_number(column_name)
        bind_parameter = "?"
        default_sql(column_name, bind_parameter, value).first.gsub(/\?/, as_number("'#{value}'"))
      else
        column_name = value.is_a?(String) ? lower_with_cast(column_name) : column_name
        bind_parameter = value.is_a?(String) ? lower_with_cast('?'): "?"
        sanitize_sql *default_sql(column_name, bind_parameter, value)
      end
    end

    def to_sql_without_params_binded(column1_name,
                                     column1_db_type,
                                     column2_name,
                                     column2_db_type,
                                     is_numeric_comparison, is_string_comparison, is_date_comparison)

      if is_numeric_comparison
        column1_name = as_number(column1_name)
        column2_name = as_number(column2_name)
      elsif is_string_comparison
        column1_name = lower_with_cast(column1_name)
        column2_name = lower_with_cast(column2_name)
      elsif is_date_comparison
        column1_name = as_date(column1_name, column1_db_type)
        column2_name = as_date(column2_name, column2_db_type)
      end

      "#{column1_name} #{operator_symbol} #{column2_name}"
    end

    def is_null_sql(column_name)
      raise "NULL value is not supported by #{to_s}"
    end

    def supports_filtering_by_null?
      false
    end

    def ==(other)
      self.hash == other.hash
    end

    def eql?(other)
      self.==(other)
    end

    def equal?(other)
      self.==(other)
    end

    def hash
      to_s.hash
    end

    def to_s
      self.class.name
    end

    def result_is_individual_value?
      false
    end

    def description(property_definition)
      return self.class.date_name if (property_definition.date? && self.class.respond_to?(:date_name))
      to_s
    end

    def atomic_operators
      return [self]
    end

    def is_equality?
      false
    end

    def ordinal?
      false
    end
  end

  class Equals < Base
    class << self
      def name
        "is"
      end
    end

    def is_null_sql(column_name)
      ["#{column_name} IS NULL"]
    end

    def supports_filtering_by_null?
      true
    end

    def default_sql(column_name, bind_parameter, value)
      return "#{column_name} #{operator_symbol} #{bind_parameter}", value
    end

    def operator_symbol
      '='
    end

    alias as_mql operator_symbol

    def opposite
      Operator.not_equals
    end

    def compare(lhs, rhs)
      lhs == rhs
    end

    def result_is_individual_value?
      true
    end

    def is_equality?
      true
    end
  end

  class NotEquals < Base
    class << self
      def name
        "is not"
      end
    end

    def is_null_sql(column_name)
      ["#{column_name} IS NOT NULL"]
    end

    def supports_filtering_by_null?
      true
    end

    def default_sql(column_name, bind_parameter, value)
      return "(#{column_name} #{operator_symbol} #{bind_parameter} OR #{column_name} IS NULL)", value
    end

    def operator_symbol
      '<>'
    end

    def as_mql
      "!="
    end

    def compare(lhs, rhs)
      !opposite.compare(lhs, rhs)
    end

    def opposite
      Operator.equals
    end
  end

  class LessThan < Base
    class << self
      def name
        "is less than"
      end

      def date_name
        "is before"
      end
    end

    def default_sql(column_name, bind_parameter, value)
      return "#{column_name} #{operator_symbol} #{bind_parameter}", value
    end

    def operator_symbol
      '<'
    end

    alias as_mql operator_symbol

    def opposite
      Operator.greater_than_or_equals
    end

    def ordinal?
      true
    end

  end

  class LessThanOrEquals < Base
    class << self
      def name
        "is less than or equals"
      end
    end

    def default_sql(column_name, bind_parameter, value)
      return "#{column_name} #{operator_symbol} #{bind_parameter}", value
    end

    def operator_symbol
      '<='
    end

    alias as_mql operator_symbol

    def opposite
      Operator.greater_than
    end

    def atomic_operators
      return [Operator.parse('<'), Operator.parse('=')]
    end

    def ordinal?
      true
    end
  end

  class GreaterThanOrEquals < Base
    class << self
      def name
        "is greater than or equals"
      end
    end

    def default_sql(column_name, bind_parameter, value)
      return "#{column_name} #{operator_symbol} #{bind_parameter}", value
    end

    def operator_symbol
      '>='
    end

    alias as_mql operator_symbol

    def opposite
      Operator.less_than
    end

    def atomic_operators
      return [Operator.parse('>'), Operator.parse('=')]
    end

    def ordinal?
      true
    end
  end

  class GreaterThan < Base
    class << self
      def name
        "is greater than"
      end

      def date_name
        "is after"
      end
    end

    def default_sql(column_name, bind_parameter, value)
      return "#{column_name} #{operator_symbol} #{bind_parameter}", value
    end

    def operator_symbol
      '>'
    end

    alias as_mql operator_symbol

    def opposite
      Operator.less_than_or_equals
    end

    def ordinal?
      true
    end
  end
end
