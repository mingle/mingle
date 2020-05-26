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

require 'ast'
require 'ast/sql/table'
require 'ast/sql/statement'
require 'ast/sql/transformer'

module Ast
  module Sql
    include Ast

    def sql_ast(*statements)
      statements(*statements)
    end

    def count(column=nil, as=nil)
      aggregate('count', (column || column('*')), as)
    end

    def sum(column, as=nil)
      aggregate('sum', column, as)
    end
    def avg(column, as=nil)
      aggregate('avg', column, as)
    end
    def max(column, as=nil)
      aggregate('max', column, as)
    end
    def min(column, as=nil)
      aggregate('min', column, as)
    end

    def aggregate(func, column, as)
      node(:aggregate, :function => func, :column => column, :as => as)
    end

    def statements(*args)
      statements = args.first.is_a?(Array) && args.length == 1 ? args.first : args
      node(:statements, statements.compact)
    end

    def select(*columns)
      node(:select, :columns => columns)
    end

    def where(condition)
      node(:where, condition)
    end

    def column(name, options={})
      node(:column, options.merge(:name => name))
    end

    def table(name, options={})
      Table.new(name, self, options)
    end

    def from(table)
      case table
      when Hash
        node(:from, table)
      when Table
        node(:from, :table => table.name)
      else
        node(:from, :table => table.to_s)
      end
    end

    def group_by(*columns)
      columns.empty? ? nil : node(:group_by, columns)
    end

    def condition(left, op, right)
      node(:comparision, [left, op, right])
    end

    def comp(name, *condtions)
      node(name.to_sym, condtions)
    end

    def union_all(*queries)
      comp(:union_all, *queries)
    end

    def eq(left, right)
      condition(left, '=', right)
    end

    def not_eq(left, right)
      condition(left, '!=', right)
    end

    def gt(left, right)
      condition(left, '>', right)
    end

    def lt(left, right)
      condition(left, '<', right)
    end

    def gteq(left, right)
      condition(left, '>=', right)
    end

    def lteq(left, right)
      condition(left, '<=', right)
    end

    def left_outer_join(table, condition)
      join('left outer', table, condition)
    end

    def inner_join(table, condition)
      join('inner', table, condition)
    end

    def join(type, table, condition)
      node(:join, :type => type, :table => table, :on => condition)
    end
    def null
      node(:null)
    end
  end
end
