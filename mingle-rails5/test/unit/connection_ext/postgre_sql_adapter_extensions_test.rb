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

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')
require File.expand_path(File.dirname(__FILE__) + '/database_test_helpers')

class PostgreSQLAdapterExtensionsTest < ActiveSupport::TestCase
  include DatabaseTestHelpers
  use_db :postgresql, 'POSTGRE_ADAPTER_TEST'

  class TestModel < ApplicationRecord

  end

  def teardown
    connection.unstub(:execute)
  end

  def test_safe_table_name_should_return_table_name_with_prefix
    original_prefix = ActiveRecord::Base.table_name_prefix
    ActiveRecord::Base.table_name_prefix = 'test_prefix_'

    assert_equal 'test_prefix_model_name', connection.safe_table_name('model_name')

    ActiveRecord::Base.table_name_prefix = original_prefix
  end

  def test_should_switch_schema_with_case_insensitive_schema_name
    assert_equal 'postgre_adapter_test', connection.current_schema

    connection.switch_schema('PuBLiC')

    assert_equal 'public', connection.current_schema
  end

  def test_schema_exists_should_check_case_insensitive_schema_name
    assert connection.schema_exists?('PubLIC')
    assert connection.schema_exists?('PoSTGrE_ADaptER_Test')
  end

  def test_should_check_case_insensitive_inequality
    first_value = 'PuBLic'
    second_value = 'PUBLICC'
    assert_equal "LOWER(CAST(#{first_value} AS TEXT)) != LOWER(CAST(#{second_value} AS TEXT))", connection.case_insensitive_inequality(first_value, second_value)
  end

  def test_should_check_schemata_with_prefix
    prefix = 'test'
    connection.expects(:select_values).with(SqlHelper.sanitize_sql("SELECT nspname FROM pg_namespace WHERE lower(nspname) LIKE ? ESCAPE '\\'", "#{prefix.downcase}%"))

    connection.schemata_with_prefix(prefix)
  end

  def test_high_precision_number_type_should_retun_numeric
    assert_equal 'NUMERIC', connection.high_precision_number_type
  end

  def test_should_redistribute_project_card_rank
    cards_table = 'cards'
    sql = %Q{
      UPDATE #{cards_table}
         SET project_card_rank = (CAST(? AS NUMERIC) + (sorted.position * CAST(? AS NUMERIC)))
        FROM (SELECT id, row_number() OVER (ORDER BY project_card_rank) AS position FROM #{cards_table}) sorted
       WHERE sorted.id = #{cards_table}.id;
    }

    connection.expects(:execute).with(SqlHelper.sanitize_sql(sql, 1, 5))

    connection.redistribute_project_card_rank(cards_table, 1, 5)
  end

  def test_should_truncate_long_index_name
    index_name = 'this_is_a_really_really_really_really_really_really_really_really_really_really_really_really_long_name'

    assert_equal index_name.shorten(63, 16), connection.index_name(:cards, {name: index_name})
  end

  def test_should_check_for_numeric_property_values
    table_name = 'cards'
    column_name = 'CardRank'
    quoted_table_name = connection.quote_table_name(table_name)
    connection.expects(:select_value).with("SELECT COUNT(*) FROM #{quoted_table_name} WHERE #{connection.is_number(column_name)} OR #{column_name} IS NULL OR TRIM(#{column_name}) = ''").returns(5)
    connection.expects(:select_value).with("SELECT COUNT(*) FROM #{quoted_table_name}").returns(5)

    assert connection.all_property_values_numeric?(table_name, column_name)
  end

  def test_is_number_should_return_numeric_comparison_sql
    expected_sql = "TRIM(cardRank) ~ '^-?(([0-9]+([.][0-9]*)?)|([0-9]*[.][0-9]+))$'"
    assert_equal expected_sql, connection.is_number('cardRank')
  end

  def test_value_ot_of_precision_should_return_value_out_of_precision_sql
    expected_sql = "cardRank ~ '^.*[.][0-9]{11,}$'"
    assert_equal expected_sql, connection.value_out_of_precision('cardRank', 10)
  end

  def test_bulk_insert_should_execute_bulk_insertions
    connection.create_table(:test_models) do |t|
      t.string :name
      t.string :identifier
    end
    data = 2.times.map do
      project_name='project'.uniquify[0..15]
      {name: project_name, identifier: project_name}.with_indifferent_access
    end

    connection.bulk_insert(TestModel, data)
    assert_equal data, TestModel.all.map { |project| {'name' => project.name, 'identifier' => project.identifier} }
  end

  def test_insert_multi_rows_should_insert_multiple_rows
    table_name = 'test_table'
    column_names = %w(foo bar)
    quoted_column_names = connection.quote_column_names(column_names).join(',')
    expected_sql = %{INSERT INTO #{connection.quote_table_name(table_name)} (#{quoted_column_names})
      VALUES ('f1','b1'),\n('f2','b2')}

    connection.expects(:execute).with(expected_sql)

    connection.insert_multi_rows(table_name, column_names, [%w(f1 b1), %w(f2 b2)])
  end

  def test_create_sequence_should_create_sequence_with_counter_when_strict_counter_is_true
    name = 'sequence_name'
    start = 5
    connection.expects(:execute).with("CREATE SEQUENCE #{name} INCREMENT 1 START #{start} CYCLE")
    connection.expects(:execute).with("SELECT SETVAL('#{name}', #{start}, true)")

    connection.create_sequence(name, start, strict_counter: true)
  end

  def test_create_sequence_should_create_sequence_without_counter_when_strict_counter_is_false
    name = 'sequence_name'
    start = 5
    connection.expects(:execute).with("CREATE SEQUENCE #{name} INCREMENT 1 START #{start}")
    connection.expects(:execute).with("SELECT SETVAL('#{name}', #{start}, true)")

    connection.create_sequence(name, start)
  end

  def test_drop_sequence_should_drop_the_given_sequence
    connection.expects(:execute).with('DROP SEQUENCE test')

    connection.drop_sequence('test')
  end

  def test_sequence_exists_should_check_for_sequence_existence
    connection.expects(:execute).with("SELECT COUNT(*) FROM pg_class where relname = 'dependency'").returns([{:count => '1'}])

    assert connection.sequence_exists?('dependency')
  end

  def test_next_sequence_value_should_return_next_sequence_value_sql
    assert_equal "nextval('sequence_name')", connection.next_sequence_value_sql('sequence_name')
  end

  def test_supports_sequences_should_return_by_default
    assert_equal true, connection.supports_sequences?
  end

  def test_set_sequence_value_should_set_given_value_for_sequence
    name = 'sequence_name'
    value = 5
    connection.expects(:select).with("SELECT SETVAL('#{name}', #{value})")

    connection.set_sequence_value(name, value)
  end

  def test_current_sequence_value_should_fetch_last_generated_sequence_value
    name = 'sequence_name'
    connection.expects(:select_value).with("SELECT last_value FROM #{name}").returns('5')

    assert_equal 5, connection.current_sequence_value(name)
  end

  def test_next_sequence_value_should_fetch_value_to_be_generated_on_next_call_for_sequence
    name = 'sequence_name'
    connection.expects(:select_value).with("SELECT nextval('#{name}')").returns('6')

    assert_equal 6, connection.next_sequence_value(name)
  end

  def test_true_value_should_return_true
    assert_equal 'TRUE', connection.true_value
  end

  def test_false_value_should_return_false
    assert_equal 'FALSE', connection.false_value
  end

  def test_append_to_should_quote_column_name
    assert_equal '"column_name" || (?)', connection.append_to('column_name')
  end

  def test_should_return_next_id_sql
    connection.create_table(:table_name) do |t|
      t.string 'data'
    end

    assert_equal "nextval('#{connection.current_schema}.table_name_id_seq')", connection.next_id_sql('table_name')
  end
end
