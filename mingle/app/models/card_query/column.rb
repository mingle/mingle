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

class CardQuery
  class AggregateFunction
    include SqlHelper

    attr_reader :function
    def initialize(function, column)
      @function, @column = function, column
      verify_numeric_property
      verify_star_only_used_with_count
      verify_recognized_functions_only
    end

    def mql_token
      [@column.mql_token, @function.upcase]
    end

    def value_from(record, cast_numeric_columns=false)
      db_value = record[unquoted_column_alias]
      return db_value unless (db_value && db_value.to_s.numeric?)

      Project.current.to_num(db_value).to_s
    end

    def to_select_sql(options = {})
      if @function =~ /count/i
        "#{@function}(#{@column.quoted_column_name}) AS #{column_alias}"
      else
        as_number(@function + '(' + as_number(@column.quoted_column_name) + ')') + " AS #{column_alias}"
      end
    end

    def collect_value_join_sql(joins, options = {})
      @column.collect_value_join_sql(joins, options) if @column.respond_to?(:value_join_sql)
    end

    def name
      "#{@function.capitalize} #{@column.name}"
    end

    def aggregate_name
      (count_aggregate?) ?'Number of cards': name
    end

    def column_name
      @column.name
    end

    def quoted_name
      Project.connection.quote_identifier(Project.connection.identifier(name))
    end

    def column_alias
      Project.connection.quote_identifier(unquoted_column_alias)
    end

    def unquoted_column_alias
      without_double_quotes = name.gsub(%{"}, '-')  # unfortunately, cannot escape double quotes in column alias in Oracle
      Project.connection.identifier(without_double_quotes)
    end

    def property_definition
      @column.property_definition if @column.respond_to?(:property_definition)
    end

    def to_s
      "#{@function}(#{@column})"
    end

    def accept(operation)
      if (count_aggregate? && star_column?)
        operation.visit_count_all_aggregate
      else
        operation.visit_aggregate_function(@function, @column.property_definition)
      end
    end

    def collect_order_by_join_sql(joins, options = {})
      # do nothing.
    end

    def order_by_columns
      return []
    end

    def order_by_column_names
      return []
    end

    def is_aggregate?
      true
    end

    def numeric?
      true
    end

    def mql_select_column_value(v)
      v
    end

    private

    def star_column?
      @column.is_a?(Star)
    end

    def count_aggregate?
      @function.downcase == 'count'
    end

    def verify_numeric_property
      unless @column.numeric?
        raise DomainException.new("Property #{@column.name.bold} is not numeric, only numeric properties can be aggregated.", @column.project)
      end
    end

    def verify_star_only_used_with_count
      return unless star_column?
      unless count_aggregate?
        raise DomainException.new("* can only be used with the #{'count'.bold} aggregate function.")
      end
    end

    def verify_recognized_functions_only
      raise DomainException.new("#{@function.bold} is not a recognized aggregate function.") unless ['avg', 'count', 'max', 'min', 'sum'].include?(@function.downcase)
    end
  end

  # interal use from model, will not expose to user
  # do not support comparison yet
  class CardIdColumn
    class CardIdPropertyDefinition
      def initialize(project)
        @project = project
      end

      def property_type
        PropertyType::CardType.new(@project)
      end

      def date?
        false
      end

      def numeric?
        false
      end
    end

    def property_definition
      CardIdPropertyDefinition.new(project)
    end

    #todo we should pass in project
    def project
      Project.current
    end

    def name
      "id"
    end
    alias_method :unquoted_column_alias, :name
    alias_method :column_name, :name

    def value_from(record, cast_numeric_columns)
      record[column_name].to_i
    end

    def to_select_sql(options={})
      quoted_column_name
    end

    def quoted_column_name
      "#{Card.quoted_table_name}.#{column_name}"
    end

    def date?
      false
    end

    def numeric?
      false
    end

    def collect_value_join_sql(joins, options = {})
    end

    def mql_select_column_value(v)
      v
    end

    def to_sql(options={})
      quoted_column_name
    end

    def accept(opertion)
      opertion.visit_id_column
    end

    def in_column_sql(options)
      to_sql(options)
    end

    def in_comparison_values(values)
      values.map do |v|
        v.respond_to?(:in_comparison_value) ? v.in_comparison_value(self) : v.to_i
      end
    end

    def comparison_sql(operator, value, options = {})
      operator.to_sql(quoted_column_name, value, false)
    end

    def number_column?
      false
    end

    def to_s
      quoted_column_name
    end
  end

  class BaseCardColumn
    attr_reader :column_name
    alias_method :unquoted_column_alias, :column_name

    def group_by_columns(options)
      quoted_column_name
    end

    def quoted_column_name
      "#{Card.quoted_table_name}.#{Project.connection.quote_column_name(column_name)}"
    end

    def to_select_sql(options={})
      quoted_column_name
    end

    def collect_value_join_sql(joins, options = {})
    end

    def mql_select_column_value(value)
      value
    end

    protected

    def initialize(column_name = '')
      @column_name = column_name
    end
  end

  class CardNameColumn < BaseCardColumn
    def initialize
      super('name')
    end
  end

  class CardNumberColumn < BaseCardColumn
    def initialize
      super('number')
    end
  end

  class CardUpdatedAtColumn < BaseCardColumn
    def initialize
      super('updated_at')
    end
  end

  class CardOrderColumn < BaseCardColumn

    def initialize(col_name, order='DESC')
      super(col_name)
      @order = order
    end

    def order_by_columns
      [Project.connection.order_by(quoted_column_name, @order)]
    end

    def order_by_column_names
      [quoted_column_name]
    end

    def collect_order_by_join_sql(joins, options = {}); end

  end

  class Column
    include Quoting, SqlHelper

    class PropertyNotExistError < DomainException; end

    attr_accessor :property_definition, :order

    def mql_token
      'SELECT'
    end

    def initialize(name, order=nil)
      @to_select_sql_clause = :to_select_clause
      @property_definition = project.find_property_definition_including_card_type_def(name, :with_hidden => true)
      raise PropertyNotExistError.new("Card property '#{name.bold}' does not exist!", project) if @property_definition.nil?
      @order = order
    end

    def project
      Project.current
    end

    # after we removed format numeric property value in database for oracle 11g,
    # we added cast_numeric_columns for model to format numeric property value
    # we kept same param name everywhere, so we could search cast_numeric_columns for details
    def value_from(record, cast_numeric_columns=false)
      property_definition.property_type.format_value_for_card_query(record.find_ignore_case(unquoted_column_alias), cast_numeric_columns)
    end

    def quoted_comparison_column_name
      property_definition.quoted_comparison_column
    end

    def column_type
      property_definition.column_type
    end

    def ordinal?
      property_definition.numeric? || property_definition.date?
    end

    def validate_comparison_value(value, &block)
      if property_definition.numeric? && !(value.blank? || value.numeric?)
        invalid_comparison_value(property_definition, value)
      end
      yield(value) if block_given?
    rescue PropertyDefinition::InvalidValueException => e
      invalid_comparison_value(property_definition, value)
    rescue EnumeratedPropertyDefinition::ValueRestrictedException => e
      raise DomainException.new(e.message, project)
    end

    def comparison_sql(operator, value, options = {})
      numeric_comparison = property_definition.numeric_comparison_for?(value)
      validate_comparison_value(value) do
        comparison_value = property_definition.comparison_value(value)
        operator.to_sql(quoted_comparison_column_name, comparison_value, numeric_comparison)
      end
    end

    def mql_select_column_value(value)
      property_definition.mql_select_column_value(value)
    end

    def invalid_comparison_value(property_definition, value)
      notice_msg = if Project.current.find_property_definition_or_nil(value)
        " Value #{value.to_s.bold} is a property, please use #{"PROPERTY #{value}".bold}."
      end
      property_type = property_definition.property_type
      raise DomainException.new("Property #{property_definition.name.bold} is #{property_type}, and value #{value.to_s.bold} is not #{property_type}. Only #{property_type} values can be compared with #{property_definition.name.bold}.#{notice_msg}", project)
    end

    def to_select_sql(options = {})
      "#{to_sql(options.merge(:clause => @to_select_sql_clause))} AS #{column_alias}"
    end

    def to_sql(options = {})
      sql = property_definition.send(options[:clause] || :to_condition_clause)
      options[:cast_numeric_columns] ? cast_column_name(sql) : sql
    end

    def group_by_columns(options = {})
      property_definition.group_by_columns.collect do |c|
        options[:cast_numeric_columns] ? cast_column_name(c) : c
      end
    end

    def quoted_column_name
      "#{Card.quoted_table_name}.#{@property_definition.quoted_column_name}"
    end

    def cast_column_name(col_name)
      return col_name unless property_definition.numeric?
      as_number(col_name, @property_definition.project.precision)
    end

    def quoted_name
      Project.connection.quote_identifier(Project.connection.identifier(name))
    end

    def column_name
      property_definition.column_name
    end

    def name
      property_definition.name
    end

    def mql_name
       "'#{name}'"
    end

    def column_alias
      Project.connection.quote_identifier(unquoted_column_alias)
    end

    def unquoted_column_alias
      without_double_quotes = name.gsub(%{"}, '-')  # unfortunately, cannot escape double quotes in column alias in Oracle
      without_double_quotes = without_double_quotes.gsub(%{?}, '_')  # ActiveRecord takes any '?' in statement as place holder, this is a workaround for property names containing '?'
      Project.connection.identifier(without_double_quotes)
    end

    def property_definition
      @property_definition
    end

    def date?
      property_definition.try :date?
    end

    def numeric?
      property_definition.try :numeric?
    end

    def non_numeric_values
      property_definition.non_numeric_values if @property_definition && @property_definition.respond_to?(:non_numeric_values)
    end

    def to_s
      str = quote(name)
      str += " " + @order if @order
      str
    end

    def collect_order_by_join_sql(joins, options = {})
      joins.push(property_definition.order_by_join_sql)
    end

    def collect_value_join_sql(joins, options = {})
      joins.push(property_definition.value_join_sql)
    end

    def order_by_columns
      property_definition.order_by_columns.collect { |column_sql| Project.connection.order_by(column_sql, @order)  }
    end

    def order_by_column_names
      property_definition.order_by_columns
    end

    def ==(other)
      property_definition.column_name == other.property_definition.column_name
    end

    def is_aggregate?
      false
    end

    def accept(operation)
      operation.visit_column(property_definition)
    end

    def number_column?
      name.ignore_case_equal?("Number")
    end

    def card_id_column?
      property_definition.is_a?()
    end

    def extracts_value_comparable_to_a_relationship_property?
      number_column? || name_column?
    end

    def in_column_sql(options)
      if number_column? #optimization
        to_sql(options)
      elsif numeric?
        as_number(to_sql(options))
      elsif date?
        to_sql(options)
      elsif column_type == :string
        lower_with_cast(to_sql(options))
      else
        to_sql(options)
      end
    end

    def in_comparison_values(values)
      if number_column?  #optimization
        values.map do |v|
          v.respond_to?(:in_comparison_value) ? v.in_comparison_value(self) : v.to_i
        end
      elsif numeric?
        values.map do |v|
          v.respond_to?(:in_comparison_value) ? v.in_comparison_value(self) : v.to_f
        end
      elsif date?
        values.map do |v|
          val = v.respond_to?(:in_comparison_value) ? v.in_comparison_value(self) : v
          Project.connection.quote(property_definition.comparison_value(val))
        end
      elsif column_type == :string
        values.map do |v|
          sql_value = v.respond_to?(:in_comparison_value) ? v.in_comparison_value(self) : v
          Card.send(:bind_variables, [lower_with_cast('?'), sql_value])
        end
      else
        values.map do |v|
          sql_value = v.respond_to?(:in_comparison_value) ? v.in_comparison_value(self) : v
          Project.connection.quote(property_definition.comparison_value(sql_value))
        end
      end
    end

    private
    def name_column?
      name.ignore_case_equal?("Name")
    end
  end

  class GroupByColumn < Delegator
    def mql_token
      'GROUP BY'
    end

    def initialize(column, order=nil)
      @property_definition = column.property_definition
      @order = order
      @__delegate__ = column
    end

    def __getobj__
      @__delegate__
    end

    def accept(operation)
      operation.visit_group_by_column(property_definition)
    end

    def to_s
      __getobj__.to_s
    end

    def ==(other)
      __getobj__.property_definition.column_name == other.property_definition.column_name
    end
  end

  class OrderByColumn < Delegator
    def initialize(column, order=nil)
      @property_definition = column.property_definition
      @order = order
      @__delegate__ = column
    end

    def mql_token
      'ORDER BY'
    end

    def __getobj__
      @__delegate__
    end

    def accept(operation)
      operation.visit_order_by_column(property_definition, __getobj__.order, default?)
    end

    def to_s
      __getobj__.to_s
    end

    def ==(other)
      __getobj__.property_definition.column_name == other.property_definition.column_name
    end

    private
    def default
      self.class.new(::CardQuery::Column.new('Number', 'DESC'))
    end

    def default?
      __getobj__ == default
    end
  end

  class Star

    def to_s
      quoted_column_name
    end

    def quoted_column_name
      '*'
    end

    def name
      nil
    end

    def numeric?
      true
    end

    def non_numeric_values
      []
    end

    def property_definition
      nil
    end
  end

  class Joins
    def initialize
      @sqls = []
    end

    def push(sql)
      @sqls.push(sql) unless sql.blank? || @sqls.include?(sql)
    end

    def to_sql(options = {})
      @sqls.join("\n")
    end
  end
end
