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

require File.expand_path(File.dirname(__FILE__) + '/../../../simple_test_helper')
require 'ast/sql'

class Ast::Sql::TransformerTest < Test::Unit::TestCase
  include Ast::Sql

  def test_simple_select_column_ast
    users = table('users')
    ast = sql_ast(select(users['number']), from(users))
    assert_equal %{SELECT 'users'."number" FROM 'users'}, to_sql(ast)
  end

  def test_simple_select_count
    users = table('users')
    ast = sql_ast(select(count), from(users))
    assert_equal %{SELECT COUNT(*) FROM 'users'}, to_sql(ast)

    ast = sql_ast(select(count(column('name'))), from(users))
    assert_equal %{SELECT COUNT("name") FROM 'users'}, to_sql(ast)
  end

  def test_give_aggregate_function_an_alias_name
    users = table('users')
    ast = sql_ast(select(count(column('name'), 'count(name)')), from(users))
    assert_equal %{SELECT COUNT("name") AS "count(name)" FROM 'users'}, to_sql(ast)

    ast = sql_ast(select(sum(column('name'), 'sum(name)')), from(users))
    assert_equal %{SELECT SUM("name") AS "sum(name)" FROM 'users'}, to_sql(ast)

    ast = sql_ast(select(avg(column('name'), 'avg(name)')), from(users))
    assert_equal %{SELECT AVG("name") AS "avg(name)" FROM 'users'}, to_sql(ast)

    ast = sql_ast(select(max(column('name'), 'max(name)')), from(users))
    assert_equal %{SELECT MAX("name") AS "max(name)" FROM 'users'}, to_sql(ast)

    ast = sql_ast(select(min(column('name'), 'min(name)')), from(users))
    assert_equal %{SELECT MIN("name") AS "min(name)" FROM 'users'}, to_sql(ast)
  end

  def test_simple_select_sum
    users = table('users')
    ast = sql_ast(select(sum(column('size'))), from(users))
    assert_equal %{SELECT SUM("size") FROM 'users'}, to_sql(ast)
  end

  def test_simple_select_avg_min_max
    users = table('users')
    ast = sql_ast(select(avg(column('size'))), from(users))
    assert_equal %{SELECT AVG("size") FROM 'users'}, to_sql(ast)

    ast = sql_ast(select(min(column('size'))), from(users))
    assert_equal %{SELECT MIN("size") FROM 'users'}, to_sql(ast)

    ast = sql_ast(select(max(column('size'))), from(users))
    assert_equal %{SELECT MAX("size") FROM 'users'}, to_sql(ast)
  end

  def test_column_alias
    users = table('users')
    ast = sql_ast(select(column('number', :as => 'n')), from(users))
    assert_equal %{SELECT "number" AS "n" FROM 'users'}, to_sql(ast)
  end

  def test_should_ignore_alias_if_column_name_is_same_with_alias
    users = table('users')
    ast = sql_ast(select(column('number', :as => 'number')), from(users))
    assert_equal %{SELECT "number" FROM 'users'}, to_sql(ast)

    ast = sql_ast(select(column('number', :as => 'Number')), from(users))
    assert_equal %{SELECT "number" FROM 'users'}, to_sql(ast)
  end

  def test_alias_table_name
    works = table('works', :as => 'user_works')
    users = table('users')
    ast = sql_ast select(column('number')), from(users), left_outer_join(works, eq(works['uid'], users['id']))
    assert_equal %{SELECT "number" FROM 'users' LEFT OUTER JOIN 'works' 'user_works' ON 'user_works'."uid" = 'users'."id"}, to_sql(ast)
  end

  def test_table_column_alias
    users = table('users')
    ast = sql_ast(select(users.column('number', :as => 'n')), from(users))
    assert_equal %{SELECT 'users'."number" AS "n" FROM 'users'}, to_sql(ast)
  end

  def test_select_multi_columns
    users = table('users')
    ast = sql_ast select(column('number'), column('name')), from(users)
    assert_equal %{SELECT "number", "name" FROM 'users'}, to_sql(ast)
  end

  def test_left_outer_join
    works = table('works')
    users = table('users')
    ast = sql_ast select(column('number')), from(users), left_outer_join(works, eq(works['uid'], users['id']))
    assert_equal %{SELECT "number" FROM 'users' LEFT OUTER JOIN 'works' ON 'works'."uid" = 'users'."id"}, to_sql(ast)
  end

  def test_inner_join
    users = table('users')
    works = table('works')
    ast = sql_ast select(column('number')), from(users), inner_join(works, not_eq(works['uid'], users['id']))
    assert_equal %{SELECT "number" FROM 'users' INNER JOIN 'works' ON 'works'."uid" != 'users'."id"}, to_sql(ast)
  end

  def test_inner_join_on_conditions
    users = table('users')
    works = table('works')
    cond1 = gt(works['user_id'], users['id'])
    cond2 = lt(works['pid'], 1)
    cond3 = gteq(works['uid'], 2)
    cond4 = lteq(works['uid'], 5)
    ast = sql_ast(select(column('number')), from(users), inner_join(works, comp(:and, cond1, cond2, cond3, cond4)))
    assert_equal <<-SQL.strip, to_sql(ast)
SELECT "number" FROM 'users' INNER JOIN 'works' ON ('works'."user_id" > 'users'."id" AND 'works'."pid" < 1 AND 'works'."uid" >= 2 AND 'works'."uid" <= 5)
SQL
  end

  def test_union_all_tables
    sub_table_queries = []
    3.times do |index|
      sub_table_queries << sql_ast(select(column('number')), from(table("users_#{index}")))
    end
    ast = sql_ast(select(column('number')), from(:as => 'users', :query => union_all(sub_table_queries)))
    sub_table_queries_sql = <<-SQL
SELECT "number" FROM 'users_0'
UNION ALL
SELECT "number" FROM 'users_1'
UNION ALL
SELECT "number" FROM 'users_2'
SQL
    assert_equal %{SELECT "number" FROM (#{sub_table_queries_sql.strip}) 'users'}, to_sql(ast)
  end

  def test_simple_where_condition
    users = table('users')
    ast = sql_ast(select(column('number')), from(users), where(eq(column('number'), 1)))
    assert_equal %{SELECT "number" FROM 'users' WHERE "number" = 1}, to_sql(ast)
  end

  def test_or_condition
    users = table('users')
    ast = sql_ast(select(column('number')), from(users), where(comp(:or, eq(column('number'), 1), eq(column('size'), 2))))
    assert_equal %{SELECT "number" FROM 'users' WHERE ("number" = 1 OR "size" = 2)}, to_sql(ast)
  end

  def test_should_format_condition_value_by_column_comparison_type
    users = table('users')
    ast = sql_ast(select(column('number')), from(users), where(eq(column('name', :data_type => 'char', :column_type => 'char'), 'card name')))
    assert_equal %{SELECT "number" FROM 'users' WHERE "name" = 'card name'}, to_sql(ast)
  end

  def test_should_not_format_column_as_condition_value
    users = table('users')
    ast = sql_ast(select(column('number')), from(users), where(eq(column('name', :data_type => 'char', :column_type => 'char'), column('oo', :data_type => 'char', :column_type => 'char'))))
    assert_equal %{SELECT "number" FROM 'users' WHERE "name" = "oo"}, to_sql(ast)
  end

  def test_should_format_date_type_condition_value
    users = table('users')
    ast = sql_ast(select(column('number')), from(users), where(eq(column('due date', :data_type => 'date', :column_type => 'date'), Date.parse('2010-10-21'))))
    assert_equal %{SELECT "number" FROM 'users' WHERE "due date" = '2010-10-21'}, to_sql(ast)
  end

  def test_should_convert_date_type_condition_value_if_its_string
    users = table('users')
    ast = sql_ast(select(column('number')), from(users), where(eq(column('due date', :data_type => 'date', :column_type => 'date'), '21 Oct 2011')))
    assert_equal %{SELECT "number" FROM 'users' WHERE "due date" = '2011-10-21'}, to_sql(ast)
  end

  def test_should_treat_column_type_same_with_data_type_when_column_type_is_not_defined
    users = table('users')
    ast = sql_ast(select(column('number')), from(users), where(eq(column('estimate', :data_type => 'number'), '1')))
    assert_equal %{SELECT "number" FROM 'users' WHERE "estimate" = 1}, to_sql(ast)
  end

  def test_should_format_column_when_data_type_is_different_with_column_type
    users = table('users')
    ast = sql_ast(select(column('number')), from(users), where(eq(column('estimate', :data_type => 'number', :column_type => 'char'), '1')))
    assert_equal %{SELECT "number" FROM 'users' WHERE AS_NUMBER("estimate") = 1}, to_sql(ast)
  end

  def test_should_format_column_value_by_column_type_when_data_type_is_nil
    users = table('users')
    ast = sql_ast(select(column('number')), from(users), where(eq(column('estimate', :column_type => 'char'), '1')))
    assert_equal %{SELECT "number" FROM 'users' WHERE "estimate" = '1'}, to_sql(ast)
  end

  def test_mark_column_as_case_insensitive_for_char_type
    users = table('users')
    ast = sql_ast(select(column('number')), from(users), where(eq(column('status', :data_type => 'char', :column_type => 'char', :case_insensitive => true), 'NEW')))
    assert_equal %{SELECT "number" FROM 'users' WHERE LOWER("status") = 'new'}, to_sql(ast)
  end

  def test_mark_column_compare_column_as_case_insensitive
    users = table('users')
    c1 = column('c1', :data_type => 'char', :column_type => 'char', :case_insensitive => true)
    c2 = column('c2', :data_type => 'char', :column_type => 'char', :case_insensitive => true)
    ast = sql_ast(select(column('number')), from(users), where(eq(c1, c2)))
    assert_equal %{SELECT "number" FROM 'users' WHERE LOWER("c1") = LOWER("c2")}, to_sql(ast)
  end

  def test_ignore_case_insensitive_when_column_data_type_is_not_char
    users = table('users')
    ast = sql_ast(select(column('number')), from(users), where(eq(column('status', :data_type => 'number', :column_type => 'char', :case_insensitive => true), '1')))
    assert_equal %{SELECT "number" FROM 'users' WHERE AS_NUMBER("status") = 1}, to_sql(ast)

    ast = sql_ast(select(column('number')), from(users), where(eq(column('status', :data_type => 'number', :column_type => 'char', :case_insensitive => true), null)))
    assert_equal %{SELECT "number" FROM 'users' WHERE AS_NUMBER("status") IS NULL}, to_sql(ast)
  end

  def test_mark_column_as_case_insensitive_when_no_data_type_but_column_type_is_char
    users = table('users')
    ast = sql_ast(select(column('number')), from(users), where(eq(column('status', :column_type => 'char', :case_insensitive => true), 'New')))
    assert_equal %{SELECT "number" FROM 'users' WHERE LOWER("status") = 'new'}, to_sql(ast)
  end

  def test_eq_null
    users = table('users')
    ast = sql_ast(select(column('number')), from(users), where(eq(column('name'), null)))
    assert_equal %{SELECT "number" FROM 'users' WHERE "name" IS NULL}, to_sql(ast)
  end

  def test_not_eq_null
    users = table('users')
    ast = sql_ast(select(column('number')), from(users), where(not_eq(column('name'), null)))
    assert_equal %{SELECT "number" FROM 'users' WHERE "name" IS NOT NULL}, to_sql(ast)
  end

  def test_null_comparison_only_support_eq_and_not_eq
    users = table('users')
    ast = sql_ast(select(column('number')), from(users), where(lt(column('name'), null)))
    assert_equal %{SELECT "number" FROM 'users' WHERE "name" < NULL}, to_sql(ast)
  end

  def test_the_order_of_statements_should_not_matter
    users = table('users')
    works = table('works')
    ast = sql_ast(from(users), where(eq(column('number'), 1)), select(users['number']), inner_join(works, not_eq(works['uid'], users['id'])))
    assert_equal %{SELECT 'users'."number" FROM 'users' INNER JOIN 'works' ON 'works'."uid" != 'users'."id" WHERE "number" = 1}, to_sql(ast)
  end

  def test_should_validate_statements
    users = table('users')
    ast = sql_ast(select(users['number']))
    assert_raise Ast::Sql::InvalidStatementsError do
      to_sql(ast)
    end
  end

  def test_should_be_able_to_pass_array_as_statements_argument
    users = table('users')
    ast = sql_ast([select(users['number']), from(users)])
    assert_equal %{SELECT 'users'."number" FROM 'users'}, to_sql(ast)
  end

  def test_should_ignore_nil_when_build_statements_node
    assert_equal statements(select(column('number'))), statements(select(column('number')), nil)
  end

  def test_group_by_column
    users = table('users')
    ast = sql_ast(select(count), from(users), group_by(column('name'), column('number')))
    assert_equal %{SELECT COUNT(*) FROM 'users' GROUP BY "name", "number"}, to_sql(ast)
  end

  def test_should_ignore_group_by_when_group_by_columns_is_blank
    users = table('users')
    ast = sql_ast(select(count), from(users), group_by)
    assert_equal %{SELECT COUNT(*) FROM 'users'}, to_sql(ast)
  end

  def test_should_remove_dup_select_columns
    users = table('users')
    ast = sql_ast(select(count), from(users), group_by(column('name'), column('number'), column('number')))
    assert_equal %{SELECT COUNT(*) FROM 'users' GROUP BY "name", "number"}, to_sql(ast)
  end

  def test_should_remove_dup_group_by_columns
    users = table('users')
    ast = sql_ast(select(users['number'], users['number']), from(users))
    assert_equal %{SELECT 'users'."number" FROM 'users'}, to_sql(ast)
  end

  def test_uniq_joins
    works = table('works')
    users = table('users')

    ast1 = left_outer_join(table('works'), eq(works['uid'], users['id']))
    ast2 = left_outer_join(table('works'), eq(works['uid'], users['id']))
    assert_equal 1, [ast1, ast2].uniq.size
  end

  def test_table_eql_and_hash
    assert_equal table('works'), table('works')
    assert_equal table('works').hash, table('works').hash
    assert_equal table('works', :as => 'w'), table('works', :as => 'w')
    assert_equal table('works', :as => 'w').hash, table('works', :as => 'w').hash
    assert_not_equal table('works', :as => 'w'), table('works', :as => 'w2')
    assert_not_equal table('works', :as => 'w').hash, table('works', :as => 'w2').hash
    assert_not_equal table('works'), table('users')
    assert_not_equal table('works').hash, table('users').hash
  end

  def to_sql(ast)
    Transformer.new(self).apply(ast)
  end

  # engine interface
  # cast <data_type> to <another_data_type>
  def cast_char_to_number(value)
    "AS_NUMBER(#{value})"
  end
  def quote_column_name(name)
    name.inspect
  end
  def quote_table_name(name)
    "'#{name}'"
  end
  def quote(value)
    "'#{value}'"
  end
  def lower(value)
    "LOWER(#{value})"
  end
end
