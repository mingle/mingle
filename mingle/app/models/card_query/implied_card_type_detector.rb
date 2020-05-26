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
  class ImpliedCardTypeDetector < Visitor

    def initialize(acceptor)
      acceptor.accept(self)
    end

    def execute
      CardType.find_by_sql ["SELECT * FROM card_types WHERE project_id = #{Project.current.id}", *conditions_mql].join(' AND ')
    end

    def visit_comparison_with_value(column, operator, value)
      case (prop_def = column.property_definition)
        when CardTypeDefinition
          explicit_conditions_mql << operator.to_sql('position', card_type_named(value).position, true)
        when TreeRelationshipPropertyDefinition
          implicit_conditions_mql << any_card_type_condition(prop_def.tree_configuration.card_types_after(prop_def.valid_card_type))
        else
          implicit_conditions_mql << all_card_types_condition
        end
    end

    def visit_comparison_with_number(column, operator, value)
      implicit_conditions_mql << case (prop_def = column.property_definition)
        when TreeRelationshipPropertyDefinition
          any_card_type_condition(prop_def.tree_configuration.card_types_after(prop_def.valid_card_type))
        else
          no_card_types_condition
        end
    end

    def visit_comparison_with_plv(column, operator, plv)
      implicit_conditions_mql << if column.property_definition.class == CardTypeDefinition
        operator.to_sql('position', card_type_named(plv.to_s).position, true)
      else
        all_card_types_condition
      end
    end

    def visit_comparison_with_column(column1, operator, column2)
      type_column = [column1, column2].detect { |c| c.property_definition.class == CardTypeDefinition }
      non_type_column = ([column1, column2] - [type_column])[0]
      if (type_column)
        possible_values = ActiveRecord::Base.connection.select_values "SELECT DISTINCT #{non_type_column.column_name} FROM #{Card.quoted_table_name} WHERE #{non_type_column.column_name} IS NOT NULL"
        visit_explicit_in_condition(type_column, possible_values)
      else
        implicit_conditions_mql << all_card_types_condition
      end
    end

    def visit_tagged_with_condition(tags)
      implicit_conditions_mql << all_card_types_condition
    end

    def visit_and_condition(*conditions)
      result = conditions.collect { |c| translate_conditions(c).conditions_mql }.flatten.collect(&:in_parenthesis).join(" AND ")
      implicit_conditions_mql << result unless result.blank?
    end

    def visit_from_tree_condition(tree_condition, other_conditions)
      visit_and_condition(tree_condition,*other_conditions)
    end

    def visit_or_condition(*conditions)
      result = conditions.collect { |c| translate_conditions(c).conditions_mql }.flatten.join(" OR ")
      implicit_conditions_mql << result.in_parenthesis unless result.blank?
    end

    def visit_not_condition(negated_condition)
      translated_conditions = translate_conditions(negated_condition)
      if (card_types_to_avoid = translated_conditions.explicit_conditions_mql).any?
        card_types_to_not_avoid = "NOT (#{card_types_to_avoid.join(' OR ')})"
        explicit_conditions_mql << card_types_to_not_avoid
      end
      @implicit_conditions_mql = implicit_conditions_mql + translated_conditions.implicit_conditions_mql.flatten
    end

    def visit_explicit_in_condition(column, values, options = {})
      implicit_conditions_mql << case (prop_def = column.property_definition)
        when CardTypeDefinition
          if values.empty?
            no_card_types_condition
          else
            any_card_type_condition(values.collect { |v| card_type_named(v) })
          end
        when TreeRelationshipPropertyDefinition
          any_card_type_condition(prop_def.tree_configuration.card_types_after(prop_def.valid_card_type))
        else
          all_card_types_condition
        end
    end

    def visit_explicit_numbers_in_condition(column, values)
      implicit_conditions_mql << case (prop_def = column.property_definition)
        when TreeRelationshipPropertyDefinition
          any_card_type_condition(prop_def.tree_configuration.card_types_after(prop_def.valid_card_type))
        else
          no_card_types_condition
        end
    end

    def visit_is_null_condition(column)
      implicit_conditions_mql << if column.property_definition.class == CardTypeDefinition
        no_card_types_condition
      else
        all_card_types_condition
      end
    end

    def visit_in_tree_condition(tree_config)
      implicit_conditions_mql << any_card_type_condition(tree_config.all_card_types)
    end

    def translate_conditions(acceptor) #translates a sub-tree into conditions
      ImpliedCardTypeDetector.new(acceptor)
    end

    def implicit_conditions_mql
      @implicit_conditions_mql ||= []
    end

    def explicit_conditions_mql
      @explicit_conditions_mql ||= []
    end

    def conditions_mql
      implicit_conditions_mql + explicit_conditions_mql
    end

    private
    def card_type_named(name)
      return if name.blank?
      if value = Project.current.card_types.detect { |ct| ct.name.downcase == name.downcase.trim }
        return value
      else
        raise "#{name.bold} is not a valid card type"
      end
    end

    def any_card_type_condition(card_types)
      return no_card_types_condition if card_types.empty?
      card_type_comparisons = card_types.collect(&:position).collect { |pos| Operator::Equals.new.to_sql('position', pos, true) }
      "(#{card_type_comparisons.join(' OR ')})"
    end

    def all_card_types_condition
      "(1=1)"
    end

    def no_card_types_condition
      "(1=0)"
    end
  end
end
