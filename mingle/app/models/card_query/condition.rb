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
  class Condition
    include Quoting

    class << self

      def comparison_between_column_and_value(column, operator, value)
        if value.blank?
          null_condition = CardQuery::IsNull.new(column)
          "is not" == operator.to_s ? CardQuery::Not.new(null_condition) : null_condition
        else
          ComparisonWithValue.new(column, operator, value)
        end
      end

      def comparison_between_column_and_number(column, operator, value)
        value.blank? || column.number_column? ? comparison_between_column_and_value(column, operator, value) : ComparisonWithNumber.new(column, operator, value)
      end

      def comparison_between_columns(column1, operator, column2)
        ComparisonWithColumn.new(column1, operator, column2)
      end

      def comparison_between_column_and_plv(column, operator, plv)
        ComparisonWithPLV.new(column, operator, plv)
      end

      def comparison_between_column_and_today(column, operator)
        TodayComparison.new(column, operator)
      end


      def comparison_between_column_and_this_card(column, operator, options)
        ComparisonWithThisCard.new(column, operator, options)
      end

      def comparison_between_column_and_this_card_property(column, operator, property)
        ComparisonWithThisCardProperty.new(column, operator, property)
      end

      def explicit_in(column, values)
        verify_plvs(column, values)
        normalized_values = values.collect { |value| value.is_a?(PLV) ? value.to_s : value }
        ExplicitIn.new(column, normalized_values, :original_values => values)
      end

      def implicit_in(column, query, options = {})
        ImplicitIn.new(column, query)
      end

      def numbers_explicit_in(column, values)
        verify_plvs(column, values)
        NumbersExplicitIn.new(column, values)
      end

      def in_plan(plan_name)
        InPlan.new(PlanIdentifier.new(plan_name))
      end

      private
      def verify_plvs(column, values)
        values.each { |value| value.verify_comparison_types(column) if value.is_a?(PLV) }
        if values.any? { |value| value.is_a?(PLV) && value.card_plv?  }
          raise DomainException.new("Project variables are not currently supported by a MQL IN clause when the comparison property is a tree property. Please construct your conditions using different MQL syntax.")
        end
      end
    end

    def bind_variables(sql)
      Card.send(:bind_variables, sql)
    end

    def collect_value_join_sql(joins, options = {})
    end

    def conditions
      nil
    end

    def negated_mql
      "NOT #{as_mql}"
    end

    def flatten_condition
      result = []
      result << self
      if self.conditions != nil
        self.conditions.compact.each do |c|
          result = result + c.flatten_condition
        end
      end
      result
    end

    def can_be_cached?
      true
    end

    def uses_plv?(plv)
      false
    end

    def comparisons
      []
    end

    def accept(operation)
      # do nothing, subclass resposibility to overwrite and impl details
    end

    def columns
      []
    end
  end

  class True < Condition; end

  class And < Condition
    def initialize(*conditions)
      @conditions = conditions.flatten.compact
    end

    def to_s
      if @conditions.size == 1
        @conditions[0].to_s
      else
        '(' + @conditions.join(' AND ') + ')'
      end
    end

    def to_sql(options = {})
      if @conditions.size == 1
        @conditions.first.to_sql(options)
      else
        conditions = @conditions.collect { |c| c.to_sql(options) }.compact
        '(' + conditions.join(' AND ') + ')' if conditions.any?
      end
    end

    def value_join_sql(options = {})
      @conditions.collect { |c| c.value_join_sql(options) }
    end

    def collect_value_join_sql(joins, options = {})
      @conditions.each { |con| con.collect_value_join_sql(joins, options) }
    end

    def accept(operation)
      operation.visit_and_condition(*conditions)
    end

    def conditions
      @conditions
    end

    def uses_plv?(plv)
      @conditions.any? { |condition| condition.uses_plv?(plv) }
    end

    def can_be_cached?
      @conditions.all?(&:can_be_cached?)
    end

    def opposite
      NotAnd.new(*@conditions)
    end

    def comparisons
      @conditions.inject([]) do |result, condition|
        if (condition.respond_to?(:comparisons))
          condition.comparisons.each {|comparison| result << comparison}
        else
          result << condition if (condition.respond_to?(:column) && condition.respond_to?(:is_equality?))
        end
      end
    end

    def columns
      @conditions.map(&:columns).flatten
    end
  end

  class NotAnd < And
    def initialize(*conditions)
      @conditions = conditions.collect{ |condition| Not.new(condition) }
    end
  end

  class FromTree < And
    attr_reader :tree_condition, :other_conditions
    def initialize(tree_condition, other_conditions)
      @other_conditions = if other_conditions.is_a?(Array)
        other_conditions.flatten.compact
      else
        [other_conditions]
      end
      @tree_condition = tree_condition
      @conditions = [tree_condition]  + @other_conditions
    end

    def accept(operation)
      operation.visit_from_tree_condition(@tree_condition, @other_conditions)
    end
  end

  class Or < Condition
    def initialize(*conditions)
      @conditions = conditions
    end

    def to_s
      '(' + @conditions.join(' OR ') + ')'
    end

    def accept(operation)
      operation.visit_or_condition(*conditions)
    end

    def to_sql(options = {})
      conditions = @conditions.collect { |c| c.to_sql(options) }.compact
      '(' + conditions.join(' OR ') + ')' if conditions.any?
    end

    def value_join_sql(options = {})
      @conditions.collect { |c| c.value_join_sql(options) }
    end

    def collect_value_join_sql(joins, options = {})
      @conditions.each { |con| con.collect_value_join_sql(joins, options) }
    end

    def conditions
      @conditions
    end

    def uses_plv?(plv)
      @conditions.any? { |condition| condition.uses_plv?(plv) }
    end

    def can_be_cached?
      @conditions.all?(&:can_be_cached?)
    end

    def comparisons
      @conditions.collect {|condition| (condition.respond_to?(:column) && condition.respond_to?(:is_equality?)) ? condition : nil}.compact
    end

    def columns
      @conditions.map(&:columns).flatten
    end
  end

  class Not < Condition
    def initialize(condition)
      @condition = condition
    end

    def to_s
      @condition.respond_to?(:opposite) ? @condition.opposite.to_s : "NOT #{@condition}"
    end

    def to_sql(options = {})
      @condition.respond_to?(:opposite) ? @condition.opposite.to_sql(options) : "NOT #{@condition.to_sql(options)}"
    end

    def collect_value_join_sql(joins, options = {})
      @condition.collect_value_join_sql(joins, options)
    end

    def conditions
      [@condition]
    end

    def can_be_cached?
      @condition.can_be_cached?
    end

    def uses_plv?(plv)
      @condition.uses_plv?(plv)
    end

    def accept(operation)
      operation.visit_not_condition(@condition)
    end

    def comparisons
      @condition.respond_to?(:opposite) ? [@condition.opposite] : []
    end

    def columns
      @condition.columns
    end
  end

  class ComparisonWithColumn < Condition

    def initialize(column1, operator, column2)
      @column1, @operator, @column2 = column1, operator, column2
    end

    def project
      @column1.project
    end

    def to_s
      "#{@column1} #{@operator} #{@column2}"
    end

    def to_sql(options = {})
      if @operator.ordinal?
        invalid_columns = [@column1, @column2].select{|c| !c.ordinal? }
        if invalid_columns.any?
          err_msg = "Property #{invalid_columns.collect(&:to_s).collect(&:bold).join(' and ')} only can be compared by '=' and '!='. #{invalid_columns.size == 1 ? 'It' : 'They'} cannot work with operator '#{@operator.operator_symbol}'"
          raise DomainException.new(err_msg, project)
        end
      end
      is_numeric_comparison = @column1.numeric? && @column2.numeric?
      is_string_comparison = @column1.column_type == :string && @column2.column_type == :string
      is_date_comparison = @column1.property_definition.date? && @column2.property_definition.date?
      @operator.to_sql_without_params_binded(@column1.quoted_column_name,
                                             @column1.column_type,
                                             @column2.quoted_column_name,
                                             @column2.column_type,
                                             is_numeric_comparison, is_string_comparison, is_date_comparison)
    end

    def accept(operation)
      operation.visit_comparison_with_column(@column1, @operator, @column2)
    end

    def column
      @column1
    end

    def column2
      @column2
    end

    def columns
      [@column1, @column2]
    end

    def collect_value_join_sql(joins, options = {})
      @column1.collect_value_join_sql(joins, options)
      @column2.collect_value_join_sql(joins, options)
    end

    def opposite
      ComparisonWithColumn.new(@column1, @operator.opposite, @column2)
    end

    def is_equality?
      @operator.is_equality?
    end

    def comparisons
      [self]
    end

  end

  class ComparisonWithValue < Condition

    attr_reader :column, :operator, :value

    def initialize(column, operator, value)
      @column, @operator, @value = column, operator, value
      raise DomainException.new("'Project' is only supported in SELECT statement") if @column.name.downcase == 'project'
    end

    def to_s
      "#{@column} #{@operator} #{quote(@value.to_s)}"
    end

    def inspect
      to_s
    end

    def to_sql(options = {})
      @column.comparison_sql(@operator, @value, options)
    end

    def accept(operation)
      operation.visit_comparison_with_value(@column, @operator, @value)
    end

    def column
      @column
    end

    def columns
      [@column]
    end

    def collect_value_join_sql(joins, options = {})
      @column.collect_value_join_sql(joins, options)
    end

    def opposite
      ComparisonWithValue.new(@column, @operator.opposite, @value)
    end

    def is_equality?
      @operator.is_equality?
    end

    def comparisons
      [self]
    end
  end

  class ComparisonWithPLV < Delegator
    def initialize(column, operator, plv)
      @plv = plv
      @column = column
      @operator = operator

      @__delegate__ = @plv.compare_with(column, operator)
    end

    def __getobj__
      @__delegate__
    end

    def uses_plv?(plv)
      @plv.uses?(plv)
    end

    def plv_display_name
      @plv.display_name
    end

    def accept(operation)
      operation.visit_comparison_with_plv(@column, @operator, @plv)
    end

    def to_s
      __getobj__.to_s
    end
  end

  class ComparisonWithNumber < ComparisonWithValue
    def initialize(column, operator, value)
      validate_column_is_card_type_property(column, 'NUMBER ...')
      validate_value_is_numeric(column, value)
      super(column, operator, CardPropertyMqlSupport.card_number(value))
    end

    def to_s
      "#{@column} #{@operator} number #{@value}"
    end

    def accept(operation)
      operation.visit_comparison_with_number(@column, @operator, @value)
    end

    protected
    def validate_column_is_card_type_property(column, value_message)
      unless PropertyType::CardType === column.property_definition.property_type
        raise DomainException.new("Property #{column.name.bold} is not a card relationship property or tree relationship property, only card relationship properties or tree relationship properties can be used in 'column = #{value_message}' clause.", column.project)
      end
    end

    def validate_value_is_numeric(column, value)
      raise DomainException.new("#{value.bold} is not a valid value for #{column.name.bold}. Only numbers can be used as values in a 'column = NUMBER ...' clause", column.project) unless value.to_s =~ /^(\d)+$/
    end
  end

  class ComparisonWithThisCard < ComparisonWithNumber

    def initialize(column, operator, options)
      content_provider = options[:content_provider]

      validate_column_can_be_compared_with_this_card column, content_provider
      validate_column_is_card_type_property column, "THIS CARD"

      if avalibility = content_provider.try(:this_card_condition_availability)
        avalibility.validate "THIS CARD", options[:alert_receiver]
      end

      if ThisCardConditionAvailability::Now === avalibility
        super(column, operator, content_provider.number)
      else
        @column, @operator, @value = column, operator, ''
      end
    end

    def accept(operation)
      operation.visit_this_card_comparison(@column, @operator, @value)
    end

    def to_s
      "#{@column} #{@operator} THIS CARD"
    end

    private

    def validate_column_can_be_compared_with_this_card(column, content_provider)
      property = column.property_definition
      if property.respond_to?(:valid_card_type) && content_provider.respond_to?(:card_type) && content_provider.card_type && property.valid_card_type != content_provider.card_type
        raise DomainException.new("Comparing between property '#{property.name.bold}' and THIS CARD is invalid as they are different types.", column.project)
      end
    end
  end

  class ComparisonWithThisCardProperty < Delegator
    def initialize(column, operator, this_card_property)
      @this_card_property = this_card_property
      @__delegate__ = this_card_property.compare_with(column, operator)
    end

    def __getobj__
      @__delegate__
    end

    def accept(operation)
      operation.visit_this_card_property_comparison(column, operator, @this_card_property)
    end

    def to_s
      "ThisCard[#{@__delegate__.to_s}]"
    end
  end

  class TodayComparison < ComparisonWithValue
    def initialize(column, operator)
      raise DomainException.new("Comparing numeric property #{column.name.bold} with today is not supported", column.project) if column.numeric?
      super(column, operator, Project.current.today.to_s)
    end

    def accept(operation)
      operation.visit_today_comparison(@column, @operator, @value)
    end

    def to_s
      "#{quote(@column)} #{@operator} TODAY"
    end

    def can_be_cached?
      false
    end
  end

  class ExplicitIn < Condition
    include Quoting, SqlHelper

    attr_reader :values, :column

    def initialize(column, values, options = { :original_values => values })
      @column = column
      @values = values
      @options = options
    end

    def to_s
      "#{@column} IN (#{@values.collect{|v| quote(v)}.join(', ')})"
    end

    def to_sql(options = {})
      return '1 != 1' if @values.empty?
      "#{@column.in_column_sql(options)} IN (#{@column.in_comparison_values(@values).join(',')})"
    end

    def collect_value_join_sql(joins, options = {})
      @column.collect_value_join_sql(joins, options)
    end

    def column
      @column
    end

    def accept(operation)
      operation.visit_explicit_in_condition(@column, @values, @options)
    end

    def comparisons
      @values.collect {|value| ComparisonWithValue.new(@column, Operator.equals, value)}
    end

    def columns
      [@column]
    end

  end

  class NumbersExplicitIn < ExplicitIn
    def initialize(column, values)
      @origin_values = values
      super(column, values.map{|v| CardPropertyMqlSupport.card_number(v)})
      unless PropertyType::CardType === @column.property_definition.property_type
        raise DomainException.new("Property #{@column.name.bold} is not relationship property, only relationship properties can be used in 'NUMBERS IN(...)' clause.", column.project)
      end
    end

    def to_s
      "#{@column} NUMBERS IN (#{@origin_values.collect{|v| quote(v)}.join(', ')})"
    end

    def accept(operation)
      operation.visit_explicit_numbers_in_condition(column, @origin_values)
    end
  end

  # This class really does a WHERE EXISTS despite the name. The performance difference in Oracle,
  # particularly when this is nested multiple times, is staggering.
  # TODO: rename this class and associated grammar to WhereExists
  class ImplicitIn < Condition
    include Quoting, SqlHelper, SecureRandomHelper

    def initialize(column, query, options = {})
      @column = column
      @query = query
      @query.validate_as_sub_query_for_comparison_against(@column)
      if PropertyType::CardType === @column.property_definition.property_type
        if ['name', 'number'].include?(@query.columns.first.name.downcase)
          @query.columns.replace([CardIdColumn.new])
        end
      end
    end

    def to_s
      "#{@column} #{@uses_numbers ? 'numbers ' : ''}IN (#{@query.to_s})"
    end

    def to_sql(options = {})
      @query.cast_numeric_columns = options[:cast_numeric_columns]
      select_query = @query.select_column_query(@query.columns.first)

      column_sql = @column.numeric? ? as_number(@column.to_sql(options)) : @column.to_sql(options)
      sub_select = select_query.to_sql(:exclude => [:order_by])

      comparison_column = select_query.columns.first.respond_to?(:column_alias) ? select_query.columns.first.column_alias : select_query.columns.first.column_name
      "EXISTS (SELECT 1 FROM (#{sub_select}) ex1 where ex1.#{comparison_column} = #{column_sql})"
    end

    def collect_value_join_sql(joins, options = {})
      @column.collect_value_join_sql(joins, options)
    end

    def column
      @column
    end

    def accept(operation)
      operation.visit_implicit_in_condition(@column, @query)
    end

    def comparisons
      []
    end

    def columns
      [@column]
    end
  end

  class TaggedWith < Condition
    include Quoting
    attr_reader :tag

    def initialize(tag)
      @tag = tag
    end

    def to_s
      "TAGGED WITH #{quote(@tag)}"
    end

    def accept(operation)
      operation.visit_tagged_with_condition(@tag)
    end

    def to_sql(options = {})
      Card.tag_condition_sql(Project.current, @tag)
    end
  end

  class IsNull < ComparisonWithValue
    def initialize(column)
      super(column, Operator.equals, nil)
    end

    def to_s
      "#{quote(@column)} IS NULL"
    end

    def accept(operation)
      operation.visit_is_null_condition(column)
    end

    def negated_mql
      "#{@column.as_mql} IS NOT NULL"
    end
  end

  module IsCurrentUser
    class RegisteredCurrentUserComparision < ComparisonWithValue

      def initialize(column)
        super(column, Operator.equals, User.current.login)
      end

      def to_s
        "#{quote(@column)} IS CURRENT USER"
      end

      def accept(operation)
        operation.visit_is_current_user_condition(@column, @value)
      end

      def can_be_cached?
        false
      end
    end

    def self.create(column)
      User.current.anonymous? ? IsFalse.new : RegisteredCurrentUserComparision.new(column)
    end
  end

  class IsFalse < Condition

    def to_sql(options = {})
      '1 != 1'
    end

    def opposite
      IsTrue.new
    end
  end

  class IsTrue < Condition

    def to_sql(options = {})
      '1 = 1'
    end

    def opposite
      IsFalse.new
    end
  end


  class InTree < Condition
    def initialize(tree)
      @tree = tree
    end

    def to_s
      "From Tree #{@tree.name}"
    end

    def to_sql(options = {})
      "#{Card.quoted_table_name}.id IN (SELECT card_id FROM tree_belongings WHERE tree_configuration_id = #{@tree.id})"
    end

    def accept(operation)
      operation.visit_in_tree_condition(@tree)
    end
  end

  class InPlan < Condition
    def initialize(plan)
      @plan = plan
      @join_table_name = "card_works"
    end

    def to_s
      "IN #{@plan}"
    end

    def collect_value_join_sql(joins, options = {})
      joins.push join_sql
    end

    def join_sql
      plan_id = @plan.db_identifier
      as = join_table_name_alias(plan_id)
      %{
        LEFT OUTER JOIN #{Work.quoted_table_name} #{as} ON #{as}.project_id = #{Card.quoted_table_name}.project_id
          AND #{as}.card_number = #{Card.quoted_table_name}.#{quote_column_name('number')}
          AND #{as}.plan_id = #{plan_id}
      }
    end

    def to_sql(options={})
      "#{join_table_name_alias(@plan.db_identifier)}.id IS NOT NULL"
    end

    def join_table_name_alias(plan_id)
      "#{@join_table_name}_plan#{plan_id}"
    end

    def accept(operation)
      operation.visit_in_plan_condition(self)
    end

    def quote_column_name(name)
      Work.connection.quote_column_name(name)
    end
    def can_be_cached?
      false
    end
  end


  class SqlCondition < Condition
    def initialize(condition)
      @condition = condition
    end

    def to_sql(options = {})
      bind_variables(@condition)
    end

    def to_s
      to_sql
    end

    def accept(operation)
    end
  end
end
