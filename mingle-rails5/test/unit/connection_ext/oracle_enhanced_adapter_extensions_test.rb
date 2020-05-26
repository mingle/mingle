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

class OracleEnhancedAdapterExtensionsTest < ActiveSupport::TestCase
  include DatabaseTestHelpers
  use_db :oracle, 'ORACLE_ENHANCED_ADAPTER_TEST'

  LONG_TABLE_NAME = 'table_name_with_26_characters'
  LONG_COLUMN_NAME = 'column_name_with_more_than_thirty_chart'
  SHORTEN_TABLE_NAME= 'TABLE_NAMEBC2B51F2E5B1CF46'
  SHORTEN_QUOTED_TABLE_NAME = "\"#{SHORTEN_TABLE_NAME}\""
  SHORTEN_QUOTED_COLUMN_NAME = '"COLUMN_NAME_WI204E56B793699453"'
  SEQUENCE_NAME_FOR_LONG_TABLE = 'TABLE_NAMEBC2B51F2E5B1CF46_SEQ'

  class TestModel < ApplicationRecord

  end

  def setup
    connection.create_table(LONG_TABLE_NAME)
    connection.add_column(LONG_TABLE_NAME, 'first_column', 'string', limit: 30)
  end

  def teardown
    connection.unstub(:execute)
  end

  def test_should_switch_schema
    assert_equal 'ORACLE_ENHANCED_ADAPTER_TEST', connection.current_schema
  end

  def test_schema_exists_should_return_true
    assert connection.schema_exists?('ORACLE_ENHANCED_ADAPTER_TEST')
  end

  def test_schema_exists_should_return_false
    assert_false connection.schema_exists?('my_schema')
  end


  def test_should_generate_next_id_sql
    assert_equal 'my_table_seq.nextval', connection.next_id_sql('my_table')
  end

  def test_should_check_schemata_with_prefix
    connection.expects(:select_values).with("SELECT USERNAME FROM ALL_USERS WHERE USERNAME LIKE 'TEST%' ESCAPE '\\'")

    connection.schemata_with_prefix('test')
  end

  def test_should_create_tenant_schema
    assert connection.create_tenant_schema('my_tenant_name')
    assert connection.schema_exists?('my_tenant_name')
  ensure
    connection.drop_tenant_schema('my_tenant_name')
  end

  def test_should_drop_tenant_schema_when_there_is_a_table_spaces_for_tenant_schema
    connection.expects(:execute).with('DROP USER my_schema CASCADE')
    connection.expects(:select_value).with("SELECT COUNT(*) AS TABLESPACE_COUNT FROM DBA_TABLESPACES WHERE TABLESPACE_NAME='my_schema'").returns(1)
    connection.expects(:execute).with('DROP TABLESPACE my_schema INCLUDING CONTENTS AND DATAFILES')

    connection.drop_tenant_schema('my_schema')
  end

  def test_should_drop_tenant_schema_when_there_is_no_table_spaces_for_tenant_schema
    connection.expects(:execute).with('DROP USER my_schema CASCADE')
    connection.expects(:select_value).with("SELECT COUNT(*) AS TABLESPACE_COUNT FROM DBA_TABLESPACES WHERE TABLESPACE_NAME='my_schema'").returns(0)
    connection.expects(:execute).with('DROP TABLESPACE my_schema INCLUDING CONTENTS AND DATAFILES').never

    connection.drop_tenant_schema('my_schema')
  end

  def test_should_execute_redistribute_project_card_rank
    sql = '
       MERGE INTO cards_table c
            USING (SELECT id, row_number() OVER (ORDER BY project_card_rank) AS position FROM cards_table) sorted
               ON (c.id = sorted.id)
WHEN MATCHED THEN
       UPDATE SET c.project_card_rank = (CAST(1 AS NUMBER) + (sorted.position * CAST(2 AS NUMBER)))
     '
    connection.expects(:execute).with(sql)

    connection.redistribute_project_card_rank('cards_table', 1, 2)

  end

  def test_string_limit_should_return_4000_as_limit
    assert_equal 4000, connection.string_limit
  end

  def test_max_precision_should_38
    assert_equal 38, connection.max_precision
  end

  def test_should_return_safe_table_name
    assert_equal 'table_namebc2b51f2e5b1cf46', connection.safe_table_name(LONG_TABLE_NAME)
  end

  def test_should_create_safe_table_name_with_table_prefix
    old_table_name_prefix = ActiveRecord::Base.table_name_prefix
    ActiveRecord::Base.table_name_prefix = 'prefix'
    assert_equal 'prefixtablaf2090bd1d379ed8', connection.safe_table_name(LONG_TABLE_NAME)
  ensure
    ActiveRecord::Base.table_name_prefix = old_table_name_prefix
  end

  def test_should_limit_column_name_to_30_chars
    assert_equal 'column_name_wi204e56b793699453', connection.column_name(LONG_COLUMN_NAME)
  end

  def test_should_not_shorten_column_name_if_its_less_than_30_chars
    assert_equal 'column_name1', connection.column_name('column_name1')
  end

  def test_should_create_sequence_with_defined_max_limit_when_strict_counter_is_given
    connection.expects(:execute).with('CREATE SEQUENCE sequence1 START WITH 5 INCREMENT BY 1 MAXVALUE 999999999999999999999 CYCLE ORDER NOCACHE')

    connection.create_sequence('sequence1', 5, strict_counter: true)
  end

  def test_should_create_sequence_with_undefined_limit_when_strict_counter_is_not_given
    connection.expects(:execute).with('CREATE SEQUENCE sequence1 START WITH 5')

    connection.create_sequence('sequence1', 5)
  end

  def test_should_drop_sequence
    connection.expects(:execute).with('DROP SEQUENCE sequence1')

    connection.drop_sequence('sequence1')
  end

  def test_should_return_true_if_sequence_exists
    connection.expects(:select_value).with("SELECT COUNT(*) FROM user_sequences WHERE sequence_name = 'SEQUENCE1'").returns(1)

    assert connection.sequence_exists?('sequence1')
  end

  def test_sequence_exists_should_shorten_sequence_name_having_more_than_30_chars
    connection.expects(:select_value).with("SELECT COUNT(*) FROM user_sequences WHERE sequence_name = 'VERY_VERY_9e19557116c10fe8'")

    connection.sequence_exists?('very_very_very_very_long_sequence_name')
  end

  def test_should_return_false_if_sequence_does_not_exists
    assert_false connection.sequence_exists?('some_random_sequence')
  end

  def test_should_set_sequence_value
    connection.expects(:execute).with('DROP SEQUENCE sequence1')
    connection.expects(:execute).with('CREATE SEQUENCE sequence1 START WITH 10')

    connection.set_sequence_value('sequence1', 10)
  end

  def test_should_return_last_generated_sequence_value
    connection.expects(:select_value).with("SELECT LAST_NUMBER FROM USER_SEQUENCES WHERE LOWER(SEQUENCE_NAME)=LOWER('MY_SEQUENCE_NAME')").returns(10)

    assert_equal 10, connection.last_generated_sequence_value('MY_SEQUENCE_NAME')
  end

  def test_should_return_current_sequence_value
    connection.expects(:select_value).with('select my_sequence.CURRVAL from dual')
    connection.current_sequence_value('my_sequence')
  end

  def test_should_return_not_null_or_empty_sql
    assert_equal 'column IS NOT NULL', connection.not_null_or_empty('column')
  end

  def test_should_return_date_insert_sql
    date = Date.new
    assert_equal "TO_DATE('#{date}', 'YYYY-MM-DD HH24:MI:SS')", connection.datetime_insert_sql(date)
  end

  def test_should_return_datetime_insert_sql
    time = Time.now
    assert_equal "TO_TIMESTAMP('#{time.to_formatted_s(:db)}.#{sprintf('%06d', time.usec)}', 'YYYY-MM-DD HH24:MI:SS.FF')", connection.datetime_insert_sql(time)
  end

  def test_alias_if_necessary_as_should_should_return_empty_string
    assert_equal '', connection.alias_if_necessary_as('MY_NAME')
  end

  def test_should_return_cast_as_char_sql
    assert_equal 'CAST(1234 AS VARCHAR2(3))', connection.as_char(1234, 3)
  end

  def test_should_return_cast_as_boolean_sql
    assert_equal 'CAST(true AS NUMBER(1,0))', connection.as_boolean(true)
  end

  def test_should_return_padded_number_sql
    assert_equal 'TO_CHAR(12, \'FM99999999999999999999999999999999990.000\')', connection.as_padded_number(12, 3)
    assert_equal 'TO_CHAR(12, \'FM99999999999999999999999999999999999990\')', connection.as_padded_number(12, 0)
  end

  def test_should_return_padded_number_sql_for_empty_value
    assert_equal 'TO_CHAR(NULL, \'FM99999999999999999999999999999999990.000\')', connection.as_padded_number('', 3)
    assert_equal 'TO_CHAR(NULL, \'FM99999999999999999999999999999999999990\')', connection.as_padded_number('', 0)
  end

  def test_should_insert_values_in_bulk
    connection.create_table(:test_models) do |t|
      t.string :name
      t.string :identifier
    end
    data = 2.times.map do
      project_name='project'.uniquify[0..15]
      {name: project_name, identifier: project_name}.with_indifferent_access
    end

    assert connection.bulk_insert(TestModel, data)
    assert_equal data, TestModel.all.map {|project| {'name' => project.name, 'identifier' => project.identifier}}
  end

  def test_insert_multi_rows_should_insert_multiple_rows
    connection.create_table(:insert_multiple_rows) do |t|
      t.string :foo
      t.string :bar
      t.string :baz
    end

    table_name = 'insert_multiple_rows'
    column_names = %w(id foo bar)

    assert connection.insert_multi_rows(table_name, column_names, [%w(12 f1 b1), %w(13 f2 b2)])

    assert_equal [[12, 'f1', 'b1', nil], [13, 'f2', 'b2', nil]], connection.exec_query('select * from insert_multiple_rows').rows
  end

  def test_insert_should_return_id
    connection.create_table(:insert_returns_item_id) do |t|
      t.string :foo
    end
    puts connection.select_value("SELECT insert_returns_item_id_seq.NEXTVAL FROM dual")
    assert_not_nil connection.insert("INSERT INTO insert_returns_item_id (id, foo) values(1, 'values')")
  end

  def test_should_create_value_out_of_precision_sql

    assert_equal "REGEXP_LIKE(\"COLUMN_NAME\", '^.*[.][0-9]{24,}$')", connection.value_out_of_precision('column_name', 23)
  end

  def test_should_remove_leading_underscores
    assert_equal 'table_name', connection.db_specific_table_name('__table_name')
  end

  def test_should_shorten_identifier
    assert_equal 'This_is_a_very90e00446f17a2024', connection.identifier('This_is_a_very_long_identifier_name')
    assert_equal 'SMALL_IDENTIFIER_NAME', connection.identifier('SMALL_IDENTIFIER_NAME')
  end

  def test_should_return_from_no_table_sql
    assert_equal 'FROM dual', connection.from_no_table
  end

  def test_should_return_is_number_sql
    assert_equal "REGEXP_LIKE(TRIM(column_name), '^-?(([0-9]+([.][0-9]*)?)|([0-9]*[.][0-9]+))$')", connection.is_number('column_name')
  end

  def test_should_verify_charset
    connection.verify_charset!
  end

  def test_should_raise_error_when_database_char_set_is_other_than_al32utf8
    sql = <<-SQL
      SELECT value
        FROM nls_database_parameters
       WHERE parameter = 'NLS_CHARACTERSET'
    SQL
    connection.expects(:select_value).with(sql).returns('UTF16')
    assert_raises Exception do
      connection.verify_charset!
    end
  end

  #ShortIdentifiersTest
  def test_data_source_exists_should_return_true_for_table_name_with_more_than_26_char
    assert connection.data_source_exists?(LONG_TABLE_NAME)
    assert_false connection.data_source_exists?('some_really_really_really_long_table_name')
  end

  def test_should_drop_table_with_name_containing_more_than_30_char
    connection.expects(:execute).with("DROP TABLE #{connection.quote_table_name('SECOND_TAB2DDFAB36D10FFB85')}")
    connection.expects(:execute).with("DROP SEQUENCE #{connection.quote_table_name('SECOND_TAB2DDFAB36D10FFB85_SEQ')}")

    connection.drop_table('second_table_name_with_more_than_thirty_chart')
  end

  def test_should_add_index_to_the_table_with_more_than_30_char
    index_name = connection.quote_column_name('I_TAB_NAM_PRO')
    column_name = connection.quote_column_name('PROPERTY')
    connection.expects(:execute).with("CREATE  INDEX #{index_name} ON #{SHORTEN_QUOTED_TABLE_NAME} (#{column_name}) ")

    connection.add_index(LONG_TABLE_NAME, :property)
  end

  def test_should_return_indexes_for_the_table_with_more_than_30_char
    connection.add_index(LONG_TABLE_NAME, :first_column)
    connection.index_name_exists?(SHORTEN_TABLE_NAME, 'i_tab_nam_fir_col', :exist)
    assert :exist
    connection.remove_index(SHORTEN_TABLE_NAME, name: 'i_tab_nam_fir_col')
  end

  def test_should_return_default_sequence_name_for_the_table_with_more_than_30_char

    assert_equal SEQUENCE_NAME_FOR_LONG_TABLE.downcase, connection.default_sequence_name(LONG_TABLE_NAME, :property)
  end


  def test_should_add_column_to_the_table_with_more_than_30_char
    connection.expects(:execute).with("ALTER TABLE #{SHORTEN_QUOTED_TABLE_NAME} ADD #{SHORTEN_QUOTED_COLUMN_NAME} VARCHAR2(20 CHAR) DEFAULT 'default_value'")

    connection.add_column(LONG_TABLE_NAME, LONG_COLUMN_NAME, 'string', default: 'default_value', limit: 20)
  end

  def test_should_rename_column_of_the_table_with_more_than_30_char
    old_quoted_column_name = connection.quote_column_name 'OLD_COLUMN_NAME'
    new_quoted_column_name = connection.quote_column_name 'NEW_COLUMN_NAMCC477D88E800CF94'
    connection.expects(:execute).with("ALTER TABLE #{SHORTEN_QUOTED_TABLE_NAME} RENAME COLUMN #{old_quoted_column_name} to #{new_quoted_column_name}")

    connection.rename_column(LONG_TABLE_NAME, 'old_column_name', 'new_column_name_with_more_than_thirty_chart')
  end

  def test_should_change_column_default_for_the_table_with_more_than_30_char
    quoted_column_name = connection.quote_column_name 'COLUMN_NAME'
    connection.expects(:execute).with("ALTER TABLE #{SHORTEN_QUOTED_TABLE_NAME} MODIFY #{quoted_column_name} DEFAULT 'default_value'")

    connection.change_column_default(LONG_TABLE_NAME, 'column_name', 'default_value')
  end

  def test_should_change_column_for_the_table_with_more_than_30_char
    quoted_column_name = connection.quote_column_name 'COLUMN_NAME'
    connection.expects(:column_for).with('table_namebc2b51f2e5b1cf46', 'column_name').returns('COLUMN_NAME')
    connection.expects(:execute).with("ALTER TABLE #{SHORTEN_QUOTED_TABLE_NAME} MODIFY #{quoted_column_name} numeric DEFAULT 20")

    connection.change_column(LONG_TABLE_NAME, 'column_name', 'numeric', default: 20)
  end

  def test_should_remove_column_from_the_table_with_more_than_30_char
    connection.expects(:execute).with("ALTER TABLE #{SHORTEN_QUOTED_TABLE_NAME} DROP COLUMN #{SHORTEN_QUOTED_COLUMN_NAME} CASCADE CONSTRAINTS")

    connection.remove_column(LONG_TABLE_NAME, LONG_COLUMN_NAME)
  end

  def test_should_quote_table_name_with_more_than_30_char
    assert_equal SHORTEN_QUOTED_TABLE_NAME, connection.quote_table_name(LONG_TABLE_NAME)
  end

  def test_should_quote_table_name_with_30_or_less_than_30_char
    assert_equal '"TABLE_NAME_WITH_THRTY_CHAR"', connection.quote_table_name('table_name_with_thrty_char')
  end


  def test_should_quote_column_name_with_more_than_30_char
    assert_equal SHORTEN_QUOTED_COLUMN_NAME, connection.quote_column_name(LONG_COLUMN_NAME)
  end

  def test_should_quote_column_name_with_30_or_less_than_30_char
    assert_equal '"COLUMN__NAME_WITH_THIRTY_CHAR_"', connection.quote_column_name('column__name_with_thirty_char_')
  end

  def test_should_return_pk_and_sequence_for_with_30_or_less_than_30_char
    expected_primary_key = 'pk'
    expected_sequence = 'sequence_name'
    connection.expects(:select_values)
        .with("select us.sequence_name from all_sequences us where us.sequence_owner = '#{connection.current_schema}' and us.sequence_name = '#{SEQUENCE_NAME_FOR_LONG_TABLE}'", 'Sequence')
        .returns([expected_sequence])
    connection.expects(:select_values)
        .with("SELECT cc.column_name FROM all_constraints c, all_cons_columns cc WHERE c.owner = '#{connection.current_schema}' AND c.table_name = '#{SHORTEN_TABLE_NAME}' AND c.constraint_type = 'P' AND cc.owner = c.owner AND cc.constraint_name = c.constraint_name", 'Primary Key')
        .returns([expected_primary_key])

    primary_key, sequence_name = *connection.pk_and_sequence_for(LONG_TABLE_NAME)

    assert_equal expected_primary_key, primary_key
    assert_equal expected_sequence, sequence_name
  end

  #CharLimitTest
  def test_should_add_column_with_enforced_char_limit
    connection.expects(:execute).with("ALTER TABLE #{SHORTEN_QUOTED_TABLE_NAME} ADD \"SOME_COLUMN\" VARCHAR2(10 CHAR)")
    connection.add_column(LONG_TABLE_NAME, 'some_column', 'string', limit: 10)
  end

  def test_should_change_column_with_enforced_char_limit
    quoted_column_name = connection.quote_column_name 'COLUMN_NAME'
    connection.expects(:column_for).with('table_namebc2b51f2e5b1cf46', 'column_name').returns('COLUMN_NAME')
    connection.expects(:execute).with("ALTER TABLE #{SHORTEN_QUOTED_TABLE_NAME} MODIFY #{quoted_column_name} VARCHAR2(20 CHAR)")

    connection.change_column(LONG_TABLE_NAME, 'column_name', 'string', limit: 20)
  end

  #ColumnKeyWordsEscaping
  def test_should_handle_column_name_ending_with_a_keyword
    assert_equal "\"1TRUE.FILE\"" , connection.quote_column_name('1True.file')
  end

  def test_should_find_all_indexes_only_in_current_schema_for_a_table
    sql = %Q{SELECT
                     all_ind_columns.column_name,
                     all_indexes.uniqueness,
                     all_ind_columns.index_name
                  FROM all_ind_columns
                  LEFT JOIN all_indexes
                    ON all_indexes.index_name = all_ind_columns.index_name
                       AND all_indexes.owner = all_ind_columns.INDEX_owner
                       AND all_indexes.TABLE_NAME = all_ind_columns.TABLE_NAME
                  WHERE
                    all_ind_columns.table_name='TABLE_NAMEBC2B51F2E5B1CF46'
                    AND all_ind_columns.index_owner='#{Multitenancy.schema_name}'
                    AND all_indexes.generated = 'N'}
    connection.expects(:select_rows).with(sql).returns([%w(LOGIN UNIQUE INDEX_USERS_ON_LOGIN)])
    assert_equal 1, connection.indexes(SHORTEN_TABLE_NAME).count
  end

  def test_should_find_index_from_current_schema
    sql = "select index_name from all_indexes where index_name = 'I_TAB_NAM_FIR_COL' and owner = '#{Multitenancy.schema_name}'"
    connection.expects(:select_value).with(sql).returns(true)
    assert connection.index_exists?(SHORTEN_TABLE_NAME, 'i_tab_nam_fir_col', :exist)
  end

  # SmartQuoting
  def test_should_smart_quote_full_name
    assert_equal "\"1True.some_column\"" , connection.quote_column_name('1True.some_column')
  end

  def test_quoting_a_column_name_twice_does_not_double_quote_it
      assert_equal "\"SOME_COLUMN_NAME\"",   connection.quote_column_name(connection.quote_column_name('some_column_name'))
  end

  def test_quoting_a_table_name_twice_does_not_double_quote_it
    assert_equal "\"SOME_TABLE_NAME\"",   connection.quote_table_name(connection.quote_table_name('some_table_name'))
  end

end
