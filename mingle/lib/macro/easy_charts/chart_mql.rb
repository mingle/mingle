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

module EasyCharts
  class ChartMql

    NOT_SET_VALUE = ['(not set)', 'null']
    THIS_CARD_VALUE = ['THIS CARD', 'THIS CARD']
    TODAY_VALUE = %w(TODAY TODAY)
    CURRENT_USER_VALUE = ['CURRENT USER', 'CURRENT USER']
    SUPPORTED_OPERATORS = [Operator::Equals, Operator::NotEquals, Operator::GreaterThan, Operator::LessThan]

    attr_reader :conditions, :tags, :aggregate, :property

    def initialize(select_values, conditions, tags)
      @property = select_values[:property]
      @aggregate = OpenStruct.new(select_values[:aggregate])
      @conditions = conditions
      @tags = tags
    end

    class << self
      def from(card_query)
        handle_error('FROM clause not supported') if card_query.from.present?
        handle_error('AS OF clause not supported') if card_query.as_of.present?
        select_values = extract_select_values(card_query)
        conditions = card_query.conditions
        chart_conditions, tags = chart_conditions_from(conditions)
        card_type_conditions = chart_conditions.select {|condition| condition.property.instance_of?(CardTypeDefinition)}
        ensure_valid_card_types(card_type_conditions)

        self.new(select_values, chart_conditions, tags)
      end

      def ensure_valid_card_types(card_type_conditions)
        handle_error('Card Type condition not found') if card_type_conditions.empty?
        handle_error('Multiple card type conditions not supported') if card_type_conditions.length > 1
        handle_error('Invalid card type condition') unless card_type_conditions.first.operator == Operator::Equals
        card_type_prop_def = card_type_conditions.first.property
        handle_error('Card Type does not exist') unless card_type_conditions.first.values.all? {|val| card_type_prop_def.contains_value?(val[0])}
      end

      private

      def extract_select_values(card_query)
        handle_error('No SELECT clause given') if card_query.columns.blank?
        handle_error('Invalid SELECT clause') unless card_query.columns.size == 2
        aggregate_function = card_query.columns[1]
        {
            property: card_query.columns[0].name,
            aggregate: {
                function: aggregate_function.function.downcase,
                property: aggregate_function.column_name
            }
        }
      end

      def chart_conditions_from_and(conditions, chart_conditions, tags)
        conditions.conditions.each {|condition| chart_conditions_from(condition, chart_conditions, tags)}
      end

      def chart_conditions_from(condition, chart_conditions = [], tags = [])
        case condition
          when CardQuery::And
            chart_conditions_from_and(condition, chart_conditions, tags)
          when CardQuery::Or
            chart_conditions.push(chart_condition_from_or(condition))
          when CardQuery::ComparisonWithValue
            chart_conditions.push(chart_condition_from_value_comparison(condition))
          when CardQuery::ExplicitIn
            chart_conditions.push(chart_condition_from_explicit_in(condition))
          when CardQuery::Not
            chart_conditions.push(chart_conditions_from_not(condition))
          when CardQuery::ComparisonWithPLV
            chart_conditions.push(chart_conditions_from_plv(condition))
          when CardQuery::TaggedWith
            tags.push(condition.tag)
          else
            handle_error("#{condition.class} condition not supported")
        end
        [chart_conditions, tags]
      end

      def chart_conditions_from_not(condition)
        condition = condition.conditions.first
        case condition
          when CardQuery::ExplicitIn
            chart_condition_from_explicit_in(condition, Operator::NotEquals)
          when CardQuery::IsNull
            ChartCondition.new(condition.column.property_definition, Operator::NotEquals, [NOT_SET_VALUE])
          else
            handle_error('Invalid NOT condition') unless condition.instance_of? CardQuery::ExplicitIn
        end
      end

      def chart_condition_from_explicit_in(condition, operator = Operator::Equals)
        ChartCondition.new(condition.column.property_definition, operator, to_values(condition.values, condition.column.property_definition))
      end

      def chart_condition_from_value_comparison(condition)
        handle_error("#{condition.operator.class.name.upcase} operator not supported") unless SUPPORTED_OPERATORS.include?(condition.operator.class)
        values =[]
        case condition
          when CardQuery::IsCurrentUser::RegisteredCurrentUserComparision
            values.push CURRENT_USER_VALUE
          when CardQuery::TodayComparison
            values.push TODAY_VALUE
          when CardQuery::ComparisonWithThisCard
            values.push THIS_CARD_VALUE
          when CardQuery::IsNull
            values.push NOT_SET_VALUE
          else
            values.push to_value(condition.value, condition.column.property_definition)
        end
        ChartCondition.new(condition.column.property_definition, condition.operator.class, values)
      end

      def chart_conditions_from_plv(condition)
        ChartCondition.new(condition.column.property_definition, condition.operator.class, [[condition.plv_display_name, condition.plv_display_name]])
      end

      def get_values_from_or_condition(conditions, values=[])
        conditions.conditions.each do |condition|
          case condition
            when CardQuery::Or
              get_values_from_or_condition(condition, values)
            when CardQuery::ExplicitIn
              values.push *to_values(condition.values, condition.column.property_definition)
            when CardQuery::IsNull
              values.push NOT_SET_VALUE
            when CardQuery::ComparisonWithPLV
              values.push [condition.plv_display_name, condition.plv_display_name]
            else
              handle_error('Invalid OR condition')
          end
        end
        values
      end

      def chart_condition_from_or(conditions)
        handle_error('Invalid OR condition') unless conditions.columns.map(&:name).uniq.size == 1

        values = get_values_from_or_condition(conditions)
        property_definition = conditions.conditions.last.column.property_definition
        ChartCondition.new(property_definition, Operator::Equals, values)
      end

      def to_values(values, property_definition)
        values.collect {|value| to_value(value, property_definition)}
      end

      def to_value(value, property_definition)
        if value.is_a?(CardPropertyMqlSupport::CardNumber)
          handle_error("Card doesn't exist") unless value.card_id
          card = Project.current.cards.find(value.card_id)
          [card.number_and_name, value.to_s]
        elsif property_definition.is_a? UserPropertyDefinition
          handle_error("#{value} doesn't exist") unless (name = name_for_user(value))
          [name, value]
        elsif property_definition.is_a? DatePropertyDefinition
          [Date.parse_with_hint(value, date_format).strftime(date_format), value.to_s]
        else
          [value, value]
        end
      end

      def date_format
        @date_format ||= Project.current.date_format
      end

      def name_for_user(login)
        @users ||= {}
        @users[login] ||= (Project.current.users.find_by_login(login).name rescue nil)
      end

      def handle_error(message)
        raise InvalidChartMqlException.new(message)
      end
    end
  end

  class InvalidChartMqlException < Exception

  end
end
