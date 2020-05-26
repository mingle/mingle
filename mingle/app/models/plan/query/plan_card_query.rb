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
    class NoProjectAssociatedError < StandardError
      def initialize
        super("Your plan must be associated with at least one project.")
      end
    end
    class DiffPropDefDataTypeError < StandardError
    end
    class AggregateNonNumericProperty < StandardError
      def initialize(prop_name)
        super("Property #{prop_name.bold} is not numeric, only numeric properties can be aggregated.")
      end
    end

    # Takes a mql ast to produce a sql ast in plan context
    class PlanCardQuery < Struct.new(:plan, :mql)
      include Ast::Sql
      include Ast::Sql::DataType
      include SelectColumns

      def validate!
        return if @valid
        raise NoProjectAssociatedError.new if plan.program.projects.empty?
        SyntaxValidator.new.validate!(mql)
        validate_property_definitions
        @select_columns = collect_select_columns(mql, plan.program.projects.first)
        validate_aggregate_function_properties
        @valid = true
      end

      def select_columns
        validate!
        @select_columns
      end

      def sql_ast
        validate!
        mql.transform(&sql_ast_transformer)
      end

      private
      def validate_property_definitions
        mql.visit do |t|
          t.match(:property) do |ast|
            proj_properties = plan.program.projects.collect {|proj| [proj.name, proj.find_property_definition_including_card_type_def(ast[:name], :with_hidden => true)] }
            validate_all_projects_have_prop(ast[:name], proj_properties)
            validate_all_projects_have_same_type_prop(ast[:name], proj_properties)
          end
        end
      end

      def validate_all_projects_have_same_type_prop(prop_name, proj_properties)
        return true if proj_properties.size < 2
        sample_proj_name, sample_prop = proj_properties.first
        proj_properties[1..-1].each do |proj_name, prop|
          if prop.class != sample_prop.class || numeric_prop?(prop) != numeric_prop?(sample_prop)
            msg = "Property #{prop_name.bold}'s type is different in projects: #{sample_proj_name} and #{proj_name}"
            raise DiffPropDefDataTypeError, msg
          end
        end
      end

      def validate_all_projects_have_prop(prop_name, proj_properties)
        no_prop_project_names = proj_properties.select {|proj_name, prop| prop.nil?}.collect {|proj_name, _| proj_name}
        unless no_prop_project_names.blank?
          msg = "Card property '#{prop_name.bold}' does not exist in projects: #{no_prop_project_names.bold.to_sentence}!"
          raise Project::NoSuchPropertyError, msg
        end
      end

      def validate_aggregate_function_properties
        @select_columns.each do |column|
          if aggregate_node[column] && column.ast[:property] != '*'
            prop = column.ast[:property]
            raise AggregateNonNumericProperty.new(prop.ast[:name]) unless prop.ast[:numeric]
          end
        end
      end

      def sql_ast_transformer
        @group_by_columns = []
        lambda do |t|
          t.match(:statements) do |statements|
            select = statements.find {|s| s.name == :select}
            statements(select, from_program_project_cards, group_by(*@group_by_columns))
          end
          t.match(:select) do |node|
            if node[:columns].any?(&aggregate_node)
              @group_by_columns.concat node[:columns].reject(&aggregate_node)
            end
            node(:select, node)
          end
          t.match(:aggregate) { |node| aggregate(node[:function], node[:property], aggregate_alias_name(node)) }
          t.match('*') {|star| column(star)}
          t.match(:property) { |ast| column(ast[:name]) }
        end
      end

      def numeric_prop?(prop)
        prop.numeric? || false
      end

      def from_program_project_cards
        queries = plan.program.projects.collect { |project| ProjectCardQuery.new(project_level_mql, project) }.collect(&:sql_ast)
        from(:as => 'plan_cards', :query => union_all(*queries))
      end

      def aggregate_node
        lambda {|n| n.name == :aggregate}
      end

      def project_level_mql
        mql.transform do |t|
          t.match(:statements) do |statements|
            select = statements.find {|s| s.name == :select}
            where = statements.find {|s| s.name == :where}
            statements(select, node(:join, :plan => plan), where)
          end
          t.match(:aggregate) {|node| node[:property] }
          t.match('*') {|n| node(:property, :name => 'number')}
        end
      end
    end
  end
end
