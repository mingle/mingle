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

class Plan
  module Query
    # Take a mql ast to produce a sql ast in a project context
    class ProjectCardQuery
      include Ast::Sql
      include DataType
      include PropertyDefinitionDataType
      include ProjectCardValidator
      include SelectColumns

      def initialize(mql, project)
        @mql, @project = mql, project
        @cards_table = table(@project.cards_table)
      end

      def select_columns
        @select_columns ||= collect_select_columns(@mql, @project)
      end

      def sql_ast
        @joins = []
        @mql.transform(&substitute_property_definitions).
            visit(&before_transform_validator).
            transform(&sql_ast_transformer).
            visit(&sql_ast_validator)
      end

      def sql_ast_transformer
        lambda do |t|
          t.match(:statements) { |ast| statements(ast.concat(@joins.uniq).concat([from(@cards_table)])) }
          t.match(:select, &transform_select_node)
          t.match(:join, :plan => t.any, &join_plan_works)
          t.match(:where, &transform_where_node)
        end
      end

      def substitute_property_definitions
        lambda do |t|
          t.match(:property) do |ast|
            prop = @project.find_property_definition_including_card_type_def(ast[:name], :with_hidden => true)
            @cards_table.column(prop.column_name, prop_def_data_types(prop).merge(:as => ast[:name], :definition => prop, :project => @project))
          end
        end
      end

      def transform_select_node
        lambda do |ast|
          node(:select, ast).transform do |t|
            t.match(:column, :definition => UserPropertyDefinition) { |node| users_login_column(node, node[:as])}
            t.match(:column, :definition => a_card_property_definition) { |node| card_name_column(node, node[:as])}
            t.match(:aggregate) do |node|
              prop_name = node[:property].ast.delete(:as) || node[:property].ast[:name]
              aggregate(node[:function], node[:property], "#{node[:function]}(#{prop_name})")
            end
            t.match('*') {|star| column(star)}
          end
        end
      end

      def transform_where_node
        lambda do |ast|
          node(:where, ast).transform do |t|
            t.match(:comparision, [t.any, t.any, :column]) do |left, op, right|
              cond = condition(left, op, right)
              op == '=' ? comp(:or, cond, comp(:and, condition(left, '=', null), condition(right, '=', null))) : cond
            end
            t.match(:comparision, [t.any, '!=', not_null]) do |column, op, value|
              comp :or, compare_with_value(column, op, value), condition(column, '=', null)
            end
            t.match(:comparision, [t.any, t.any, is_null]) { |array| condition(*array) }
            t.match(:comparision) { |column, op, value| compare_with_value(column, op, value) }

            t.match(:column, :definition => a_card_property_definition) { |node| card_name_column(node)}
            t.match(:column, :definition => UserPropertyDefinition) { |node| users_login_column(node)}
            t.match(:column, :definition => EnumeratedPropertyDefinition, :data_type => CHAR) do |node|
              values_position_column(node[:definition], :join_enum_values)
            end
            t.match(:column, :definition => CardTypeDefinition) { |node| values_position_column(node[:definition], :join_card_types) }
            t.match(:column) { |ast| node(:column, ast.merge(:as => nil, :case_insensitive => case_insensitive?(ast))) }
            t.match(:context, :type => 'user') { |ast| User.current.login}
          end
        end
      end

      def a_card_property_definition
        lambda {|n| [CardRelationshipPropertyDefinition, TreeRelationshipPropertyDefinition].any?{|clazz| n.is_a?(clazz)}}
      end

      def not_null
        lambda {|n| n != null}
      end

      def is_null
        lambda {|n| n == null}
      end

      def case_insensitive?(ast)
        ast[:data_type] == CHAR && !ast[:definition].is_a?(FormulaPropertyDefinition)
      end

      def values_position_column(definition, joins)
        values = send(joins, definition)
        values.column('position', :definition => definition, :column_type => NUMBER)
      end

      def card_name_column(node, as=nil)
        prop_column_join_by_id(node[:definition], @cards_table, 'name', as)
      end

      def users_login_column(node, as=nil)
        prop_column_join_by_id(node[:definition], User, 'login', as)
      end

      def prop_column_join_by_id(prop_def, join_table, column_name, as=nil, column_type=CHAR)
        join_cards = join_by_id(prop_def, join_table)
        join_cards.column(column_name, :as => as, :definition => prop_def, :column_type => column_type, :case_insensitive => true)
      end

      def compare_with_value(column, op, value)
        prop = column.ast[:definition]
        # have to put in this hack, because FormulaPropertyDefinition#comparison_value
        # returns String type and does not convert today to date object
        # Here we have different expectation of comparison_value with CardQuery
        # impelementation, so put in this urgly code before we change CardQuery
        # impelementation to have same expectation
        comparison_value = if prop.is_a?(FormulaPropertyDefinition)
          prop.property_type.get_derived_type(value).find_object(value)
        else
          prop.comparison_value(value)
        end
        condition(column, op, comparison_value)
      end

      def join_card_types(prop_def)
        table(CardType.table_name).tap do |values|
          same_name = eq(values['name'], @cards_table[prop_def.column_name])
          same_proj = eq(values['project_id'], @project.id)
          @joins << left_outer_join(values, comp(:and, same_name, same_proj))
        end
      end

      def join_enum_values(prop_def)
        values_table(prop_def, EnumerationValue).tap do |values|
          same_value = eq(values['value'], @cards_table[prop_def.column_name])
          same_prop  = eq(values['property_definition_id'], prop_def.id)
          @joins << left_outer_join(values, comp(:and, same_value, same_prop))
        end
      end

      def join_by_id(prop_def, table)
        values_table(prop_def, table).tap do |values|
          @joins << left_outer_join(values, eq(values['id'], @cards_table[prop_def.column_name]))
        end
      end

      def values_table(prop_def, table)
        table(table.table_name, :as => prop_def.column_name + '_values')
      end

      def join_plan_works
        lambda do |node|
          works = table(Work.table_name)
          cond1 = eq(works['plan_id'], node[:plan].id)
          cond2 = eq(works['project_id'], @project.id)
          cond3 = eq(works['card_number'], @cards_table['number'])
          inner_join(works, comp(:and, cond1, cond2, cond3))
        end
      end
    end
  end
end
