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

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class BulkSQLHelperTest < ActiveSupport::TestCase

  def teardown
    ActiveRecord::Base.connection.unstub(:execute)
  end

  def test_bulk_update_should_update_multiple_records_when_there_is_no_where_clause
    options = {table: 'table_name', set: '"column" = \'value\'', for_ids: 'IN (1,2,3,4,5,6)'}
    sql = %{
      UPDATE #{ActiveRecord::Base.connection.quote_table_name(options[:table])}
      SET #{options[:set]}
      WHERE id #{options[:for_ids]}
    }

    ActiveRecord::Base.connection.expects(:execute).with(sql)

    ActiveRecord::Base.connection.bulk_update(options)
  end

  def test_bulk_update_should_update_multiple_records_when_where_clause_is_given
    options = {table: 'table_name', set: '"column" = \'value\'', for_ids: 'IN (1,2,3,4,5,6)', where: '"column_x"=\'value x\''}
    sql = %{
      UPDATE #{ActiveRecord::Base.connection.quote_table_name(options[:table])}
      SET #{options[:set]}
      WHERE id #{options[:for_ids]} AND (#{options[:where]})
    }

    ActiveRecord::Base.connection.expects(:execute).with(sql)

    ActiveRecord::Base.connection.bulk_update(options)
  end

  def test_insert_into_should_insert_all_records_with_new_ids_by_default
    options = {table: 'target_table', from: 'source_table', select_columns: %w(column1 column2), insert_columns: %w(tc1 tc2)}
    sql = %{
      INSERT INTO #{ActiveRecord::Base.connection.quote_column_name(options[:table])} (id, tc1, tc2)
        (SELECT  nextval('target_table_id_seq'), #{options[:select_columns].join(', ')}
        FROM #{options[:from]}\n          \n        )
    }
    ActiveRecord::Base.connection.expects(:execute).with(sql)
    ActiveRecord::Base.connection.expects(:next_id_sql).with('target_table').returns("nextval('target_table_id_seq')")

    ActiveRecord::Base.connection.insert_into(options)
  end

  def test_insert_into_should_insert_all_records_without_id_column_when_generate_id_is_false
    options = {table: 'target_table', from: 'source_table', select_columns: %w(column1 column2), insert_columns: %w(tc1 tc2), generate_id: false}
    sql = %{
      INSERT INTO #{ActiveRecord::Base.connection.quote_column_name(options[:table])} (tc1, tc2)
        (SELECT  #{options[:select_columns].join(', ')}
        FROM #{options[:from]}\n          \n        )
    }
    ActiveRecord::Base.connection.expects(:execute).with(sql)

    ActiveRecord::Base.connection.insert_into(options)
  end

  def test_insert_into_should_insert_records_with_where_condition
    options = {table: 'target_table',
               from: 'source_table',
               select_columns: %w(column1 column2),
               insert_columns: %w(tc1 tc2),
               generate_id: false, where: '"column1"=\'value x\''}
    sql = %{
      INSERT INTO #{ActiveRecord::Base.connection.quote_column_name(options[:table])} (tc1, tc2)
        (SELECT  #{options[:select_columns].join(', ')}
        FROM #{options[:from]}
        WHERE #{options[:where]} \n        )
    }
    ActiveRecord::Base.connection.expects(:execute).with(sql)

    ActiveRecord::Base.connection.insert_into(options)
  end

  def test_insert_into_should_insert_records_with_select_distinct
    options = {table: 'target_table',
               from: 'source_table',
               select_columns: %w(column1 column2),
               insert_columns: %w(tc1 tc2),
               generate_id: false, select_distinct: true}
    sql = %{
      INSERT INTO #{ActiveRecord::Base.connection.quote_column_name(options[:table])} (tc1, tc2)
        (SELECT DISTINCT #{options[:select_columns].join(', ')}
        FROM #{options[:from]}\n          \n        )
    }
    ActiveRecord::Base.connection.expects(:execute).with(sql)

    ActiveRecord::Base.connection.insert_into(options)
  end

  def test_insert_into_should_insert_records_with_group_by
    options = {table: 'target_table',
               from: 'source_table',
               select_columns: %w(column1 column2),
               insert_columns: %w(tc1 tc2),
               generate_id: false, group_by: 'column2'}
    sql = %{
      INSERT INTO #{ActiveRecord::Base.connection.quote_column_name(options[:table])} (tc1, tc2)
        (SELECT  #{options[:select_columns].join(', ')}
        FROM #{options[:from]}
          GROUP BY column2
        )
    }
    ActiveRecord::Base.connection.expects(:execute).with(sql)

    ActiveRecord::Base.connection.insert_into(options)
  end

  def test_delete_from_should_delete_given_ids
    options = {table: 'target_table', for_ids: 'IN (1,2,3,4,5,6)'}
    sql = %{
      DELETE FROM #{ActiveRecord::Base.connection.quote_table_name(options[:table])} WHERE id #{options[:for_ids]}
    }
    ActiveRecord::Base.connection.expects(:execute).with(sql)

    ActiveRecord::Base.connection.delete_from(options)
  end

  def test_delete_from_should_delete_given_ids_with_where_clause
    options = {table: 'target_table', for_ids: 'IN (1,2,3,4,5,6)', where: '"column_x"=\'value x\''}
    sql = %{
      DELETE FROM #{ActiveRecord::Base.connection.quote_table_name(options[:table])} WHERE id #{options[:for_ids]} AND (#{options[:where]})
    }
    ActiveRecord::Base.connection.expects(:execute).with(sql)

    ActiveRecord::Base.connection.delete_from(options)
  end
end
