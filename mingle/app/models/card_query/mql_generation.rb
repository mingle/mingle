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
  class MqlGeneration < Visitor

    def initialize(acceptor)
      acceptor.accept(self)
    end

    def execute
      [].tap do |result|
        result << ["SELECT", @distinct].compact.join(' ') if @walking_whole_query && columns_mql.any?
        result << columns_mql.join(', ') if columns_mql.any?
        result << "AS OF '#{@as_of_date}'" if @as_of_date
        result << @in_tree_condition if @in_tree_condition
        result << "WHERE" if (@walking_whole_query || @include_where_if_conditions_exist) && result.any? && conditions_mql.any?
        result << conditions_mql.join(' ') if conditions_mql.any?
        result << "GROUP BY #{group_by_columns_mql.join(', ')}" if group_by_columns_mql.any?
        # TODO: I'm assuming that the ['foo'] is unintentional.
        result << %{ORDER BY #{order_by_columns_mql.join(', ')}} unless (order_by_columns_mql.empty? || order_by_columns_mql == ['foo'])
      end.join(' ')
    end

    def visit_card_query(query)
      @walking_whole_query = true
      @distinct = 'DISTINCT' if query.distinct?
      @as_of_date = query.as_of_string if query.as_of_string
    end

    def visit_column(property_definition)
      columns_mql << property_definition.name.as_mql
    end

    def visit_id_column
      columns_mql << "NUMBER"
    end

    def visit_group_by_column(property_definition)
      group_by_columns_mql << property_definition.name.as_mql
    end

    def visit_order_by_column(property_definition, order, is_default)
      order_by_columns_mql << property_definition.name.as_mql unless is_default
    end

    def visit_aggregate_function(function, property_definition)
      columns_mql << "#{function}(#{property_definition.name.as_mql})"
    end

    def visit_count_all_aggregate
      columns_mql << "COUNT(*)"
    end

    def visit_comparison_with_column(column1, operator, column2)
      conditions_mql << "#{translate(column1)} #{operator.as_mql} PROPERTY #{translate(column2)}"
    end

    def visit_comparison_with_plv(column, operator, card_query_plv)
      conditions_mql << "#{translate(column)} #{operator.as_mql} #{card_query_plv.display_name}"
    end

    def visit_comparison_with_value(column, operator, value)
      conditions_mql << "#{translate(column)} #{operator.as_mql} #{value.to_s.as_mql}"
    end

    def visit_comparison_with_number(column, operator, value)
      conditions_mql << "#{translate(column)} #{operator.as_mql} NUMBER #{value}"
    end

    def visit_this_card_comparison(column, operator, value)
      visit_comparison_with_number column, operator, value.to_s
    end

    def visit_this_card_property_comparison(column, operator, this_card_property)
      value = this_card_property.url_identifier
      if value.blank?
        visit_is_null_condition(column)
      else
        if column.property_definition.property_type.kind_of?(PropertyType::CardType)
          visit_comparison_with_number column, operator, value
        else
          visit_comparison_with_value column, operator, value
        end
      end
    end

    def visit_today_comparison(column, operator, current_time)
      mql = case operator
      when Operator::Equals
        "#{translate(column)} IS TODAY"
      when Operator::NotEquals
        "#{translate(column)} IS NOT TODAY"
      else
        "#{translate(column)} #{operator.as_mql} TODAY"
      end
      conditions_mql << mql
    end

    def visit_and_condition(*conditions)
      conditions_mql << conditions.collect { |condition| translate(condition) }.join(' AND ')
    end

    def visit_from_tree_condition(tree_condition, other_conditions)
      @include_where_if_conditions_exist = true
      @in_tree_condition = translate(tree_condition)
      visit_and_condition(*other_conditions) if other_conditions.any?
    end

    def visit_or_condition(*conditions)
      conditions_mql << "(#{conditions.collect { |condition| "(#{translate(condition)})" }.join(' OR ')})"
    end

    def visit_not_condition(negated_condition)
      mql = case negated_condition
      when CardQuery::IsNull
        "#{translate(negated_condition.column)} IS NOT NULL"
      else
        "NOT #{translate(negated_condition)}"
      end
      conditions_mql << mql
    end

    def visit_explicit_in_condition(column, values, options = {})
      conditions_mql << "#{translate(column)} IN (#{values.collect(&:as_mql).join(', ')})"
    end

    def visit_explicit_numbers_in_condition(column, values)
      conditions_mql << "#{translate(column)} NUMBER IN (#{values.join(', ')})"
    end

    def visit_implicit_in_condition(column, query)
      uses_numbers = (PropertyType::CardType === column.property_definition.property_type) && query.columns.first.name == 'Number'
      conditions_mql << "#{translate(column)} #{uses_numbers ? 'NUMBERS' : ''} IN (#{translate(query)})"
    end

    def visit_tagged_with_condition(tag)
      conditions_mql << "TAGGED WITH #{tag.as_mql}"
    end

    def visit_is_null_condition(column)
      conditions_mql << "#{translate(column)} IS NULL"
    end

    def visit_is_current_user_condition(column, current_user_login)
      conditions_mql << "#{translate(column)} IS CURRENT USER"
    end

    def visit_in_tree_condition(tree)
      @include_where_if_conditions_exist = true
      in_tree tree.name
    end

    def -(another)
      return self.execute unless !another.blank?
      return "(#{self.execute}) AND NOT NUMBER IN (SELECT number where #{another.execute})"
    end

    protected
    def translate(acceptor) #translates a sub-tree
      MqlGeneration.new(acceptor).execute
    end

    def in_tree(tree_name)
      @in_tree_condition = "FROM TREE #{tree_name.as_mql}"
    end

    def columns_mql
      @columns_mql ||= []
    end

    def conditions_mql
      @conditions_mql ||= []
    end

    def order_by_columns_mql
      @order_by_columns_mql ||= []
    end

    def group_by_columns_mql
      @group_by_columns_mql ||= []
    end
  end
end
