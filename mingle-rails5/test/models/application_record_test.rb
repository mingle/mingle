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

class ApplicationRecordTest < ActiveSupport::TestCase

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.create_table('application_record_test')
    @connection.add_column('application_record_test', 'COLUMN_ONE', 'string')
    @connection.add_column('application_record_test', 'LONG_LONG_LONG_LONG_COLUMN_NAME', 'string')
  end

  def teardown
    @connection.drop_table('application_record_test')
  end

  def test_should_return_true_when_column_is_defined_in_model
    test_model = TestModel.new
    assert test_model.column_defined?('COLUMN_ONE')
  end

  def test_should_return_false_when_column_not_defined_in_model
    test_model = TestModel.new
    assert_false test_model.column_defined?('WRONG_COLUMN_NAME')
  end

  def test_column_defined_should_handle_long_column_name
    test_model = TestModel.new
    assert test_model.column_defined?('LONG_LONG_LONG_LONG_COLUMN_NAME')
  end

  def test_should_find_users_with_more_than_oracle_batch_limit
    ids=[]
    1.upto(1010){|i| ids<<i}
    add_multiple_records([1,5,100,1001,1005])

    all_records = TestModel.batched_find(ids)

    assert_equal(5,all_records.count)
  end

  def add_multiple_records(ids)
    ids.each{ |v| @connection.execute("insert into application_record_test (id) values(#{v})") }
  end

  class TestModel < ApplicationRecord
    self.table_name = 'application_record_test'
  end
end
