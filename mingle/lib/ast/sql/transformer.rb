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

module Ast
  module Sql
    module DataType
      CHAR = 'char'
      DATE = 'date'
      NUMBER = 'number'
      INTEGER = 'integer'
      TIMESTAMP = 'timestamp'

      def data_type(node)
        ast = node.is_a?(Node) ? node.ast : node
        ast[:data_type] || ast[:column_type]
      end

      def cast_column?(ast)
        ast[:data_type] && ast[:column_type] && ast[:data_type] != ast[:column_type]
      end

      def cast_column_method(node)
        "cast_#{node[:column_type]}_to_#{node[:data_type]}"
      end
    end

    class Transformer < Transform
      include Ast
      include DataType
      NULL_COMPARATORS = {'=' => 'IS', '!=' => 'IS NOT'}

      def initialize(engine)
        @engine = engine
        match(:statements) { |node| node.compact.tap{|n| Statement.validate(n)}.sort.join(' ') }
        match(:select) { |node| Statement.select("SELECT #{node[:columns].uniq.join(', ')}") }
        match(:from, :query => any, :as => any) {|node| Statement.from "FROM (#{node[:query]}) " + @engine.quote_table_name(node[:as])}
        match(:from) { |node| Statement.from 'FROM ' + @engine.quote_table_name(node[:table]) }
        match(:join, :type => any) { |join| Statement.join join_sql(join) }
        match(:where) {|ast| Statement.where "WHERE #{ast}" }
        match(:group_by) {|columns| Statement.group_by("GROUP BY #{columns.uniq.join(', ')}") }

        match(:aggregate) do |node|
          r = "#{node[:function].upcase}(#{node[:column]})"
          r = "#{r} AS #{@engine.quote_column_name(node[:as])}" if node[:as]
          r
        end
        match(:union_all) { |tables| tables.join("\nUNION ALL\n")}
        match(:column) { |node| column_name(node) }
        match(:and) { |node| '(' + node.join(' AND ') + ')' }
        match(:or) { |node| '(' + node.join(' OR ') + ')' }
        match(:comparision, [any, any, :null]) do |column, op, value|
          [column, (NULL_COMPARATORS[op] || op), value].join(' ')
        end
        match(:comparision, [case_insensitive_char_column, any, a_node]) do |column, op, column2|
          [@engine.lower(column), op, @engine.lower(column2)].join(' ')
        end
        match(:comparision, [case_insensitive_char_column, any, any]) do |column, op, value|
          [@engine.lower(column), op, @engine.quote(value.to_s.downcase)].join(' ')
        end
        match(:comparision, [date_column, any, String]) do |column, op, value|
          quote_value_comparision(column, op, Date.parse(value))
        end
        match(:comparision, [date_column, any, Date]) { |array| quote_value_comparision(*array) }
        match(:comparision, [char_column, any, not_a_node]) { |array| quote_value_comparision(*array) }
        match(:comparision) { |array| array.join(' ') }
        match(:null) { 'NULL' }
      end

      def quote_value_comparision(column, op, value)
        [column, op, @engine.quote(value)].join(' ')
      end

      def date_column
        lambda {|n| DATE == data_type(n)}
      end

      def char_column
        lambda {|n| CHAR == data_type(n)}
      end

      def case_insensitive_char_column
         lambda do |node|
           node.name == :column && data_type(node) == CHAR && case_insensitive?(node)
         end
      end

      def case_insensitive?(node)
        node.ast[:case_insensitive]
      end

      def column_name(node)
        return node[:name] if node[:name] == '*'
        name = @engine.quote_column_name(node[:name])
        name = @engine.quote_table_name(node[:table]) + '.' + name if node[:table]
        name = @engine.send(cast_column_method(node), name) if cast_column?(node)
        name = name + ' AS ' + @engine.quote_column_name(node[:as]) if node[:as] && node[:as].downcase != node[:name].downcase
        name
      end

      def join_sql(join)
        table_name = @engine.quote_table_name(join[:table].name)
        table_name = table_name + ' ' + @engine.quote_table_name(join[:table].alias_name) if join[:table].alias_name
        join[:type].upcase + ' JOIN ' + table_name + ' ON ' + join[:on]
      end

    end
  end
end
